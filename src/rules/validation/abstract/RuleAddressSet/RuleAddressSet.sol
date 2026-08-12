// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {MetaTxModuleStandalone, ERC2771Context} from "../../../../modules/MetaTxModuleStandalone.sol";
import {RuleAddressSetInternal} from "./RuleAddressSetInternal.sol";
import {RuleAddressSetInvariantStorage} from "./invariantStorage/RuleAddressSetInvariantStorage.sol";
import {RuleAddressSetRolesStorage} from "./invariantStorage/RuleAddressSetRolesStorage.sol";
/* ==== Interfaces === */
import {IIdentityRegistryContains} from "../../../interfaces/IIdentityRegistry.sol";
import {IAddressList} from "../../../interfaces/IAddressList.sol";
/**
 * @title Rule Address Set
 * @notice Manages a permissioned set of addresses related to rule logic.
 * @dev
 * - Provides controlled functions for adding and removing addresses.
 * - Integrates `AccessControl` for role-based access.
 * - Supports gasless transactions via ERC-2771 meta-transactions.
 * - Extends internal logic defined in {RuleAddressSetInternal}.
 */

abstract contract RuleAddressSet is
    MetaTxModuleStandalone,
    RuleAddressSetInvariantStorage,
    RuleAddressSetRolesStorage,
    RuleAddressSetInternal,
    IAddressList
{
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the RuleAddressSet contract.
     * @param forwarderIrrevocable Address of the ERC2771 forwarder (for meta-transactions).
     */
    constructor(address forwarderIrrevocable) MetaTxModuleStandalone(forwarderIrrevocable) {}

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyAddressListAdd() {
        _authorizeAddressListAdd();
        _;
    }

    modifier onlyAddressListRemove() {
        _authorizeAddressListRemove();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds multiple addresses to the set.
     * @dev
     * - Does not revert if an address is already listed.
     * - Accessible only by accounts with the `ADDRESS_LIST_ADD_ROLE`.
     * @param targetAddresses Array of addresses to be added.
     */
    function addAddresses(address[] calldata targetAddresses) public virtual onlyAddressListAdd {
        _addAddresses(targetAddresses);
        emit AddAddresses(targetAddresses);
    }

    /**
     * @notice Removes multiple addresses from the set.
     * @dev
     * - Does not revert if an address is not listed.
     * - Accessible only by accounts with the `ADDRESS_LIST_REMOVE_ROLE`.
     * @param targetAddresses Array of addresses to remove.
     */
    function removeAddresses(address[] calldata targetAddresses) public virtual onlyAddressListRemove {
        _removeAddresses(targetAddresses);
        emit RemoveAddresses(targetAddresses);
    }

    /**
     * @notice Adds a single address to the set.
     * @dev
     * - Reverts if the address is already listed.
     * - Accessible only by accounts with the `ADDRESS_LIST_ADD_ROLE`.
     * @param targetAddress The address to be added.
     */
    function addAddress(address targetAddress) public virtual onlyAddressListAdd {
        require(targetAddress != address(0), RuleAddressSet_ZeroAddressNotAllowed());
        require(!_isAddressListed(targetAddress), RuleAddressSet_AddressAlreadyListed());
        _addAddress(targetAddress);
        emit AddAddress(targetAddress);
    }

    /**
     * @notice Removes a single address from the set.
     * @dev
     * - Reverts if the address is not listed.
     * - Accessible only by accounts with the `ADDRESS_LIST_REMOVE_ROLE`.
     * @param targetAddress The address to be removed.
     */
    function removeAddress(address targetAddress) public virtual onlyAddressListRemove {
        require(_isAddressListed(targetAddress), RuleAddressSet_AddressNotFound());
        _removeAddress(targetAddress);
        emit RemoveAddress(targetAddress);
    }

    /**
     * @notice Returns the total number of currently listed addresses.
     * @return count The number of listed addresses.
     */
    function listedAddressCount() public view returns (uint256 count) {
        count = _listedAddressCount();
    }

    /**
     * @notice Checks whether a specific address is currently listed.
     * @param targetAddress The address to check.
     * @return isListed True if listed, false otherwise.
     */
    function contains(address targetAddress) public view override(IIdentityRegistryContains) returns (bool isListed) {
        isListed = _isAddressListed(targetAddress);
    }

    /**
     * @notice Checks whether a specific address is currently listed.
     * @param targetAddress The address to check.
     * @return isListed True if listed, false otherwise.
     */
    function isAddressListed(address targetAddress) public view returns (bool isListed) {
        isListed = _isAddressListed(targetAddress);
    }

    /**
     * @notice Checks multiple addresses in a single call.
     * @param targetAddresses Array of addresses to check.
     * @return results Array of booleans corresponding to listing status.
     */
    function areAddressesListed(address[] memory targetAddresses) public view returns (bool[] memory results) {
        results = new bool[](targetAddresses.length);
        for (uint256 i = 0; i < targetAddresses.length; ++i) {
            results[i] = _isAddressListed(targetAddresses[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                             INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Authorizes the caller to add addresses to the set; reverts if unauthorized.
     */
    function _authorizeAddressListAdd() internal view virtual;

    /**
     * @notice Authorizes the caller to remove addresses from the set; reverts if unauthorized.
     */
    function _authorizeAddressListRemove() internal view virtual;

    /**
     * @inheritdoc ERC2771Context
     */
    function _msgSender() internal view virtual override(ERC2771Context) returns (address sender) {
        return ERC2771Context._msgSender();
    }

    /**
     * @inheritdoc ERC2771Context
     */
    function _msgData() internal view virtual override(ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /**
     * @inheritdoc ERC2771Context
     */
    function _contextSuffixLength() internal view virtual override(ERC2771Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
}
