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
- `RuleMaxTotalSupply` and `RuleChainlinkPoR` ignore the spender entirely — they cap *supply*, not identities, and act only when `from == address(0)`.

Full per-rule semantics (who each rule screens, mint/burn handling, unset-oracle behaviour, stateful?, authoritative view) are tabulated in `doc/technical/RULE_SEMANTICS.md` — consult it before assuming any rule behaves like its siblings.

### Standards conformance (non-negotiable)
Rules that implement a standardized interface must match that standard's semantics, not merely its function signatures. Specs are vendored in `doc/ERCSpecification/` — read them before changing a rule's screening logic.

- **`RuleIdentityRegistry` conforms to ERC-3643 (enforced, I-1).** The spec mandates that **only the receiver** be identity-verified: *"The receiver MUST be whitelisted on the Identity Registry and verified"*; `transferFrom` "works the same way"; `mint` and `forcedTransfer` "only require the receiver"; `burn` "bypasses all checks on eligibility". The sender, the spender and the minter are **not** required to be verified — do not re-add those checks as defaults. Screening the sender **traps de-listed holders** (the spec checks only the receiver precisely so a lapsed investor can still exit their position). Stricter screening is available as an explicit opt-in via the `checkSender` / `checkSpender` flags, both defaulting to `false`.
- **`isVerified(address(0))` must be `false`** — ERC-3643 defines `isVerified` as "is this wallet a valid investor holding the required claims", and `address(0)` is not a wallet. Likewise `RuleERC2980`'s `whitelist(address)` / `frozenlist(address)` are MANDATORY ERC-2980 getters and must not return `true` for `address(0)`. **Enforced (I-12):** mint/burn permission is an explicit `allowMint` / `allowBurn` flag, and the zero address can never enter any list — single adds revert, batch adds skip it. Never re-introduce "whitelist `address(0)` to enable mint/burn".

## Key Directories
| Path | Description |
|---|---|
| `src/rules/validation/` | Read-only rules (view functions, no state changes during transfer) |
| `src/rules/operation/` | Read-write rules (modify state on transfer) |
| `src/rules/validation/abstract/core/` | `RuleTransferValidation` (ERC-1404/3643/7551 views), `RuleNFTAdapter` (ERC-7943 + `ITransferContext` overloads), `RuleWhitelistShared` |
| `src/rules/validation/abstract/` | Shared base contracts and invariant storage |
| `src/rules/interfaces/` | Shared interfaces (`IAddressList`, `IIdentityRegistry`, `ISanctionsList`, `ITotalSupply`, `ITransferContext`, `IERC2980`, `IERC7943NonFungibleCompliance`, `AggregatorV3Interface`, `IDecimals`) |
| `src/registry/` | Contracts filling a token's **identity registry** slot, not its compliance slot (`IdentityRegistryWhitelist`). Not rules: no `IRule`, never added to a RuleEngine |
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
| `RuleReceiverWhitelist` / `RuleReceiverWhitelistOwnable2Step` | Screen **only the receiver**, reproducing ERC-3643 eligibility. Sender and spender are never checked — do not add those, it traps de-listed holders (same reasoning as I-1). Burn is exempt (`to == address(0)` can never be listed); mint is screened on the receiver with no `allowMint` flag. Code 81 |
| `RuleWhitelistWrapper` / `Ownable2Step` | Aggregate multiple whitelist rules (OR logic) |
| `RuleBlacklist` / `RuleBlacklistOwnable2Step` | Block transfers involving blacklisted addresses |
| `RuleSanctionsList` | Block sanctioned addresses via Chainalysis oracle |
| `RuleMaxTotalSupply` | Cap minting so total supply never exceeds a maximum |
| `RuleChainlinkPoR` / `RuleChainlinkPoROwnable2Step` | Cap minting at the reserves reported by a Chainlink Proof of Reserve feed (`AggregatorV3Interface`). The limit equals the reported reserves exactly — no margin parameter (deliberately dropped from Chainlink's `SecureMintPolicy`); compose with `RuleMaxTotalSupply` for a static cap. Mints only; transfers and burns always pass, so a stale or broken feed never traps holders. The read path is guarded (`code.length` check + `try/catch` + saturating arithmetic) so the ERC-1404 views never revert |
| `RuleIdentityRegistry` | Check ERC-3643 identity registry for participant verification |
| `IdentityRegistryWhitelist` | The mirror image of `RuleIdentityRegistry`: **is** an ERC-3643 identity registry, backed by a whitelist, so no ONCHAINID is needed. Keeps **no identity state** — `_identity` and `_country` are accepted for signature compatibility then discarded, and `investorCountry` is a constant 0; do not add identity storage back. Inherits `RuleAddressSetInternal` (the same set machinery as `RuleWhitelist`) rather than deploying or re-implementing a whitelist — **only the internal layer**, because `RuleAddressSet`'s public `addAddress`/`removeAddress` are not `virtual` and so could not maintain the `keyHasPurpose` reverse index; a second write path would produce verified-but-unrecoverable wallets. Installed with `token.setIdentityRegistry()`. Implements **no** ERC-734 surface: `recoveryAddress` needs a real ONCHAINID as `_investorOnchainID`. A `keyHasPurpose` implementation was tried and removed — the agent chooses which contract that call lands on, so it added no security while forcing a hash-to-wallet reverse index and duplicate-tolerant registration. Do not re-add it. The token itself must hold `IDENTITY_REGISTRAR_ROLE`. See `doc/technical/IdentityRegistryWhitelist.md` |
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

FOUNDRY_PROFILE=erc3643 forge test   # the real-ERC-3643-token suite (see below)
```
Foundry config: `foundry.toml` (solc 0.8.34, EVM prague, optimizer 200 runs).

**There are two profiles, and `forge test` alone does not run everything.** The vendored ERC-3643
`Token.sol` pins `pragma solidity 0.8.30` *exactly*, which cannot share a compilation unit with our
0.8.34. So `test/ERC3643Real/**` is in the default profile's `skip` list and is built by
`[profile.erc3643]` at solc 0.8.30 instead (our contracts are `^0.8.20`, so they compile there too).
CI must run **both** commands. Gotchas: profiles inherit unspecified keys from `[profile.default]`,
so that profile has to clear `skip = []` explicitly; and it writes to `out-erc3643/` to avoid
clobbering the 0.8.34 artifacts.

ERC-3643 imports `@onchain-id/solidity`, which is an npm package rather than a submodule and so is
not vendored. `test/utils/onchainid/` holds minimal `IIdentity` / `IClaimIssuer` stubs wired in by a
**context-scoped** remapping (`lib/ERC-3643/:@onchain-id/solidity/contracts/=test/utils/onchainid/`)
so they apply to the ERC-3643 build only. Only `keyHasPurpose` is ever called; everywhere else those
types appear as parameters or event fields, which canonicalise to `address` and affect no selector.

## Restriction Code Ranges
| Rule | Codes |
|---|---|
| RuleWhitelist / RuleWhitelistWrapper | 21–23, 24 (mint not allowed), 25 (burn not allowed) |
| RuleSanctionsList | 30–32 |
| RuleBlacklist | 36–38 |
| RuleConditionalTransferLight / …MultiToken | 46 |
| RuleMaxTotalSupply | 50, 51 (total supply unavailable) |
| RuleIdentityRegistry | 55–57 |
| RuleERC2980 | 60–63, 64 (mint not allowed), 65 (burn not allowed) |
| RuleSpenderWhitelist | 66 |
| RuleMintAllowance | 70 |
| RuleChainlinkPoR | 75 (reserves exceeded), 76 (feed stale), 77 (feed answer invalid), 78 (total supply unavailable) |
| RuleReceiverWhitelist | 81 |

## Conventions
- Each rule has an `InvariantStorage` abstract contract holding its constants, custom errors, and events.
- Access control is implemented via an abstract `_authorize*()` method overridden by concrete subclasses (template method pattern).
- AccessControl variants must use `onlyRole(ROLE)` in `_authorize*()` methods (avoid direct `_checkRole`).
- **All `_authorize*()` / `_only*()` access-control hooks are `internal view virtual`** — both the abstract declaration and every override. An authorization hook checks and reverts; it must never mutate state, and `view` makes that a compiler-enforced invariant rather than a convention. It is free: these are `internal`, so `view` costs no gas and changes no runtime behaviour. Both OZ check functions (`AccessControl._checkRole`, `Ownable._checkOwner`) are `view`, so every hook can be.
  - **One documented exception**: `RuleConditionalTransferLightMultiTokenBase._authorizeComplianceBindingChange` cannot be `view`, because it delegates to `_onlyComplianceManager()`, which `lib/RuleEngine` declares non-`view` (Solidity checks mutability against a virtual's *declared* type, not the installed override). If you hit this constraint elsewhere, document why inline — do not silently drop `view` from a hook.
- AccessControl variants treat the default admin as having all roles via `hasRole`, but the admin may not appear in role member enumerations unless explicitly granted.
- All rules **and `IdentityRegistryWhitelist`** implement `IERC3643Version` via `VersionModule`; the current version string is `"0.5.0"`. `test/Version.t.sol` asserts it for every deployable contract — keep it exhaustive, a half-covered version test reads as authoritative while missing the mirror it exists to catch.
- **ERC-165 interface IDs**: `type(IFoo).interfaceId` only XORs selectors defined directly on `IFoo` and does NOT include selectors from inherited interfaces. Always use the pre-computed library constants instead: `ERC1404ExtendInterfaceId.ERC1404EXTEND_INTERFACE_ID` (from `CMTAT/library/`), `RuleEngineInterfaceId.RULE_ENGINE_INTERFACE_ID` (from `CMTAT/library/`), and `RuleInterfaceId.IRULE_INTERFACE_ID` (from `RuleEngine/modules/library/`). If no pre-computed constant exists for an interface, define a flat mock interface that redeclares all functions from the full inheritance tree and use `type(IFooFlattened).interfaceId` to compute the correct value (see `lib/RuleEngine/src/mocks/IRuleInterfaceIdHelper.sol` for the established pattern).
- Batch add/remove operations are non-reverting (skip duplicates); single-item operations revert on invalid input.
- All `internal` functions should be marked `virtual`.
- Do not create git commits; provide commit messages only when requested.
- Always run full tests (`forge test`) after any code modification, including lint-driven or mechanical refactors, before reporting completion.
- Use `require(condition, CustomError(...))` for custom errors; avoid direct `revert CustomError(...)`.
- **No emoji in code comments or NatSpec.** Use a plain word marker instead: `WARNING:`, `NOTE:`, `IMPORTANT:`. Emoji render inconsistently across editors, terminals, `forge doc` output and diffs; they are not searchable (`grep WARNING` finds the marker, `grep ⚠️` depends on the shell); and they encode as multi-byte sequences that can be silently mangled by tooling. This applies to `src/`, `test/` and `script/`. Markdown documentation may use emoji freely — the restriction is Solidity comments only.
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
- `RuleChainlinkPoR` reads the feed's `decimals()` **live on every check** and deliberately does NOT cache it. Caching saves ~2,900 gas per mint but lets an aggregator migration that changes decimals mis-scale the reserves by `10 ** delta` with no on-chain signal — in the overstating direction that is unlimited unbacked minting. Both feed calls share the `code.length` guard (Solidity's extcodesize revert on a `try` to a codeless address is uncatchable) and `MAX_FEED_DECIMALS` is re-checked at read time, not just at configuration. Do not "optimise" this back into a cache.
- `RuleChainlinkPoR` (and `RuleMaxTotalSupply`) protect **one token per instance** with no on-chain guard: they read `totalSupply()` from the configured `tokenContract`, never from the token that triggered the check, and behind a RuleEngine they cannot learn that identity. One instance added to two RuleEngines evaluates both tokens against the first one's supply and feed — silently over-minting or freezing the second. Chainlink's `SecureMintPolicy` blocks this with `onInstall`/`PolicyAlreadyBound`; adding an equivalent here would mean making a stateless validation rule bindable, which is a library-wide decision. Documented, not fixed.
- `ADDRESS_LIST_ADD_ROLE` / `ADDRESS_LIST_REMOVE_ROLE` live in `RuleAddressSetRolesStorage`, inherited by `RuleAddressSet` (the public layer that enforces them) — **not** by `RuleAddressSetInternal`. Do not move them back into `RuleAddressSetInvariantStorage`: a contract reusing only the internal layer (`IdentityRegistryWhitelist`) would then publish two roles it never checks, and an operator granting one would get no privilege and no signal.
- `RuleChainlinkPoR` and `RuleMaxTotalSupply` both guard `tokenContract.totalSupply()` with a code-length check plus `try/catch`, returning a restriction code (78 and 51 respectively) rather than reverting, and both validate the token at configuration (non-zero, has code, `totalSupply()` callable). The ERC-1404 views MUST NOT revert — never call `totalSupply()` unguarded on a read path. Neither rule re-checks `code.length` at read time: `try/catch` cannot catch a call to a codeless address (Solidity's extcodesize check reverts uncatchably), but the setters require code and EIP-6780 (Cancun) makes that permanent, so the check would be unreachable. This is a **deployment precondition** (Cancun or later, `foundry.toml` targets `prague`), documented in each rule doc rather than enforced at runtime — do not re-add the guard unless targeting a pre-Cancun chain. `decimals()` stays optional on the token; `totalSupply()` is mandatory. The two rules use *different* constant names for the same idea (`CODE_TOTAL_SUPPLY_UNAVAILABLE` vs `CODE_SUPPLY_ORACLE_UNAVAILABLE`) because `HelperContract` inherits both invariant-storage contracts and identical identifiers would clash.
- `RuleChainlinkPoR` accepts `tokenDecimals == 0`. Chainlink's `SecureMintPolicy` requires 1–18, but CMTAT equity tokens report 0 decimals, so the lower bound was dropped. Do not re-add it.
