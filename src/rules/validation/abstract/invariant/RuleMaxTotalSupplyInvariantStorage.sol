// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleSharedInvariantStorage} from "./RuleSharedInvariantStorage.sol";

/**
 * @title RuleMaxTotalSupplyInvariantStorage — constants and events for the max-total-supply rule.
 */
abstract contract RuleMaxTotalSupplyInvariantStorage is RuleSharedInvariantStorage {
    /**
     * @notice Restriction message returned when the max total supply would be exceeded.
     */
    string constant TEXT_MAX_TOTAL_SUPPLY_EXCEEDED = "Max total supply exceeded";

    // It is very important that each rule uses an unique code
    /**
     * @notice Restriction code returned when the max total supply would be exceeded.
     */
    uint8 public constant CODE_MAX_TOTAL_SUPPLY_EXCEEDED = 50;

    /**
     * @notice Emitted when the maximum total supply is updated.
     * @param newMaxTotalSupply New maximum total supply cap.
     */
    event MaxTotalSupplyUpdated(uint256 newMaxTotalSupply);
    /**
     * @notice Emitted when the tracked token contract is updated.
     * @param newTokenContract Address of the newly configured token contract.
     */
    event TokenContractUpdated(address indexed newTokenContract);

    error RuleMaxTotalSupply_InvalidTransfer(address rule, address from, address to, uint256 value, uint8 code);
    error RuleMaxTotalSupply_InvalidTransferFrom(
        address rule, address spender, address from, address to, uint256 value, uint8 code
    );
    error RuleMaxTotalSupply_TokenAddressZeroNotAllowed();
}
