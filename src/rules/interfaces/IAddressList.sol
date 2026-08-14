// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IIdentityRegistryContains} from "./IIdentityRegistry.sol";

/**
 * @title IAddressList — interface for managing and querying a set of addresses.
 */
interface IAddressList is IIdentityRegistryContains {
    /* ============ Events ============ */
    /**
     * @notice Emitted when a batch add completes.
     * @dev `targetAddresses` is the input array as submitted, NOT the set of addresses that changed
     * state: a batch skips entries already present. `added` and `skipped` describe the effect, so a
     * consumer can tell a batch of 100 new members from 100 no-ops without replaying the whole
     * event history. The two always sum to `targetAddresses.length`.
     * @param targetAddresses The array submitted by the caller.
     * @param added Number of addresses newly inserted.
     * @param skipped Number of addresses already present, left untouched.
     */
    event AddAddresses(address[] targetAddresses, uint256 added, uint256 skipped);

    /**
     * @notice Emitted when a batch remove completes.
     * @dev See {AddAddresses}: `targetAddresses` is the input, `removed` and `skipped` are the effect.
     * @param targetAddresses The array submitted by the caller.
     * @param removed Number of addresses actually removed.
     * @param skipped Number of addresses that were not present.
     */
    event RemoveAddresses(address[] targetAddresses, uint256 removed, uint256 skipped);

    /**
     * @notice Emitted when a single address is added.
     * @param targetAddress The added address.
     */
    event AddAddress(address indexed targetAddress);

    /**
     * @notice Emitted when a single address is removed.
     * @param targetAddress The removed address.
     */
    event RemoveAddress(address indexed targetAddress);

    /* ============ Write ============ */
    /**
     * @notice Adds multiple addresses to the set.
     * @dev Does not revert if some addresses are already listed.
     * @param targetAddresses The addresses to add.
     */
    function addAddresses(address[] calldata targetAddresses) external;

    /**
     * @notice Removes multiple addresses from the set.
     * @dev Does not revert if some addresses are not listed.
     * @param targetAddresses The addresses to remove.
     */
    function removeAddresses(address[] calldata targetAddresses) external;

    /**
     * @notice Adds a single address to the set.
     * @dev Reverts if the address is already listed.
     * @param targetAddress The address to add.
     */
    function addAddress(address targetAddress) external;

    /**
     * @notice Removes a single address from the set.
     * @dev Reverts if the address is not listed.
     * @param targetAddress The address to remove.
     */
    function removeAddress(address targetAddress) external;

    /* ============ Read ============ */

    /**
     * @notice Returns the number of currently listed addresses.
     * @return count The number of listed addresses.
     */
    function listedAddressCount() external view returns (uint256 count);

    /**
     * @notice Checks whether the provided address is listed.
     * @param targetAddress The address to check.
     * @return isListed True if listed, otherwise false.
     */
    function isAddressListed(address targetAddress) external view returns (bool isListed);

    /**
     * @notice Checks multiple addresses for listing status.
     * @param targetAddresses Array of addresses to check.
     * @return results Boolean array aligned by index with listing results.
     */
    function areAddressesListed(address[] memory targetAddresses) external view returns (bool[] memory results);
}
