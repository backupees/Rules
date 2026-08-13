// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {AggregatorV3Interface} from "../../../interfaces/AggregatorV3Interface.sol";
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleTransferValidation} from "../core/RuleTransferValidation.sol";
import {ChainlinkPoRFeedManager} from "../core/ChainlinkPoRFeedManager.sol";

/**
 * @title RuleChainlinkPoRBase
 * @notice Restricts minting so that the token's total supply never exceeds the reserves reported
 * by a Chainlink Proof of Reserve (PoR) data feed.
 * @dev Before every mint the rule reads `latestRoundData()` from the configured
 * `AggregatorV3Interface`, scales the answer from the feed's decimals to the token's decimals, and
 * rejects the operation when `totalSupply + value` would exceed it. The backed supply equals the
 * reported reserves exactly; there is no margin or buffer.
 *
 * Only mints (`from == address(0)`) are gated: plain transfers do not change the total supply and
 * burns only reduce it.
 *
 * @dev This contract is the **rule half**: the constructor, the ERC-1404 / ERC-3643 surface
 * (`canReturnTransferRestrictionCode`, `messageForTransferRestriction`, `transferred`) and the
 * restriction logic that turns a backed supply into a restriction code. Everything about the feed
 * itself -- which feed, which token, staleness, decimal scaling, and the revert-free read -- lives
 * in {ChainlinkPoRFeedManager}, which carries no constructor and no ERC-1404 dependency so it can be
 * reused or initialized differently. See that contract for the feed-reading guarantees, including
 * why `decimals()` is read live rather than cached.
 *
 * IMPORTANT: the read path (`detectTransferRestriction*` / `canTransfer*`) must never revert. A feed
 * that has no code, whose `decimals()` or `latestRoundData()` reverts, that reports more than
 * {MAX_FEED_DECIMALS} decimals, returns a negative answer or reports an incomplete round yields
 * {CODE_RESERVES_ANSWER_INVALID} or {CODE_RESERVES_FEED_UNAVAILABLE}; a feed older than
 * `maxStalenessSeconds` yields {CODE_RESERVES_FEED_STALE}; a `tokenContract` whose `totalSupply()`
 * reverts or that has lost its code yields {CODE_TOTAL_SUPPLY_UNAVAILABLE}. All are fail-closed:
 * mints are blocked. `tokenContract` is trusted to report an *accurate* supply, but it is NOT
 * trusted to stay callable -- that is guarded.
 */
abstract contract RuleChainlinkPoRBase is RuleTransferValidation, ChainlinkPoRFeedManager {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the rule with the protected token and the reserve feed.
     * @dev Configuration is delegated to {ChainlinkPoRFeedManager}'s internals, which are
     * constructor-agnostic; an upgradeable variant would call the same three from an initializer.
     * @param tokenContract_ Address of the token whose `totalSupply` is checked; must not be the zero address.
     * @param tokenDecimals_ Decimals of that token; must be at most {MAX_TOKEN_DECIMALS} and, when
     * the token exposes `decimals()`, must match it. `0` is valid and common for CMTAT equity tokens.
     * @param reservesFeed_ Proof of Reserve data feed; must be a contract exposing `AggregatorV3Interface`.
     * @param maxStalenessSeconds_ Initial staleness threshold in seconds; 0 disables the check.
     */
    constructor(
        address tokenContract_,
        uint8 tokenDecimals_,
        AggregatorV3Interface reservesFeed_,
        uint256 maxStalenessSeconds_
    ) {
        _setReservesFeed(reservesFeed_);
        _setTokenMetadata(tokenContract_, tokenDecimals_);
        _setMaxStalenessSeconds(maxStalenessSeconds_);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether this rule can produce the given restriction code.
     * @param restrictionCode Restriction code to test.
     * @return True if `restrictionCode` is one of this rule's codes.
     */
    function canReturnTransferRestrictionCode(uint8 restrictionCode) external pure override returns (bool) {
        return restrictionCode == CODE_RESERVES_EXCEEDED || restrictionCode == CODE_RESERVES_FEED_STALE
            || restrictionCode == CODE_RESERVES_ANSWER_INVALID || restrictionCode == CODE_RESERVES_FEED_UNAVAILABLE
            || restrictionCode == CODE_TOTAL_SUPPLY_UNAVAILABLE;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IERC3643IComplianceContract
     */
    function transferred(address from, address to, uint256 value) public view override(IERC3643IComplianceContract) {
        _transferred(from, to, value);
    }

    /**
     * @inheritdoc IRuleEngine
     */
    function transferred(address spender, address from, address to, uint256 value) public view override(IRuleEngine) {
        _transferredFrom(spender, from, to, value);
    }

    /**
     * @inheritdoc IERC1404
     */
    function messageForTransferRestriction(uint8 restrictionCode)
        public
        pure
        override(IERC1404)
        returns (string memory)
    {
        if (restrictionCode == CODE_RESERVES_EXCEEDED) {
            return TEXT_RESERVES_EXCEEDED;
        } else if (restrictionCode == CODE_RESERVES_FEED_STALE) {
            return TEXT_RESERVES_FEED_STALE;
        } else if (restrictionCode == CODE_RESERVES_ANSWER_INVALID) {
            return TEXT_RESERVES_ANSWER_INVALID;
        } else if (restrictionCode == CODE_RESERVES_FEED_UNAVAILABLE) {
            return TEXT_RESERVES_FEED_UNAVAILABLE;
        } else if (restrictionCode == CODE_TOTAL_SUPPLY_UNAVAILABLE) {
            return TEXT_TOTAL_SUPPLY_UNAVAILABLE;
        }
        return TEXT_CODE_NOT_FOUND;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc RuleTransferValidation
     */
    function _detectTransferRestriction(
        address from,
        address,
        /* to */
        uint256 value
    )
        internal
        view
        virtual
        override
        returns (uint8)
    {
        // Only mints change the total supply upwards; transfers and burns are never gated.
        if (from != address(0)) {
            return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
        }
        (uint8 restrictionCode, uint256 backedSupply) = _maxBackedSupply();
        if (restrictionCode != uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK)) {
            return restrictionCode;
        }
        (bool supplyAvailable, uint256 currentSupply) = _currentSupply();
        if (!supplyAvailable) {
            return CODE_TOTAL_SUPPLY_UNAVAILABLE;
        }
        // Overflow-safe: `currentSupply + value` could exceed uint256 and this is a
        // MUST-NOT-revert ERC-1404/ERC-3643 view, so compare against the remaining headroom.
        if (currentSupply > backedSupply || value > backedSupply - currentSupply) {
            return CODE_RESERVES_EXCEEDED;
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @inheritdoc RuleTransferValidation
     */
    function _detectTransferRestrictionFrom(address, address from, address to, uint256 value)
        internal
        view
        virtual
        override
        returns (uint8)
    {
        return _detectTransferRestriction(from, to, value);
    }

    /**
     * @notice Enforces the reserve backing for a direct transfer, reverting on violation.
     * @param from Sender address; the zero address denotes a mint whose backing is checked.
     * @param to Recipient address.
     * @param value Transfer amount.
     */
    function _transferred(address from, address to, uint256 value) internal view virtual {
        uint8 code = _detectTransferRestriction(from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleChainlinkPoR_InvalidTransfer(address(this), from, to, value, code)
        );
    }

    /**
     * @notice Enforces the reserve backing for a `transferFrom`, reverting on violation.
     * @param spender Approved spender initiating the transfer; the minter on the mint path.
     * @param from Sender address; the zero address denotes a mint whose backing is checked.
     * @param to Recipient address.
     * @param value Transfer amount.
     */
    function _transferredFrom(address spender, address from, address to, uint256 value) internal view virtual {
        uint8 code = _detectTransferRestrictionFrom(spender, from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleChainlinkPoR_InvalidTransferFrom(address(this), spender, from, to, value, code)
        );
    }
}
