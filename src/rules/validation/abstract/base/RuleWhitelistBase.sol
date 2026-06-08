// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleAddressSet} from "../RuleAddressSet/RuleAddressSet.sol";
import {RuleWhitelistShared} from "../core/RuleWhitelistShared.sol";
import {RuleTransferValidation} from "../core/RuleTransferValidation.sol";
import {IIdentityRegistryVerified} from "../../../interfaces/IIdentityRegistry.sol";

/**
 * @title RuleWhitelistBase
 * @notice Core whitelist logic without access-control policy.
 */
abstract contract RuleWhitelistBase is RuleAddressSet, RuleWhitelistShared, IIdentityRegistryVerified {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

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

    function setCheckSpender(bool value) public virtual onlyCheckSpenderManager {
        _setCheckSpender(value);
        emit CheckSpenderUpdated(value);
    }

    function isVerified(address targetAddress)
        public
        view
        virtual
        override(IIdentityRegistryVerified)
        returns (bool isListed)
    {
        isListed = _isAddressListed(targetAddress);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(RuleTransferValidation) returns (bool) {
        return RuleTransferValidation.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyCheckSpenderManager() {
        _authorizeCheckSpenderManager();
        _;
    }

    function _authorizeCheckSpenderManager() internal view virtual;

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    function _setCheckSpender(bool value) internal virtual {
        checkSpender = value;
    }
}
