# Rule Max Total Supply

[TOC]

This rule restricts minting so that the token's total supply never exceeds a configured maximum. Only mint operations (`from == address(0)`) are checked. Regular transfers between holders and burns are not affected.

## Configuration

### Constructor parameters

| Parameter | Description |
| --- | --- |
| `admin` | Address granted `DEFAULT_ADMIN_ROLE` (implicitly holds all roles) |
| `tokenContract_` | Address of the token contract; must be non-zero, must have code, and its `totalSupply()` must be callable |
| `maxTotalSupply_` | Initial maximum total supply cap |

### Post-deployment configuration

Both the cap and the token contract address can be updated by the admin after deployment.

## Schema

### Graph

![surya_graph_RuleMaxTotalSupply](../surya/surya_graph/surya_graph_RuleMaxTotalSupply.sol.png)

### Inheritance

![surya_inheritance_RuleMaxTotalSupply](../surya/surya_inheritance/surya_inheritance_RuleMaxTotalSupply.sol.png)

### Flow with a CMTAT token

The sequence below shows how the rule participates when a CMTAT token (with this rule configured in its RuleEngine) processes a mint. Only mints (`from == address(0)`) are gated; transfers and burns pass.

![RuleMaxTotalSupply flow with a CMTAT token](../img/rule-max-total-supply-flow.png)

_Diagram source: doc/img/rule-max-total-supply-flow.puml._

## Restriction codes

| Constant | Code | Meaning |
| --- | --- | --- |
| `CODE_MAX_TOTAL_SUPPLY_EXCEEDED` | 50 | Mint would cause total supply to exceed the maximum |
| `CODE_SUPPLY_ORACLE_UNAVAILABLE` | 51 | `tokenContract.totalSupply()` reverted, or the token has lost its code |

## Access Control

The default admin is the address passed as `admin` in the constructor. It is granted `DEFAULT_ADMIN_ROLE`, which implicitly holds all roles. All privileged operations are gated on `DEFAULT_ADMIN_ROLE`.

| Role | Description |
| --- | --- |
| `DEFAULT_ADMIN_ROLE` | May update the supply cap and token contract address |


## Methods

### `setMaxTotalSupply(uint256 newMaxTotalSupply)`

Updates the maximum total supply cap. Restricted to `DEFAULT_ADMIN_ROLE`. Emits `MaxTotalSupplyUpdated`.

### `setTokenContract(address newTokenContract)`

Updates the reference to the token contract. Reverts if the address is zero, has no code, or its `totalSupply()` is not callable. Restricted to `DEFAULT_ADMIN_ROLE`. Emits `TokenContractUpdated`.

### `maxTotalSupply() → uint256`

Returns the current maximum total supply.

### `tokenContract() → ITotalSupply`

Returns the current token contract address.

## Transfer restriction logic

The rule only acts on mint operations (i.e. `from == address(0)`). It reads `tokenContract.totalSupply()` and rejects the mint if `totalSupply + value > maxTotalSupply`. Transfers and burns always pass.

### Read-path safety

`detectTransferRestriction` / `canTransfer` are ERC-1404 / ERC-3643 views that MUST NOT revert, so the supply read is guarded: a `tokenContract` that has lost its code, or whose `totalSupply()` reverts (a proxy upgraded to something broken, or a pausable implementation reverting while paused), yields `CODE_SUPPLY_ORACLE_UNAVAILABLE` (51) rather than propagating the failure. The comparison also uses remaining headroom (`value > maxTotalSupply - currentSupply`) instead of `currentSupply + value`, which could overflow.

Configuration validates the token up front — non-zero, has code, and `totalSupply()` callable — so an unusable token fails loudly at setup instead of silently blocking every mint later. The code-length check is explicit rather than relying on the uncatchable extcodesize revert that the probe would incidentally produce.

The trust placed in `tokenContract` is therefore narrower than it looks: it is trusted to report an **accurate** supply, which nothing on-chain can verify, but it is **not** trusted to stay callable.

#### Deployment precondition: EIP-6780 (Cancun or later)

`try/catch` does not catch a call to a codeless address — Solidity's `extcodesize` check reverts *uncatchably*. The revert-free guarantee therefore assumes `tokenContract` still has code at read time, which holds because the setters require code at configuration and **EIP-6780** (Cancun) restricts `SELFDESTRUCT` to same-transaction accounts. There is no runtime code-length re-check, because it would be unreachable on any supported chain; `foundry.toml` targets `prague`. On a chain without EIP-6780, re-introduce the guard (~100 gas per call site — the account is warmed either way, so it does not cost a full cold `EXTCODESIZE`).

## Usage scenario

The operator deploys `RuleMaxTotalSupply` with `tokenContract = CMTAT_address` and `maxTotalSupply = 1_000_000`. The rule is registered in the `RuleEngine`. When the issuer mints 100,000 tokens and total supply is already 950,000, the mint is rejected with code 50. Transfers between existing holders continue unaffected.
