// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleChainlinkPoRInvariantStorage} from "../invariant/RuleChainlinkPoRInvariantStorage.sol";
import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {AggregatorV3Interface} from "../../../interfaces/AggregatorV3Interface.sol";
import {IDecimals} from "../../../interfaces/IDecimals.sol";
import {ITotalSupply} from "../../../interfaces/ITotalSupply.sol";
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleTransferValidation} from "../core/RuleTransferValidation.sol";

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
 * The feed's `decimals()` is read **live on every check**, never cached. Caching would be one
 * external call cheaper, but a feed whose decimals change after configuration would then be
 * mis-scaled by a factor of `10 ** delta` with no on-chain signal -- in the direction that
 * overstates reserves, that silently authorises unbacked minting. Correctness wins over the call.
 *
 * IMPORTANT: the read path (`detectTransferRestriction*` / `canTransfer*`) must never revert, so
 * every feed interaction is guarded. A feed that has no code, whose `decimals()` or
 * `latestRoundData()` reverts, that reports more than {MAX_FEED_DECIMALS} decimals, returns a
 * negative answer or reports an incomplete round yields {CODE_RESERVES_ANSWER_INVALID}; a feed
 * older than `maxStalenessSeconds` yields {CODE_RESERVES_FEED_STALE}; a `tokenContract` whose
 * `totalSupply()` reverts or that has lost its code yields {CODE_TOTAL_SUPPLY_UNAVAILABLE}. All are
 * fail-closed: mints are blocked. `tokenContract` is trusted to report an *accurate* supply, but it
 * is NOT trusted to stay callable -- that is guarded.
 */
abstract contract RuleChainlinkPoRBase is RuleTransferValidation, RuleChainlinkPoRInvariantStorage {
    /**
     * @notice The Proof of Reserve data feed consulted before every mint.
     */
    AggregatorV3Interface public reservesFeed;
    /**
     * @dev tokenContract is trusted to return a correct totalSupply.
     */
    ITotalSupply public tokenContract;
    /**
     * @notice Decimals of the protected token, used to scale the reserve answer.
     */
    uint8 public tokenDecimals;
    /**
     * @notice Maximum accepted age of the reserve data, in seconds; 0 disables the staleness check.
     */
    uint256 public maxStalenessSeconds;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the rule with the protected token and the reserve feed.
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
            || restrictionCode == CODE_RESERVES_ANSWER_INVALID || restrictionCode == CODE_TOTAL_SUPPLY_UNAVAILABLE;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the Proof of Reserve data feed and caches its decimals.
     * @dev The feed must be a contract whose `decimals()` call succeeds and reports at most
     * {MAX_FEED_DECIMALS}; both are validated here so the read path stays revert-free.
     * @param newReservesFeed The new data feed.
     */
    function setReservesFeed(AggregatorV3Interface newReservesFeed) public virtual onlyChainlinkPoRManager {
        _setReservesFeed(newReservesFeed);
    }

    /**
     * @notice Sets the protected token and the decimals used to scale the reserve answer.
     * @param newTokenContract The new token contract; must not be the zero address.
     * @param newTokenDecimals The token decimals; must be at most {MAX_TOKEN_DECIMALS} and, when the
     * token exposes `decimals()`, must match it. `0` is valid and common for CMTAT equity tokens.
     */
    function setTokenMetadata(address newTokenContract, uint8 newTokenDecimals) public virtual onlyChainlinkPoRManager {
        _setTokenMetadata(newTokenContract, newTokenDecimals);
    }

    /**
     * @notice Sets the maximum accepted age of the reserve data.
     * @param newMaxStalenessSeconds The new threshold in seconds; 0 disables the staleness check.
     */
    function setMaxStalenessSeconds(uint256 newMaxStalenessSeconds) public virtual onlyChainlinkPoRManager {
        _setMaxStalenessSeconds(newMaxStalenessSeconds);
    }

    /**
     * @notice Returns the decimals currently reported by {reservesFeed}.
     * @dev Read live from the feed rather than from storage, so it always agrees with what the
     * restriction checks use. Unlike the ERC-1404 views this getter is allowed to revert: it
     * forwards whatever the feed does, which is the honest answer for a diagnostic accessor.
     * @return The feed's current decimals.
     */
    function feedDecimals() public view virtual returns (uint8) {
        return reservesFeed.decimals();
    }

    /**
     * @notice Returns the supply currently backed by the reserves, i.e. the maximum total supply a
     * mint may reach. This is the reported reserves scaled into token units, with no margin applied.
     * @dev Mirrors what {detectTransferRestriction} computes, so integrators can preview the limit
     * without simulating a mint. Never reverts.
     * @return restrictionCode `0` when the feed answer is usable, otherwise the restriction code
     * that a mint would return.
     * @return backedSupply The backed supply expressed in token units; meaningless when
     * `restrictionCode` is non-zero.
     */
    function maxBackedSupply() public view virtual returns (uint8 restrictionCode, uint256 backedSupply) {
        return _maxBackedSupply();
    }

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
        } else if (restrictionCode == CODE_TOTAL_SUPPLY_UNAVAILABLE) {
            return TEXT_TOTAL_SUPPLY_UNAVAILABLE;
        }
        return TEXT_CODE_NOT_FOUND;
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyChainlinkPoRManager() {
        _authorizeChainlinkPoRManager();
        _;
    }

    /**
     * @notice Authorization hook invoked before any configuration change.
     * @dev Implemented by concrete subclasses with the desired access-control policy.
     */
    function _authorizeChainlinkPoRManager() internal view virtual;

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Stores the data feed and emits {ReservesFeedUpdated}.
     * @dev The feed's `decimals()` is validated here so a misconfigured feed is rejected up front
     * rather than silently blocking every mint later, but the value is deliberately NOT cached --
     * {_maxBackedSupply} re-reads it on every check. The emitted decimals are informational: they
     * record what the feed reported at configuration time.
     * @param newReservesFeed The new data feed.
     */
    function _setReservesFeed(AggregatorV3Interface newReservesFeed) internal virtual {
        address feed = address(newReservesFeed);
        require(feed != address(0), RuleChainlinkPoR_FeedAddressZeroNotAllowed());
        require(feed.code.length != 0, RuleChainlinkPoR_FeedIsNotAContract(feed));
        uint8 newFeedDecimals;
        try newReservesFeed.decimals() returns (uint8 decimals_) {
            newFeedDecimals = decimals_;
        } catch {
            revert RuleChainlinkPoR_FeedDecimalsUnavailable(feed);
        }
        require(newFeedDecimals <= MAX_FEED_DECIMALS, RuleChainlinkPoR_FeedDecimalsTooLarge(newFeedDecimals));
        reservesFeed = newReservesFeed;
        emit ReservesFeedUpdated(feed, newFeedDecimals);
    }

    /**
     * @notice Stores the protected token and its decimals and emits {TokenMetadataUpdated}.
     * @dev When the token exposes `decimals()`, the provided value must match it; otherwise the
     * provided value is used as-is. WARNING: an incorrect value for a token that does not expose
     * `decimals()` skews the reserve comparison in either direction.
     * @param newTokenContract The new token contract.
     * @param newTokenDecimals The token decimals.
     */
    function _setTokenMetadata(address newTokenContract, uint8 newTokenDecimals) internal virtual {
        require(newTokenContract != address(0), RuleChainlinkPoR_TokenAddressZeroNotAllowed());
        // Explicit, rather than relying on the uncatchable extcodesize revert that the `decimals()`
        // probe below happens to produce for a codeless address: that is compiler behaviour, not a
        // check, and it would vanish if the probe were ever rewritten as a low-level staticcall.
        require(newTokenContract.code.length != 0, RuleChainlinkPoR_TokenIsNotAContract(newTokenContract));
        require(newTokenDecimals <= MAX_TOKEN_DECIMALS, RuleChainlinkPoR_InvalidTokenDecimals(newTokenDecimals));
        try IDecimals(newTokenContract).decimals() returns (uint8 onChainDecimals) {
            require(
                onChainDecimals == newTokenDecimals,
                RuleChainlinkPoR_TokenDecimalsMismatch(newTokenDecimals, onChainDecimals)
            );
        } catch {
            // The token does not expose `decimals()`; the provided value is used as-is.
        }
        // `totalSupply()` is mandatory, unlike `decimals()`: the restriction check cannot work
        // without it. Probing here turns a silent read-path failure into a configuration error.
        try ITotalSupply(newTokenContract).totalSupply() returns (uint256) {}
        catch {
            revert RuleChainlinkPoR_TokenTotalSupplyUnavailable(newTokenContract);
        }
        tokenContract = ITotalSupply(newTokenContract);
        tokenDecimals = newTokenDecimals;
        emit TokenMetadataUpdated(newTokenContract, newTokenDecimals);
    }

    /**
     * @notice Stores the staleness threshold and emits {MaxStalenessSecondsUpdated}.
     * @param newMaxStalenessSeconds The new threshold in seconds; 0 disables the check.
     */
    function _setMaxStalenessSeconds(uint256 newMaxStalenessSeconds) internal virtual {
        maxStalenessSeconds = newMaxStalenessSeconds;
        emit MaxStalenessSecondsUpdated(newMaxStalenessSeconds);
    }

    /**
     * @notice Reads the feed and derives the supply currently backed by the reserves.
     * @dev Never reverts: the feed address is code-checked and the call is wrapped in `try/catch`.
     * @return restrictionCode `0` when the answer is usable, otherwise the reason it is not.
     * @return backedSupply The backed supply in token units; `0` when `restrictionCode` is non-zero.
     */
    function _maxBackedSupply() internal view virtual returns (uint8 restrictionCode, uint256 backedSupply) {
        AggregatorV3Interface feed = reservesFeed;
        // Guards BOTH calls below: Solidity's extcodesize check on a `try` to a codeless address
        // reverts uncatchably, so `try/catch` alone would not keep this function revert-free.
        if (address(feed).code.length == 0) {
            return (CODE_RESERVES_ANSWER_INVALID, 0);
        }
        // Read live, never cached: see the contract-level note on why the extra call is worth it.
        uint8 currentFeedDecimals;
        try feed.decimals() returns (uint8 decimals_) {
            currentFeedDecimals = decimals_;
        } catch {
            return (CODE_RESERVES_ANSWER_INVALID, 0);
        }
        // Re-checked at read time, not just at configuration: a feed that raised its decimals past
        // the bound would otherwise overflow the scaling exponent and revert this view.
        if (currentFeedDecimals > MAX_FEED_DECIMALS) {
            return (CODE_RESERVES_ANSWER_INVALID, 0);
        }
        try feed.latestRoundData() returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80) {
            // A negative reserve is meaningless and `updatedAt == 0` marks a round that never completed.
            if (answer < 0 || updatedAt == 0) {
                return (CODE_RESERVES_ANSWER_INVALID, 0);
            }
            uint256 staleness = maxStalenessSeconds;
            if (staleness != 0 && block.timestamp > updatedAt && block.timestamp - updatedAt > staleness) {
                return (CODE_RESERVES_FEED_STALE, 0);
            }
            // `answer >= 0` was just checked, so the cast to uint256 preserves the value.
            // forge-lint: disable-next-line(unsafe-typecast)
            uint256 backed = _scaleReserve(uint256(answer), currentFeedDecimals);
            return (uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK), backed);
        } catch {
            return (CODE_RESERVES_ANSWER_INVALID, 0);
        }
    }

    /**
     * @notice Reads the protected token's current total supply.
     * @dev Guarded the same way as the feed calls so the ERC-1404 read path stays revert-free even
     * if the token breaks after configuration -- a proxy upgraded to something that reverts, or a
     * pausable implementation that reverts while paused. Configuration already probes
     * `totalSupply()`, so reaching the failure branch means the token changed behaviour since.
     * @return available True when the supply could be read.
     * @return supply The total supply; meaningless when `available` is false.
     */
    function _currentSupply() internal view virtual returns (bool available, uint256 supply) {
        ITotalSupply token = tokenContract;
        // A `try` on a codeless address reverts uncatchably, so check for code first.
        if (address(token).code.length == 0) {
            return (false, 0);
        }
        try token.totalSupply() returns (uint256 totalSupply_) {
            return (true, totalSupply_);
        } catch {
            return (false, 0);
        }
    }

    /**
     * @notice Converts a reserve answer from the feed's decimals to the token's decimals.
     * @dev Saturates at `type(uint256).max` instead of overflowing: this function is on a
     * MUST-NOT-revert read path, and a reserve that large backs any representable supply anyway.
     * Scaling down truncates, which rounds the backed supply in the conservative direction.
     * @param answer The raw feed answer, expressed with `from` decimals.
     * @param from The feed's decimals, as read live for this check.
     * @return The reserve expressed with {tokenDecimals} decimals.
     */
    function _scaleReserve(uint256 answer, uint8 from) internal view virtual returns (uint256) {
        uint8 to = tokenDecimals;
        if (to == from) {
            return answer;
        }
        if (to > from) {
            // to <= MAX_TOKEN_DECIMALS, so the factor is at most 10 ** 18.
            uint256 factor = 10 ** uint256(to - from);
            if (answer > type(uint256).max / factor) {
                return type(uint256).max;
            }
            return answer * factor;
        }
        // `from` was bounded by MAX_FEED_DECIMALS above, so the divisor cannot overflow.
        return answer / (10 ** uint256(from - to));
    }

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
