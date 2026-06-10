// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleSharedInvariantStorage} from "../../validation/abstract/invariant/RuleSharedInvariantStorage.sol";

abstract contract RuleMintAllowanceInvariantStorage is RuleSharedInvariantStorage {
    /* ============ Role ============ */
    bytes32 public constant ALLOWANCE_OPERATOR_ROLE = keccak256("ALLOWANCE_OPERATOR_ROLE");

    /* ============ State variables ============ */
    string constant TEXT_MINTER_ALLOWANCE_EXCEEDED = "MintAllowance: minter allowance exceeded";
    // It is very important that each rule uses a unique code
    uint8 public constant CODE_MINTER_ALLOWANCE_EXCEEDED = 70;

    /* ============ Events ============ */
    event MintAllowanceSet(address indexed minter, uint256 newAllowance);
    event MintAllowanceIncreased(address indexed minter, uint256 addedAmount, uint256 newAllowance);
    event MintAllowanceDecreased(address indexed minter, uint256 reducedAmount, uint256 newAllowance);
    event MintAllowanceConsumed(address indexed minter, uint256 consumed, uint256 remaining);

    /* ============ Custom error ============ */
    error RuleMintAllowance_AllowanceExceeded(address rule, address minter, uint256 allowance, uint256 amount);
    error RuleMintAllowance_DecreaseBelowZero(address minter, uint256 currentAllowance, uint256 reductionAmount);
    error RuleMintAllowance_TokenAlreadyBound();
}
