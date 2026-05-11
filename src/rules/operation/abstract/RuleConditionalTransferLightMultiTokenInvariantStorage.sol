// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleSharedInvariantStorage} from "../../validation/abstract/invariant/RuleSharedInvariantStorage.sol";

abstract contract RuleConditionalTransferLightMultiTokenInvariantStorage is RuleSharedInvariantStorage {
    /* ============ Role ============ */
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /* ============ State variables ============ */
    string constant TEXT_TRANSFER_REQUEST_NOT_APPROVED = "ConditionalTransferLightMultiToken: The request is not approved";
    uint8 public constant CODE_TRANSFER_REQUEST_NOT_APPROVED = 46;

    /* ============ Events ============ */
    event TransferApproved(address indexed token, address indexed from, address indexed to, uint256 value, uint256 count);
    event TransferExecuted(address indexed token, address indexed from, address indexed to, uint256 value, uint256 remaining);
    event TransferApprovalCancelled(
        address indexed token, address indexed from, address indexed to, uint256 value, uint256 remaining
    );

    /* ============ Custom error ============ */
    error RuleConditionalTransferLightMultiToken_TransferExecutorUnauthorized(address account);
    error RuleConditionalTransferLightMultiToken_InsufficientAllowance(
        address token, address owner, uint256 allowance, uint256 required
    );
    error RuleConditionalTransferLightMultiToken_InvalidToken();
    error RuleConditionalTransferLightMultiToken_TransferNotApproved();
    error RuleConditionalTransferLightMultiToken_TransferApprovalNotFound();
}
