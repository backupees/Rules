# Project Guide

## Purpose
Modular compliance-rule library for CMTAT / ERC-3643 security tokens. Each rule enforces a transfer restriction (whitelist, spender whitelist, blacklist, sanctions, max supply, identity, conditional approval, mint quota) and can be used standalone or composed via a `RuleEngine`.

## Architecture Overview
A rule answers two questions about a proposed token movement:
- **Read path** — `detectTransferRestriction` / `detectTransferRestrictionFrom` / `canTransfer` / `canTransferFrom` return an ERC-1404 restriction code (`0` = OK). These are views and must not revert.
- **Write path** — `transferred` / `created` / `destroyed` are called by the token *after* it has decided to move value; the rule **reverts** to block, and may mutate state.

### The two integration topologies (this determines `msg.sender` inside a rule)
```
Topology A — "RuleEngine mode" (default)
  CMTAT ──transferred(spender,from,to,value)──▶ RuleEngine ──transferred(...)──▶ Rule
                                                              msg.sender == RuleEngine
  ⇒ bind the RuleEngine to an operation rule, not the token.

Topology B — "direct mode" (CMTAT.setRuleEngine(rule))
  CMTAT ──transferred(spender,from,to,value)──▶ Rule
                                                 msg.sender == CMTAT token
  ⇒ bind the token.
```
Operation rules that treat `msg.sender` or `getTokenBound()` as a *token identity* behave differently in the two topologies. `approveAndTransferIfAllowed` only works in Topology B.

### The mint/burn `spender` convention (CMTAT v3.3+)
`CMTAT._mintOverride` calls `_checkTransferred(_msgSender(), address(0), to, value)`, so **on every mint the minter's address arrives at each rule as `spender`** via the 4-arg `transferred` overload. Plain `transfer()` passes `spender == address(0)` and takes the 3-arg path.

- `RuleWhitelist`, `RuleSpenderWhitelist`, `RuleWhitelistWrapper` explicitly exempt mint/burn from the spender check.
- `RuleIdentityRegistry`, `RuleBlacklist`, `RuleSanctionsList`, `RuleERC2980` do **not** — they screen the minter. For the deny-lists this is intended; for `RuleIdentityRegistry` it means the minter must itself be identity-verified (see `RESULT.md` F-1).
- `RuleMintAllowance` is the only rule that *uses* the mint spender: it debits `mintAllowance[spender]`.

Full per-rule semantics (who each rule screens, mint/burn handling, unset-oracle behaviour, stateful?, authoritative view) are tabulated in `doc/technical/RULE_SEMANTICS.md` — consult it before assuming any rule behaves like its siblings.

## Key Directories
| Path | Description |
|---|---|
| `src/rules/validation/` | Read-only rules (view functions, no state changes during transfer) |
| `src/rules/operation/` | Read-write rules (modify state on transfer) |
| `src/rules/validation/abstract/core/` | `RuleTransferValidation` (ERC-1404/3643/7551 views), `RuleNFTAdapter` (ERC-7943 + `ITransferContext` overloads), `RuleWhitelistShared` |
| `src/rules/validation/abstract/` | Shared base contracts and invariant storage |
| `src/rules/interfaces/` | Shared interfaces (`IAddressList`, `IIdentityRegistry`, `ISanctionsList`, `ITotalSupply`, `ITransferContext`, `IERC2980`, `IERC7943NonFungibleCompliance`) |
| `src/modules/` | Reusable modules (`AccessControlModuleStandalone`, `MetaTxModuleStandalone`, `VersionModule`, `Ownable2StepERC165Module`) |
| `test/` | Foundry tests, one folder per rule |
| `lib/` | Git submodule dependencies (do not edit) |

## Key Files to Read First
1. `src/rules/validation/abstract/core/RuleTransferValidation.sol` — the read-path interface every rule implements; declares the `_detectTransferRestriction*` hooks.
2. `src/rules/validation/abstract/core/RuleNFTAdapter.sol` — adds the ERC-7943 `tokenId` overloads and the `ITransferContext` struct entrypoints; declares the `_transferred*` write hooks.
3. `src/rules/validation/abstract/RuleAddressSet/RuleAddressSet.sol` — the `EnumerableSet` membership machinery shared by whitelist/blacklist/spender-whitelist.
4. `src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol` — the approval state machine (`approvalCounts`, `_transferHash`).
5. `src/rules/operation/abstract/RuleMintAllowanceBase.sol` — the only rule keyed on the mint `spender`.
6. `lib/RuleEngine/src/RuleEngineBase.sol` — how a rule actually gets called.

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
| `RuleConditionalTransferLightMultiToken` / `…Ownable2Step` | Conditional transfers with approvals keyed `(token, from, to, value)`. **Direct-binding-only (Topology B)** — approvals are *consumed* under `msg.sender`, so this rule must NOT be added to a RuleEngine; behind an engine it either reverts or loses all per-token isolation. See `RESULT.md` F-4 and `doc/technical/RuleConditionalTransferLightMultiToken.md` |
| `RuleMintAllowance` / `RuleMintAllowanceOwnable2Step` | Per-minter mint quota, debited on the 4-arg `transferred(spender, from=0, to, value)` path. Requires CMTAT ≥ v3.3. `canTransfer` is **not** authoritative for this rule — use `canTransferFrom(minter, address(0), to, value)` |
| `AccessControlModuleStandalone` | Base RBAC module; admin implicitly holds all roles |
| `MetaTxModuleStandalone` | ERC-2771 meta-transaction support. Note: the operation rules deliberately do **not** inherit this, so `_msgSender()` used as a binding identity is never forwarder-controlled |
| `Ownable2StepERC165Module` | Shared ERC-165 advertisement (`IERC173`, `IOwnable2Step`) for the Ownable2Step variants |
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
| RuleWhitelist / RuleWhitelistWrapper | 21–23 |
| RuleSanctionsList | 30–32 |
| RuleBlacklist | 36–38 |
| RuleConditionalTransferLight / …MultiToken | 46 |
| RuleMaxTotalSupply | 50 |
| RuleIdentityRegistry | 55–57 |
| RuleERC2980 | 60–63 |
| RuleSpenderWhitelist | 66 |
| RuleMintAllowance | 70 |

## Conventions
- Each rule has an `InvariantStorage` abstract contract holding its constants, custom errors, and events.
- Access control is implemented via an abstract `_authorize*()` method overridden by concrete subclasses (template method pattern).
- AccessControl variants must use `onlyRole(ROLE)` in `_authorize*()` methods (avoid direct `_checkRole`).
- **All `_authorize*()` / `_only*()` access-control hooks are `internal view virtual`** — both the abstract declaration and every override. An authorization hook checks and reverts; it must never mutate state, and `view` makes that a compiler-enforced invariant rather than a convention. It is free: these are `internal`, so `view` costs no gas and changes no runtime behaviour. Both OZ check functions (`AccessControl._checkRole`, `Ownable._checkOwner`) are `view`, so every hook can be.
  - **One documented exception**: `RuleConditionalTransferLightMultiTokenBase._authorizeComplianceBindingChange` cannot be `view`, because it delegates to `_onlyComplianceManager()`, which `lib/RuleEngine` declares non-`view` (Solidity checks mutability against a virtual's *declared* type, not the installed override). If you hit this constraint elsewhere, document why inline — do not silently drop `view` from a hook.
- AccessControl variants treat the default admin as having all roles via `hasRole`, but the admin may not appear in role member enumerations unless explicitly granted.
- All rules implement `IERC3643Version` via `VersionModule`; the current version string is `"0.4.0"` (asserted by `test/Version.t.sol`).
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

## Security Findings Reference
- [`THREAT_MODEL.md`](THREAT_MODEL.md) — trust model, 30 catalogued threats with IDs, data-flow diagrams, 12 invariants.
- [`RESULT.md`](RESULT.md) — findings (0 High/Medium, 2 Low, 8 Info), invariant and access-control verification, disposition of every threat ID.
- [`TEST_IMPROVEMENT.md`](TEST_IMPROVEMENT.md) — test-gap analysis and the deferred test backlog.
- [`test/ThreatModel/ThreatModelTests.t.sol`](test/ThreatModel/ThreatModelTests.t.sol) — 18 PoCs. Tests suffixed `_CurrentBehaviour` assert behaviour the audit considers wrong; **fixing the underlying issue must make them fail**, at which point update the test and the finding together.

Gotchas worth knowing before you change anything:
- `HelperContract` already inherits `RuleConditionalTransferLightInvariantStorage`; inheriting the multi-token variant alongside it is a compile error (`OPERATOR_ROLE`, `CODE_TRANSFER_REQUEST_NOT_APPROVED` clash).
- `RuleWhitelistWrapperBase._detectTransferRestrictionForTargets` short-circuits once every target address is resolved, so a broken child rule may never be reached for some address pairs.
- `RuleWhitelistWrapper` does not ERC-165-check its child rules (unlike `RuleEngineBase._checkRule`); a non-`IAddressList` child bricks the scan.
