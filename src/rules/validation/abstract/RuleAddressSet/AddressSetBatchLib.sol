// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title AddressSetBatchLib
 * @notice The batch add/remove mechanics shared by every address-list rule in this library.
 * @dev Extracted because the same two loops were written three times: once in
 * {RuleAddressSetInternal} and twice in `RuleERC2980Internal`, for its whitelist and its frozenlist.
 * The copies had already drifted -- only the `RuleAddressSetInternal` one was covered by a test for
 * the zero-address rejection (`FEEDBACK_12.md` D-1, F-5).
 *
 * Only the two *loops* live here. `add` / `remove` / `contains` / `length` on a single address stay
 * in the inheriting contracts as one-line delegations to {EnumerableSet}: routing those through a
 * library would add a layer of indirection without removing any real duplication.
 *
 * ## Why the zero-address guard is a function parameter
 * Each rule reverts with its OWN custom error (`RuleAddressSet_ZeroAddressNotAllowed`,
 * `RuleERC2980_ZeroAddressNotAllowed`), matching the codebase-wide "one error namespace per rule"
 * convention. A shared library cannot name those errors, and the alternatives are worse:
 *
 * - Reverting with a single shared error would change the revert data callers and tests already
 *   depend on, and break the per-rule error convention.
 * - Returning a "a zero was found" flag for the caller to check would make the guard optional in
 *   practice: a caller that forgot the check would silently list `address(0)`, which is the exact
 *   outcome the guard exists to prevent.
 *
 * Passing the guard as an `internal pure` function pointer keeps it MANDATORY -- it is a required
 * parameter, so the call does not compile without one -- while each rule keeps its own error. The
 * pointer is resolved at compile time and the library is `internal`, so this is a jump inside the
 * calling contract, not a `DELEGATECALL`.
 */
library AddressSetBatchLib {
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * @notice Adds every address in `addressesToAdd` to `set`, skipping entries already present.
     * @dev Duplicates are skipped and counted rather than rejected: an idempotent no-op that the
     * caller's batch event still describes truthfully. `address(0)` is NOT skipped -- `guard` is
     * invoked for every entry and is expected to revert on it, rejecting the whole batch. Silently
     * dropping the sentinel would make the caller's `Add*` event, which echoes the input array,
     * report a member that is not in the set.
     * @param set The address set to modify.
     * @param addressesToAdd The addresses to add.
     * @param guard Per-entry validation supplied by the calling rule; reverts with that rule's own
     * error. Invoked before the entry is inserted.
     * @return added The number of addresses newly inserted.
     * @return skipped The number of addresses already present.
     */
    function addBatch(
        EnumerableSet.AddressSet storage set,
        address[] calldata addressesToAdd,
        function(address) internal pure guard
    ) internal returns (uint256 added, uint256 skipped) {
        for (uint256 i = 0; i < addressesToAdd.length; ++i) {
            guard(addressesToAdd[i]);
            if (set.add(addressesToAdd[i])) {
                added += 1;
            } else {
                skipped += 1;
            }
        }
    }

    /**
     * @notice Removes every address in `addressesToRemove` from `set`, skipping absent entries.
     * @dev No guard: removal has no invalid input. Removing an address that is not present is an
     * idempotent no-op, counted in `skipped`.
     * @param set The address set to modify.
     * @param addressesToRemove The addresses to remove.
     * @return removed The number of addresses actually removed.
     * @return skipped The number of addresses that were not present.
     */
    function removeBatch(EnumerableSet.AddressSet storage set, address[] calldata addressesToRemove)
        internal
        returns (uint256 removed, uint256 skipped)
    {
        for (uint256 i = 0; i < addressesToRemove.length; ++i) {
            if (set.remove(addressesToRemove[i])) {
                removed += 1;
            } else {
                skipped += 1;
            }
        }
    }
}
