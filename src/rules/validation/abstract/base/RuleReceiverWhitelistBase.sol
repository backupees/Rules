// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleAddressSet} from "../RuleAddressSet/RuleAddressSet.sol";
import {RuleNFTAdapter} from "../core/RuleNFTAdapter.sol";
import {RuleTransferValidation} from "../core/RuleTransferValidation.sol";
import {RuleReceiverWhitelistInvariantStorage} from "../invariant/RuleReceiverWhitelistInvariantStorage.sol";
import {AddressListInterfaceId} from "../../../interfaces/library/AddressListInterfaceId.sol";
import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";

/**
 * @title RuleReceiverWhitelistBase
 * @notice A whitelist that screens **only the receiver**, reproducing ERC-3643's eligibility rule
 * as a compliance rule.
 *
 * @dev ERC-3643 mandates exactly one identity check — *"The receiver MUST be whitelisted on the
 * Identity Registry and verified"* — and states that `transferFrom` "works the same way", that
 * `mint` "only require[s] the receiver", and that `burn` "bypasses all checks on eligibility".
 * This rule implements that literally:
 *
 * | Operation | Screened |
 * |---|---|
 * | `transfer(from, to)`            | `to` only |
 * | `transferFrom(spender, from, to)` | `to` only -- the spender is **never** checked |
 * | mint (`from == address(0)`)     | `to`, like any other receiver |
 * | burn (`to == address(0)`)       | nothing -- always allowed |
 *
 * ## Why the sender is not screened
 * Screening the sender would **trap de-listed holders**: an investor whose eligibility lapses could
 * neither receive nor send, leaving their position stranded. ERC-3643 checks only the receiver
 * precisely so a lapsed investor can still exit to an eligible counterparty. Do not add a sender
 * check here -- use {RuleWhitelist}, which screens both parties, if that is the policy you want.
 *
 * ## Why burn is exempt rather than checked
 * On a burn the receiver is `address(0)`, which can never be listed (the address set rejects it, so
 * `isAddressListed(address(0))` is always `false`). Without an explicit exemption every burn would
 * be rejected. ERC-3643 says burn bypasses eligibility, so the exemption is the conformant
 * behaviour, not a convenience.
 *
 * ## Mint has no opt-out flag
 * Unlike {RuleWhitelist}, there is no `allowMint`. ERC-3643 gates minting on receiver eligibility
 * alone, so a mint to a listed address is allowed and a mint to an unlisted one is not. To cap or
 * close issuance, compose with `RuleMaxTotalSupply` or `RuleChainlinkPoR` rather than reaching for
 * a flag here.
 */
abstract contract RuleReceiverWhitelistBase is RuleAddressSet, RuleNFTAdapter, RuleReceiverWhitelistInvariantStorage {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the receiver-whitelist rule base.
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address for meta-transactions.
     */
    constructor(address forwarderIrrevocable) RuleAddressSet(forwarderIrrevocable) {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether this rule can emit the given restriction code.
     * @param restrictionCode The restriction code to check.
     * @return True if the code is produced by this rule.
     */
    function canReturnTransferRestrictionCode(uint8 restrictionCode) external pure override returns (bool) {
        return restrictionCode == CODE_ADDRESS_RECEIVER_NOT_WHITELISTED;
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
        if (restrictionCode == CODE_ADDRESS_RECEIVER_NOT_WHITELISTED) {
            return TEXT_ADDRESS_RECEIVER_NOT_WHITELISTED;
        }
        return TEXT_CODE_NOT_FOUND;
    }

    /**
     * @inheritdoc RuleTransferValidation
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(RuleTransferValidation) returns (bool) {
        // Advertise IAddressList: this rule manages an address set and is callable through
        // the IAddressList interface.
        return interfaceId == AddressListInterfaceId.IADDRESS_LIST_INTERFACE_ID
            || RuleTransferValidation.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Detects whether a transfer is blocked because the receiver is not whitelisted.
     * @dev The sender is deliberately ignored; see the contract-level notes.
     * @param to The recipient address; `address(0)` denotes a burn and is exempt.
     * @return The restriction code, or TRANSFER_OK when allowed.
     */
    function _detectTransferRestriction(address, address to, uint256) internal view virtual override returns (uint8) {
        // Burn (to == address(0)) bypasses eligibility per ERC-3643. It must be exempted
        // explicitly: address(0) can never be listed, so it would otherwise always be rejected.
        if (to != address(0) && !_isAddressListed(to)) {
            return CODE_ADDRESS_RECEIVER_NOT_WHITELISTED;
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @notice Detects whether a delegated transfer is blocked because the receiver is not whitelisted.
     * @dev ERC-3643: `transferFrom` "works the same way" as `transfer`, so the spender is not
     * screened and this delegates to {_detectTransferRestriction}.
     * @param from The sender address.
     * @param to The recipient address.
     * @param value The amount transferred.
     * @return The restriction code, or TRANSFER_OK when allowed.
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
     * @notice Reverts if a direct transfer is blocked because the receiver is not whitelisted.
     * @param from The sender address.
     * @param to The recipient address.
     * @param value The amount transferred.
     */
    function _transferred(address from, address to, uint256 value) internal view virtual override {
        uint8 code = _detectTransferRestriction(from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleReceiverWhitelist_InvalidTransfer(address(this), from, to, value, code)
        );
    }

    /**
     * @notice Reverts if a delegated transfer is blocked because the receiver is not whitelisted.
     * @param spender The delegated spender address; recorded in the error only, never screened.
     * @param from The sender address.
     * @param to The recipient address.
     * @param value The amount transferred.
     */
    function _transferredFrom(address spender, address from, address to, uint256 value) internal view virtual override {
        uint8 code = _detectTransferRestrictionFrom(spender, from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleReceiverWhitelist_InvalidTransferFrom(address(this), spender, from, to, value, code)
        );
    }
}
