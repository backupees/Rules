// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

/**
 * @title RuleAddressSetInvariantStorage — roles and errors for the address-set rule.
 */
abstract contract RuleAddressSetInvariantStorage {
    /* ============ Role ============ */
    /**
     * @notice Role allowed to remove addresses from the set.
     */
    bytes32 public constant ADDRESS_LIST_REMOVE_ROLE = keccak256("ADDRESS_LIST_REMOVE_ROLE");
    /**
     * @notice Role allowed to add addresses to the set.
     */
    bytes32 public constant ADDRESS_LIST_ADD_ROLE = keccak256("ADDRESS_LIST_ADD_ROLE");

    /* ============ Custom errors ============ */
    /**
     * @notice Thrown when trying to add an address that is already listed.
     */
    error RuleAddressSet_AddressAlreadyListed();

    /**
     * @notice Thrown when trying to remove an address that is not listed.
     */
    error RuleAddressSet_AddressNotFound();

    /**
     * @notice Thrown when trying to add the zero address to the set.
     * @dev The zero address is the ERC-20 mint/burn sentinel, not a participant. Listing it would
     *      make `isVerified(address(0))` / `contains(address(0))` return `true`, contradicting
     *      ERC-3643. Mint/burn permission is governed by the explicit `allowMint` / `allowBurn`
     *      flags instead.
     */
    error RuleAddressSet_ZeroAddressNotAllowed();
}
