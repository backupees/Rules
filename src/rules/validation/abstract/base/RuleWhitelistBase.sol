// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleAddressSet} from "../RuleAddressSet/RuleAddressSet.sol";
import {RuleWhitelistShared} from "../core/RuleWhitelistShared.sol";
import {RuleTransferValidation} from "../core/RuleTransferValidation.sol";
import {IIdentityRegistryVerified} from "../../../interfaces/IIdentityRegistry.sol";
import {AddressListInterfaceId} from "../../../interfaces/library/AddressListInterfaceId.sol";

/**
 * @title RuleWhitelistBase
 * @notice Core whitelist logic without access-control policy.
 */
abstract contract RuleWhitelistBase is RuleAddressSet, RuleWhitelistShared, IIdentityRegistryVerified {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the whitelist rule base.
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address for meta-transactions.
     * @param checkSpender_ Whether to also verify the spender on delegated transfers.
     * @param allowMintBurn When true, whitelists the zero address so mint/burn is permitted.
     */
    constructor(address forwarderIrrevocable, bool checkSpender_, bool allowMintBurn)
        RuleAddressSet(forwarderIrrevocable)
    {
        checkSpender = checkSpender_;
        if (allowMintBurn) {
            _addAddress(address(0));
            emit AddAddress(address(0));
        }
    }

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Enables or disables spender verification on delegated transfers.
     * @dev Restricted to the check-spender manager; emits {CheckSpenderUpdated}.
     * @param value The new state of the `checkSpender` flag.
     */
    function setCheckSpender(bool value) public virtual onlyCheckSpenderManager {
        _setCheckSpender(value);
        emit CheckSpenderUpdated(value);
    }

    /**
     * @inheritdoc IIdentityRegistryVerified
     */
    function isVerified(address targetAddress)
        public
        view
        virtual
        override(IIdentityRegistryVerified)
        returns (bool isListed)
    {
        isListed = _isAddressListed(targetAddress);
    }

    /**
     * @inheritdoc RuleTransferValidation
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(RuleTransferValidation) returns (bool) {
        // Advertise IAddressList: this rule manages an address set and is usable as a
        // child rule of RuleWhitelistWrapper, which calls it through IAddressList.
        return interfaceId == AddressListInterfaceId.IADDRESS_LIST_INTERFACE_ID
            || RuleTransferValidation.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyCheckSpenderManager() {
        _authorizeCheckSpenderManager();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal helper to update the `checkSpender` flag.
     * @param value New flag value.
     */
    function _setCheckSpender(bool value) internal virtual {
        checkSpender = value;
    }

    /**
     * @notice Authorizes the caller as check-spender manager; reverts otherwise.
     * @dev Implemented by concrete subclasses with the desired access-control policy.
     */
    function _authorizeCheckSpenderManager() internal view virtual;

    /**
     * @notice Detects whether a direct transfer is restricted by the whitelist.
     * @param from The sender address.
     * @param to The recipient address.
     * @return The restriction code, or TRANSFER_OK when both parties are whitelisted.
     */
    function _detectTransferRestriction(
        address from,
        address to,
        uint256 /* value */
    )
        internal
        view
        virtual
        override
        returns (uint8)
    {
        if (!isAddressListed(from)) {
            return CODE_ADDRESS_FROM_NOT_WHITELISTED;
        } else if (!isAddressListed(to)) {
            return CODE_ADDRESS_TO_NOT_WHITELISTED;
        }
        return uint8(REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @notice Detects whether a delegated transfer is restricted by the whitelist.
     * @param spender The delegated spender address.
     * @param from The sender address.
     * @param to The recipient address.
     * @param value The amount transferred.
     * @return The restriction code, or TRANSFER_OK when allowed.
     */
    function _detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        internal
        view
        virtual
        override
        returns (uint8)
    {
        // Mint (from == address(0)) and burn (to == address(0)) are exempt from the spender check:
        // the minter/burner acts on its own authority, not as a delegated ERC-20 spender.
        if (checkSpender && from != address(0) && to != address(0) && !isAddressListed(spender)) {
            return CODE_ADDRESS_SPENDER_NOT_WHITELISTED;
        }
        return _detectTransferRestriction(from, to, value);
    }
}
