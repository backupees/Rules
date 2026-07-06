# Rule Conditional Transfer Light MultiToken

[TOC]

`RuleConditionalTransferLightMultiToken` is an operation rule that requires explicit operator approval before each transfer, with approvals scoped per token.

Approval key:

- `keccak256(token, from, to, value)`

This prevents approval reuse across tokens when the rule receives token-specific caller context (for example, direct token callbacks to the rule).

## Schema

### Graph

![surya_graph_RuleConditionalTransferLightMultiToken](../surya/surya_graph/surya_graph_RuleConditionalTransferLightMultiToken.sol.png)

### Inheritance

![surya_inheritance_RuleConditionalTransferLightMultiToken](../surya/surya_inheritance/surya_inheritance_RuleConditionalTransferLightMultiToken.sol.png)

### Flow with a CMTAT token

The sequence below shows the two-phase flow with token-scoped approvals: an operator approves a `(token, from, to, value)` transfer, then the CMTAT token (with this rule configured in its RuleEngine) validates and consumes that approval. Approvals of one token cannot be spent by another.

![RuleConditionalTransferLightMultiToken flow with a CMTAT token](../img/rule-conditional-transfer-light-multitoken-flow.png)

_Diagram source: doc/img/rule-conditional-transfer-light-multitoken-flow.puml._

## Restriction codes

| Constant | Code | Meaning |
| --- | --- | --- |
| `CODE_TRANSFER_REQUEST_NOT_APPROVED` | 46 | No approval exists for this `(token, from, to, value)` tuple |

## Access control

| Role | Description |
| --- | --- |
| `DEFAULT_ADMIN_ROLE` | Manages all roles (AccessControl variant) |
| `OPERATOR_ROLE` | Approve/cancel approvals and call `approveAndTransferIfAllowed` |
| `COMPLIANCE_MANAGER_ROLE` | Bind/unbind token contracts |

## Methods

### `approveTransfer(address token, address from, address to, uint256 value)`

Approves one transfer for a specific token key.

### `cancelTransferApproval(address token, address from, address to, uint256 value)`

Removes one approval for a specific token key. Reverts if none exists.

### `approvedCount(address token, address from, address to, uint256 value) -> uint256`

Returns the remaining count for a specific token key.

### `approveAndTransferIfAllowed(address token, address from, address to, uint256 value) -> bool`

Approves and executes `safeTransferFrom` on the specified token, requiring allowance for this rule as spender.

### `transferred(...)`

Only bound tokens can call transfer execution hooks. Approval consumption uses the caller token (`msg.sender`) as the token key.

## Notes

- Mints and burns are exempt from approval consumption (`from == address(0)` or `to == address(0)`).
- This rule is ERC-20 operation-focused, like `RuleConditionalTransferLight`.
- In a shared `RuleEngine` topology, rule calls are made by the `RuleEngine` address, so `msg.sender` is the engine (not the token). In that case, token-scoped approval keys are not observable through current ERC-3643 / RuleEngine function signatures.
