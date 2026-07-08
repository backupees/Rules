// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleSharedInvariantStorage} from "../../invariant/RuleSharedInvariantStorage.sol";

/**
 * @title RuleERC2980InvariantStorage — constants, roles, events and errors for the ERC-2980 rule.
 */
abstract contract RuleERC2980InvariantStorage is RuleSharedInvariantStorage {
    /* ============ String message ============ */
    /**
     * @notice Restriction message returned when the sender is frozen.
     */
    string constant TEXT_ADDRESS_FROM_IS_FROZEN = "The sender address is frozen";
    /**
     * @notice Restriction message returned when the recipient is frozen.
     */
    string constant TEXT_ADDRESS_TO_IS_FROZEN = "The recipient address is frozen";
    /**
     * @notice Restriction message returned when the spender is frozen.
     */
    string constant TEXT_ADDRESS_SPENDER_IS_FROZEN = "The spender address is frozen";
    /**
     * @notice Restriction message returned when the recipient is not whitelisted.
     */
    string constant TEXT_ADDRESS_TO_NOT_WHITELISTED = "The recipient is not in the whitelist";

    /* ============ Code ============ */
    // It is very important that each rule uses a unique code
    /**
     * @notice Restriction code returned when the sender is frozen.
     */
    uint8 public constant CODE_ADDRESS_FROM_IS_FROZEN = 60;
    /**
     * @notice Restriction code returned when the recipient is frozen.
     */
    uint8 public constant CODE_ADDRESS_TO_IS_FROZEN = 61;
    /**
     * @notice Restriction code returned when the spender is frozen.
     */
    uint8 public constant CODE_ADDRESS_SPENDER_IS_FROZEN = 62;
    /**
     * @notice Restriction code returned when the recipient is not whitelisted.
     */
    uint8 public constant CODE_ADDRESS_TO_NOT_WHITELISTED = 63;

    /* ============ Roles ============ */
    /**
     * @notice Role allowed to add addresses to the whitelist.
     */
    bytes32 public constant WHITELIST_ADD_ROLE = keccak256("WHITELIST_ADD_ROLE");
    /**
     * @notice Role allowed to remove addresses from the whitelist.
     */
    bytes32 public constant WHITELIST_REMOVE_ROLE = keccak256("WHITELIST_REMOVE_ROLE");
    /**
     * @notice Role allowed to add addresses to the frozenlist.
     */
    bytes32 public constant FROZENLIST_ADD_ROLE = keccak256("FROZENLIST_ADD_ROLE");
    /**
     * @notice Role allowed to remove addresses from the frozenlist.
     */
    bytes32 public constant FROZENLIST_REMOVE_ROLE = keccak256("FROZENLIST_REMOVE_ROLE");

    /* ============ Events ============ */
    /**
     * @notice Emitted when multiple addresses are added to the whitelist.
     * @param targetAddresses Addresses added to the whitelist.
     */
    event AddWhitelistAddresses(address[] targetAddresses);
    /**
     * @notice Emitted when multiple addresses are removed from the whitelist.
     * @param targetAddresses Addresses removed from the whitelist.
     */
    event RemoveWhitelistAddresses(address[] targetAddresses);
    /**
     * @notice Emitted when a single address is added to the whitelist.
     * @param targetAddress Address added to the whitelist.
     */
    event AddWhitelistAddress(address indexed targetAddress);
    /**
     * @notice Emitted when a single address is removed from the whitelist.
     * @param targetAddress Address removed from the whitelist.
     */
    event RemoveWhitelistAddress(address indexed targetAddress);

    /**
     * @notice Emitted when multiple addresses are added to the frozenlist.
     * @param targetAddresses Addresses added to the frozenlist.
     */
    event AddFrozenlistAddresses(address[] targetAddresses);
    /**
     * @notice Emitted when multiple addresses are removed from the frozenlist.
     * @param targetAddresses Addresses removed from the frozenlist.
     */
    event RemoveFrozenlistAddresses(address[] targetAddresses);
    /**
     * @notice Emitted when a single address is added to the frozenlist.
     * @param targetAddress Address added to the frozenlist.
     */
    event AddFrozenlistAddress(address indexed targetAddress);
    /**
     * @notice Emitted when a single address is removed from the frozenlist.
     * @param targetAddress Address removed from the frozenlist.
     */
    event RemoveFrozenlistAddress(address indexed targetAddress);

    /* ============ Custom errors ============ */
    error RuleERC2980_InvalidTransfer(address rule, address from, address to, uint256 value, uint8 code);
    error RuleERC2980_InvalidTransferFrom(
        address rule, address spender, address from, address to, uint256 value, uint8 code
    );
    error RuleERC2980_AddressAlreadyListed();
    error RuleERC2980_AddressNotFound();
}
