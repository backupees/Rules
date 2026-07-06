# Project Guide

## Purpose
Modular compliance-rule library for CMTAT / ERC-3643 security tokens. Each rule enforces a transfer restriction (whitelist, spender whitelist, blacklist, sanctions, max supply, identity, conditional approval) and can be used standalone or composed via a `RuleEngine`.

## Key Directories
| Path | Description |
|---|---|
| `src/rules/validation/` | Read-only rules (view functions, no state changes during transfer) |
| `src/rules/operation/` | Read-write rules (modify state on transfer) |
| `src/rules/validation/abstract/` | Shared base contracts and invariant storage |
| `src/rules/interfaces/` | Shared interfaces (`IAddressList`, `IIdentityRegistry`, `ISanctionsList`) |
| `src/modules/` | Reusable modules (`AccessControlModuleStandalone`, `MetaTxModuleStandalone`, `VersionModule`) |
| `test/` | Foundry tests, one folder per rule |
| `lib/` | Git submodule dependencies (do not edit) |

## Main Contracts
| Contract | Role |
|---|---|
| `RuleWhitelist` / `RuleWhitelistOwnable2Step` | Allow transfers only between whitelisted addresses |
| `RuleWhitelistWrapper` / `Ownable2Step` | Aggregate multiple whitelist rules (OR logic) |
| `RuleBlacklist` / `RuleBlacklistOwnable2Step` | Block transfers involving blacklisted addresses |
| `RuleSanctionsList` | Block sanctioned addresses via Chainalysis oracle |
| `RuleMaxTotalSupply` | Cap minting so total supply never exceeds a maximum |
| `RuleIdentityRegistry` | Check ERC-3643 identity registry for participant verification |
| `RuleSpenderWhitelist` / `RuleSpenderWhitelistOwnable2Step` | Allow `transferFrom` only when spender is whitelisted; direct transfers are always allowed |
| `RuleERC2980` | ERC-2980 Swiss Compliant rule: whitelist (recipient-only) + frozenlist (blocks sender, recipient, and spender for `transferFrom`); frozenlist takes priority |
| `RuleERC2980Ownable2Step` | Ownable2Step variant of RuleERC2980 |
| `RuleConditionalTransferLight` | Require operator approval before each transfer; bound to exactly one token at a time (`bindToken` reverts if a token is already bound; use `unbindToken` first to migrate) |
| `RuleConditionalTransferLightOwnable2Step` | Owner-only approval and execution for conditional transfers |
| `RuleMintAllowance` | Enforce a per-minter mint quota; each mint reduces the minter's allowance; operator can set/increase/decrease allowances; bind to RuleEngine address before use |
| `RuleMintAllowanceOwnable2Step` | Ownable2Step variant of RuleMintAllowance |
| `AccessControlModuleStandalone` | Base RBAC module; admin implicitly holds all roles |
| `MetaTxModuleStandalone` | ERC-2771 meta-transaction support |
| `VersionModule` | Implements `IERC3643Version`; returns the contract version string |

## Dependencies (lib/)
- `openzeppelin-contracts` v5.6.1 — `AccessControl`, `Ownable2Step`, `EnumerableSet`, `ERC2771Context`
- `openzeppelin-contracts-upgradeable` v5.6.1
- `CMTAT` v3.0.0 — `IERC1404`, `IERC3643`, `IRuleEngine` interfaces
- `RuleEngine` v3.0.0-rc4 — `IRule`, `RulesManagementModule`
- `forge-std` — Foundry test utilities

Remappings are in `remappings.txt`; aliases used in source: `OZ/`, `CMTAT/`, `RuleEngine/`.

## Toolchain
```bash
forge build          # compile
forge test           # run all tests
forge test -vvv      # verbose output
```
Foundry config: `foundry.toml` (solc 0.8.34, EVM prague, optimizer 200 runs).

## Restriction Code Ranges
| Rule | Codes |
|---|---|
| RuleWhitelist | 21–23 |
| RuleSanctionsList | 30–32 |
| RuleBlacklist | 36–38 |
| RuleConditionalTransferLight | 46 |
| RuleMaxTotalSupply | 50 |
| RuleIdentityRegistry | 55–57 |
| RuleERC2980 | 60–63 |
| RuleSpenderWhitelist | 66 |
| RuleMintAllowance | 70 |

## Conventions
- Each rule has an `InvariantStorage` abstract contract holding its constants, custom errors, and events.
- Access control is implemented via an abstract `_authorize*()` method overridden by concrete subclasses (template method pattern).
- AccessControl variants must use `onlyRole(ROLE)` in `_authorize*()` methods (avoid direct `_checkRole`).
- AccessControl variants treat the default admin as having all roles via `hasRole`, but the admin may not appear in role member enumerations unless explicitly granted.
- All rules implement `IERC3643Version` via `VersionModule`; the current version string is `"0.2.0"`.
- **ERC-165 interface IDs**: `type(IFoo).interfaceId` only XORs selectors defined directly on `IFoo` and does NOT include selectors from inherited interfaces. Always use the pre-computed library constants instead: `ERC1404ExtendInterfaceId.ERC1404EXTEND_INTERFACE_ID` (from `CMTAT/library/`), `RuleEngineInterfaceId.RULE_ENGINE_INTERFACE_ID` (from `CMTAT/library/`), and `RuleInterfaceId.IRULE_INTERFACE_ID` (from `RuleEngine/modules/library/`). If no pre-computed constant exists for an interface, define a flat mock interface that redeclares all functions from the full inheritance tree and use `type(IFooFlattened).interfaceId` to compute the correct value (see `lib/RuleEngine/src/mocks/IRuleInterfaceIdHelper.sol` for the established pattern).
- Batch add/remove operations are non-reverting (skip duplicates); single-item operations revert on invalid input.
- All `internal` functions should be marked `virtual`.
- Do not create git commits; provide commit messages only when requested.
- Always run full tests (`forge test`) after any code modification, including lint-driven or mechanical refactors, before reporting completion.
- Use `require(condition, CustomError(...))` for custom errors; avoid direct `revert CustomError(...)`.
- `AGENTS.md` and `CLAUDE.md` are identical — always update both together.
- Always update README.md with the latest change
- New rule or features implemented: create/update technical documentation in `doc/technical`, update README, create/update test (target: 100% of code coverage), update CHANGELOG.md. Code coverage, run `forge coverage --report summary`
- After each implemented feature or fix, provide a one-line GitHub commit message for all changes since the last commit.
