// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

/* ==== OpenZeppelin === */
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {RuleAddressSetInvariantStorage} from "./invariantStorage/RuleAddressSetInvariantStorage.sol";

/**
 * @title Rule Address Set (Internal)
 * @notice Internal utility for managing a set of rule-related addresses.
 * @dev
 * - Uses OpenZeppelin's EnumerableSet for efficient enumeration.
 * - Designed for internal inheritance and logic composition.
 * - Batch operations do not revert when individual entries are invalid.
 */
abstract contract RuleAddressSetInternal is RuleAddressSetInvariantStorage {
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Storage for all listed addresses.
     */
    EnumerableSet.AddressSet private _listedAddresses;

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds multiple addresses to the set.
     * @dev
     * - Does not revert if an address is already listed.
     * - Skips existing entries silently.
     * @param addressesToAdd The array of addresses to add.
     * @return added The number of newly added addresses.
     * @return skipped The number of addresses that were already listed.
     */
    function _addAddresses(address[] calldata addressesToAdd) internal returns (uint256 added, uint256 skipped) {
        for (uint256 i = 0; i < addressesToAdd.length; ++i) {
            // The zero address is the mint/burn sentinel, never a participant. It is REJECTED
            // rather than skipped: the batch convention skips *duplicates* (an idempotent no-op that
            // the emitted event still describes truthfully), but silently dropping address(0) would
            // make `AddAddresses` report a member that is not in the set — re-polluting the very
            // off-chain view this guard exists to keep clean. Mint/burn is governed by
            // allowMint/allowBurn, never by list membership.
            require(addressesToAdd[i] != address(0), RuleAddressSet_ZeroAddressNotAllowed());
            if (_listedAddresses.add(addressesToAdd[i])) {
                added += 1;
            } else {
                skipped += 1;
            }
        }
    }

    /**
     * @notice Removes multiple addresses from the set.
     * @dev
     * - Does not revert if an address is not found.
     * - Skips non-existing entries silently.
     * @param addressesToRemove The array of addresses to remove.
     * @return removed The number of addresses removed.
     * @return skipped The number of addresses that were not listed.
     */
    function _removeAddresses(address[] calldata addressesToRemove)
        internal
        returns (uint256 removed, uint256 skipped)
    {
        for (uint256 i = 0; i < addressesToRemove.length; ++i) {
            if (_listedAddresses.remove(addressesToRemove[i])) {
                removed += 1;
            } else {
                skipped += 1;
            }
        }
    }

    /**
     * @notice Adds a single address to the set.
     * @param targetAddress The address to add.
     */
    function _addAddress(address targetAddress) internal virtual {
        _listedAddresses.add(targetAddress);
    }

    /**
     * @notice Removes a single address from the set.
     * @param targetAddress The address to remove.
     */
    function _removeAddress(address targetAddress) internal virtual {
        _listedAddresses.remove(targetAddress);
    }

    /**
     * @notice Returns the total number of listed addresses.
     * @return count The number of listed addresses.
     */
    function _listedAddressCount() internal view virtual returns (uint256 count) {
        count = _listedAddresses.length();
    }

    /**
     * @notice Checks if an address is listed.
     * @param targetAddress The address to check.
     * @return isListed True if the address is listed, false otherwise.
     */
    function _isAddressListed(address targetAddress) internal view virtual returns (bool isListed) {
        isListed = _listedAddresses.contains(targetAddress);
    }
}
