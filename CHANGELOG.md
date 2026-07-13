# CHANGELOG

Please follow [https://changelog.md/](https://changelog.md/) conventions.

## Semantic Version 2.0.0

Given a version number MAJOR.MINOR.PATCH, increment the:

1. MAJOR version when the new version makes:
   -  Incompatible proxy **storage** change internally or through the upgrade of an external library (OpenZeppelin)
   -  A significant change in external APIs (public/external functions) or in the internal architecture
2. MINOR version when the new version adds functionality in a backward compatible manner
3. PATCH version when the new version makes backward compatible bug fixes

See [https://semver.org](https://semver.org)

## Type of changes

- `Added` for new features.
- `Changed` for changes in existing functionality.
- `Deprecated` for soon-to-be removed features.
- `Removed` for now removed features.
- `Fixed` for any bug fixes.
- `Security` in case of vulnerabilities.

Reference: [keepachangelog.com/en/1.1.0/](https://keepachangelog.com/en/1.1.0/)

Custom changelog tag: `Dependencies`, `Documentation`, `Testing`

## Checklist

> Before a new release, perform the following tasks

- Code: Update the version name, variable VERSION
- Run formatter and linter

> forge fmt
> forge lint

- Documentation
  - Perform a code coverage and update the files in the corresponding directory [./doc/coverage](./doc/coverage)
  - Perform an audit with several audit tools (Mythril and Slither), update the report in the corresponding directory [./doc/security/audits/tools](./doc/security/audits/tools)
  - Update surya doc by running the 3 scripts in [./doc/script](./doc/script)
  - Update changelog



## Unreleased

### Added

- `RuleConditionalTransferLight`: **split the binding into two independent roles**, so the rule works fully behind a `RuleEngine`. New `bindRuleEngine(address)` / `unbindRuleEngine()` (compliance-manager gated, emitting `RuleEngineBound` / `RuleEngineUnbound`) authorise a RuleEngine to call the transfer execution hooks, while `bindToken` continues to designate the **ERC-20 token** the rule acts on. `transferred` now accepts a call from either the bound token or the bound RuleEngine (new `isTransferExecutor(address)` view). This fixes `approveAndTransferIfAllowed`, which was previously unusable behind a RuleEngine: the single binding slot had to be *both* the ERC-20 target and the authorised caller, and behind an engine those are different addresses — binding the engine broke the helper (an engine is not an ERC-20) while binding the token left the engine unauthorised and reverted every transfer and mint. Backward compatible: existing direct-binding deployments are unaffected, and a deployment that binds the engine via `bindToken` keeps working as before (though it should migrate to use both bindings). See finding F-3.
- `RuleConditionalTransferLightMultiToken`: new caller-explicit pre-flight views `detectTransferRestrictionForToken(token, from, to, value)` and `canTransferForToken(token, from, to, value)`. The standardized ERC-1404 / ERC-3643 views (`detectTransferRestriction`, `canTransfer`) derive the token key from `msg.sender`, so an off-chain `eth_call` from a wallet or explorer always read "not approved" even for an approved transfer; the new views take the token explicitly and give every caller the real answer. Additive — the standardized signatures are unchanged, and both paths are backed by the same internal helper so they can never disagree for the bound token.
- ERC-165: `RuleWhitelist`, `RuleBlacklist`, `RuleSpenderWhitelist` (and their `Ownable2Step` variants) now advertise the `IAddressList` interface (`0x5d10e182`). Purely additive — no call is rejected. This is the prerequisite for `RuleWhitelistWrapper` to interface-check its child rules (improvement I-4, finding F-5). Adds `AddressListInterfaceId` (pre-computed constant) and `IAddressListInterfaceIdHelper` (flattened interface used to derive it): `type(IAddressList).interfaceId` cannot be used, because it omits `contains(address)` inherited from `IIdentityRegistryContains`. `RuleWhitelistWrapper` deliberately does **not** advertise it — it exposes no address set of its own, so a wrapper cannot be nested inside another wrapper.
- `RuleConditionalTransferLight` / `RuleConditionalTransferLightMultiToken`: new `resetApproval(...)` operator function that discards **every** outstanding approval for a transfer key in one call (returns the cleared count, emits `TransferApprovalReset`). It deliberately does **not** require a bound token, so it can clean up approvals that survived an `unbindToken` — and, for the multi-token rule, approvals stranded under a key that can never be consumed.
- `RuleMintAllowance`: new `clearMintAllowances(address[] calldata minters)` operator function that zeroes the listed minters' quotas (non-reverting batch), for discarding stale quotas before rebinding.

### Fixed

- `RuleMaxTotalSupply`: `detectTransferRestriction` / `canTransfer` / `detectTransferRestrictionFrom` no longer revert with an arithmetic panic when `currentSupply + value` would overflow `uint256`. The mint check now compares against the remaining headroom (`value > maxTotalSupply - currentSupply`), so these ERC-1404 / ERC-3643 views always return a restriction code as required. Enforcement (`transferred`) is unchanged.

### Changed

- **BREAKING — `RuleWhitelist`, `RuleWhitelistWrapper`, `RuleERC2980`: mint/burn permission is now an explicit flag, not membership of `address(0)`.** Previously these rules enabled mint/burn by *whitelisting the zero address*, which made the standardized identity getters assert falsehoods: `isVerified(address(0))` returned `true` (ERC-3643 defines `isVerified` as "is this wallet a valid investor holding the required claims" — the zero address is not a wallet), and `RuleERC2980.whitelist(address(0))` returned `true` (a **mandatory** ERC-2980 getter). It also meant `removeAddress(address(0))` silently disabled all minting and burning.
  - New state: `allowMint` / `allowBurn`, with `setAllowMint(bool)` / `setAllowBurn(bool)` (admin/owner gated, emitting `AllowMintUpdated` / `AllowBurnUpdated`), so issuance can still be permanently closed at runtime while redemptions stay open.
  - New restriction codes: `RuleWhitelist` / `RuleWhitelistWrapper` → `24` (`CODE_MINT_NOT_ALLOWED`) and `25` (`CODE_BURN_NOT_ALLOWED`); `RuleERC2980` → `64` / `65`. A blocked mint now reports "minting is not allowed" instead of the misleading "sender is not whitelisted".
  - The zero address can no longer enter any list: single adds revert (`RuleAddressSet_ZeroAddressNotAllowed` / `RuleERC2980_ZeroAddressNotAllowed`), batch adds skip it silently per the non-reverting-batch convention.
  - **Constructors:** `RuleWhitelist(admin, forwarder, checkSpender, allowMintBurn)` keeps its shape — `allowMintBurn` now sets *both* flags instead of whitelisting `address(0)`. `RuleWhitelistWrapper` gains an `allowMintBurn` parameter (it holds no addresses of its own and must decide mint/burn itself). `RuleERC2980`'s third parameter is renamed `allowBurn` → `allowMintBurn` and now governs both operations.
  - **Deployer migration:** a deployment that enabled mint/burn by whitelisting `address(0)` must instead pass `allowMintBurn = true` (or call the setters). Permission semantics are otherwise unchanged: a permitted mint still requires a whitelisted **recipient**, and a permitted burn still requires a whitelisted **sender**.
- Access-control hooks: **all `_authorize*()` / `_only*()` hooks are now `internal view virtual`**, both the abstract declarations and every override. An authorization hook checks and reverts; `view` makes "authorization never mutates state" a compiler-enforced invariant rather than a convention. Compile-time only — `view` on an `internal` function has no gas or runtime impact. Normalised `RuleWhitelistWrapperBase._authorizeCheckSpenderManager` (declaration), the three `RuleWhitelistWrapper` overrides (which disagreed with their own `Ownable2Step` twin), and the six `_onlyComplianceManager` overrides across the operation rules. The convention is now recorded in `CLAUDE.md`/`AGENTS.md`. One documented exception remains: `RuleConditionalTransferLightMultiTokenBase._authorizeComplianceBindingChange` delegates to `_onlyComplianceManager()`, which `lib/RuleEngine` declares non-`view`, and Solidity checks mutability against a virtual's declared type — it can only become `view` once that is changed upstream.
- `RuleERC2980`: split the shared list-management errors into per-list errors so a revert identifies which list rejected. `RuleERC2980_AddressAlreadyListed` becomes `RuleERC2980_AddressAlreadyWhitelisted` / `RuleERC2980_AddressAlreadyFrozen`, and `RuleERC2980_AddressNotFound` becomes `RuleERC2980_AddressNotWhitelisted` / `RuleERC2980_AddressNotFrozen`. **Breaking (ABI):** the removed errors' 4-byte selectors no longer exist; off-chain tooling matching on them must update.

### Testing

- Add `test/TransferContext/OverloadParity.t.sol` — asserts overload parity across all 7 rules that inherit `RuleNFTAdapter`: every ERC-7943 `tokenId` overload returns exactly what its fungible counterpart returns (`tokenId` is ignored by design), the write overloads accept/reject identically, and the `ITransferContext` struct entrypoints dispatch to the same internal hooks. Closes the per-rule gap for `RuleBlacklist`, `RuleSanctionsList`, `RuleERC2980` and `RuleIdentityRegistry`, and pins threat `AC-5` (the `ctx` entrypoints are unguarded but view-only on validation rules, so they mutate nothing).
- Add `test/invariant/` — the project's first stateful invariant suite (`StdInvariant`, `fail_on_revert = true`). Handler-driven fuzzing over the two stateful rules: `RuleConditionalTransferLight` (approval conservation, `INV-5`) and `RuleMintAllowance` (exact quota accounting via a ghost mirror, `INV-7`). 4 invariants × 8 192 calls each, 0 reverts. The handlers also prove mint/burn never consume an approval and that non-mint transfers never touch a quota. Both invariants were mutation-verified (injecting an approval double-spend and an off-by-one quota deduction makes them fail). Adds an `[invariant]` section to `foundry.toml`.
- Add `test/ThreatModel/ThreatModelTests.t.sol` — 18 threat-model proof-of-concept tests (15 unit/integration, 3 fuzz) covering the identity-registry mint path, `RuleMaxTotalSupply` view overflow, the multi-token approval-key divergence, `approveAndTransferIfAllowed` under a `RuleEngine`, residual state after `unbindToken`, `_transferHash` injectivity, mint-quota accounting, and `RuleWhitelistWrapper` child-rule composition. Full suite: 425 tests, production line coverage 94.91%.

### Documentation

- `RuleConditionalTransferLightMultiToken`: document that the rule is **direct-binding-only** and **must not be added to a `RuleEngine`**. Approvals are recorded under the `token` argument but consumed under `msg.sender`, so behind an engine every wiring either reverts or silently loses per-token isolation. Added a "Deployment topology" section with the exhaustive case analysis to `doc/technical/RuleConditionalTransferLightMultiToken.md`, documented the caller-dependent `detectTransferRestriction`, and propagated the constraint to the README binding-model table, `RULE_SEMANTICS.md` and the project guide.
- `RuleWhitelistWrapper`: document the child-rule scan cost model and publish operator guidance. The wrapper makes one external `STATICCALL` per child (**~8.8k gas each**) and the scan runs during transfer *execution*, so it is paid by the transferring user on every transfer — not only in views. At the default `maxRules = 10` the worst case is ~90k gas per transfer (~121k with `checkSpender`). Two amplifiers are documented: a transfer that will be *rejected* never early-exits and therefore always scans all children, and `checkSpender = true` adds a third target address that must also be resolved. The scan is linear (marginal cost measured flat at ~8.8k gas/child from 25 to 200 children). Guidance: keep the child list at or below the default cap, order children by expected hit rate, and treat raising `maxRules` as a permanent per-transfer cost on every holder (a cap of 100 ⇒ ~884k gas/transfer, measured). This is a cost problem rather than a liveness one — transfers still fit in a block until roughly 3,400 children. The list size remains the **operator's responsibility**; no lower cap is hard-coded.
- Add `doc/technical/INVARIANT_TESTS.md` — documents the stateful invariant suite: handler architecture and ghost variables, each of the four invariants and what it proves, the mutation-testing negative controls, the coverage map against the threat-model invariants, and how to add a new invariant. Linked from a new "Invariant testing" section in the README.
- Add `doc/technical/RULE_SEMANTICS.md` — a per-rule comparison table (who each rule screens for `from` / `to` / spender on `transferFrom` / mint / burn, behaviour when the oracle/registry is unset, stateful?, and which pre-flight view is authoritative), with a highlights summary and link added to the README.
- `RuleMintAllowance`: document that `canTransfer` / `detectTransferRestriction` are **not authoritative** (hardcoded to "allowed" because the 3-arg path has no minter identity) and that a mint pre-flight must use the spender-aware `canTransferFrom(minter, address(0), to, value)` / `detectTransferRestrictionFrom`. Added a bold callout and an eligibility-views table to `doc/technical/RuleMintAllowance.md` and a warning to the README rule section.
- Add `THREAT_MODEL.md`, `RESULT.md` and `TEST_IMPROVEMENT.md` — manual security review of `src/` (0 High/Medium, 2 Low, 8 Info). Slither call-graph / inheritance / function-summary artifacts in `AUDIT/slither-graph/`.
- Add a "Manual Threat Model & Review" section to `README.md`.
- `CLAUDE.md` / `AGENTS.md`: correct the version string to `0.4.0`, document the two integration topologies and the CMTAT v3.3+ mint `spender` convention, and add the missing `RuleMintAllowance`, `RuleConditionalTransferLightMultiToken`, `RuleNFTAdapter` and restriction code `70` entries.

## v0.4.0

### Added

- `RuleConditionalTransferLightMultiToken` and `RuleConditionalTransferLightMultiTokenOwnable2Step` — multi-token conditional transfer rules with token-scoped approvals keyed by `(token, from, to, value)`.
- `RuleMintAllowance` and `RuleMintAllowanceOwnable2Step` — operation rule enforcing a per-minter mint quota managed by an operator. Each mint reduces the minter's allowance; the operator can set an absolute quota or increment/decrement it. Regular transfers and burns are not restricted. Restriction code 70 (`CODE_MINTER_ALLOWANCE_EXCEEDED`).

### Changed

- Update contract version in `VersionModule` to `0.4.0`.
- Ownable2Step rule deployments now explicitly advertise ERC-165 `IERC165` (`0x01ffc9a7`), ERC-173 (`0x7f5828d0`), and Ownable2Step (`0x9ab669ef`) interface IDs.
- `RuleMintAllowance` now enforces single-target binding like `RuleConditionalTransferLight`: a second `bindToken` call reverts with `RuleMintAllowance_TokenAlreadyBound` until the current RuleEngine/token is unbound.
- `RuleMintAllowance` no longer advertises the full ERC-3643 `ICompliance` interface through ERC-165 because its mint quota requires spender-aware callbacks.

### Dependencies

- Update RuleEngine to `v3.0.0-rc4`. Role constants were isolated into dedicated storage contracts (`RulesManagementModuleRolesStorage`, `ERC3643ComplianceRolesStorage`); concrete rules that reference `RULES_MANAGEMENT_ROLE` / `COMPLIANCE_MANAGER_ROLE` now inherit the corresponding storage contract.

### Documentation

- Added technical documentation: `doc/technical/RuleConditionalTransferLightMultiToken.md`.
- Updated README operation-rule sections and tables to include `RuleConditionalTransferLightMultiToken`.
- Added technical documentation: `doc/technical/RuleMintAllowance.md`.
- Updated restriction code table, rule index, role summary, and Ownable2Step list in README.
- Documented that `RuleMintAllowance` does not work with pure ERC-3643 3-arg mint callbacks; it requires the spender-aware CMTAT/RuleEngine path.

### Testing

- Added `RuleConditionalTransferLightMultiToken` tests proving approvals are token-scoped and cannot be consumed cross-token.
- Added explicit RuleEngine integration tests for `RuleConditionalTransferLightMultiToken` documenting caller-context behavior in shared RuleEngine topology.
- Added `Ownable2StepERC165Support` test covering all Ownable2Step rule deployments.
- Extended `Ownable2StepERC165Support` with negative assertions to ensure Ownable2Step rule deployments do not advertise unrelated interfaces (`IAccessControl`, `0xdeadbeef`).
- Added unit tests (`test/RuleMintAllowance/RuleMintAllowance.t.sol`, `test/RuleMintAllowance/RuleMintAllowanceOwnable2Step.t.sol`) and CMTAT integration test (`test/RuleMintAllowance/CMTATIntegration.t.sol`) — 54 tests, including batch mint rollback and ERC-165 advertised-interface coverage, >98% line coverage on `RuleMintAllowanceBase`.

## v0.3.0 - 2026-04-16

Commit: `91c21c1191e84ff938892267ec443b0d1bb9efb0`

### Security

- **H1 fix** — `RuleConditionalTransferLight`: enforced single-token binding by overriding `bindToken` to revert with `RuleConditionalTransferLight_TokenAlreadyBound` if a token is already bound. Eliminates cross-token approval replay and approval-draining attacks. Use `unbindToken` first to migrate to a new token.
- **M1 fix** — Added `IERC7551Compliance` (`0x7157797f`), `IERC3643IComplianceContract` (validation rules), and the full ERC-3643 `ICompliance` ID via flat mock `IERC3643ComplianceFull` (`0x3144991c`) to all `supportsInterface` implementations. Silent `false` on ERC-165 introspection no longer occurs for compliant callers.

### Added

- `RuleConditionalTransferLightApprovalBase` — new abstract contract holding the pure approval state machine (approval counts, `approveTransfer`, `cancelTransferApproval`, `approvedCount`, and the `transferred` callback). No ERC-3643 / IRule knowledge.
- `IERC3643ComplianceFull` (`src/mocks/IERC3643ComplianceFull.sol`) — flat mock interface redeclaring all eight ERC-3643 `ICompliance` functions; used to compute the correct ERC-165 ID (`0x3144991c`) since `type(IERC3643Compliance).interfaceId` only XORs directly-defined selectors.

### Changed

- `RuleConditionalTransferLightBase` refactored into two layers: `RuleConditionalTransferLightApprovalBase` (state machine) + `RuleConditionalTransferLightBase` (ERC-3643 / IRule compliance integration). Eliminates code duplication between the AccessControl and Ownable2Step variants.
- `RuleConditionalTransferLightOwnable2Step` now inherits `ERC3643ComplianceModule` via the base (consistent with the AccessControl variant); `_authorizeTransferExecution` consolidated into the base and checks `isTokenBound(_msgSender())`.
- `approveAndTransferIfAllowed` no longer takes a `token` parameter — bound token is retrieved directly via `getTokenBound()`.
- `RuleConditionalTransferLightBase.approveAndTransferIfAllowed` now uses OpenZeppelin `SafeERC20.safeTransferFrom` to handle non-standard ERC-20 return behavior safely.
- Removed unused custom error `RuleConditionalTransferLight_TransferFailed` from `RuleConditionalTransferLightInvariantStorage`.
- Custom error `RuleConditionalTransferLight_TokenAddressZeroNotAllowed` renamed to `RuleConditionalTransferLight_TokenNotBound` for clarity.
- `RuleERC2980` and `RuleERC2980Ownable2Step` constructors now include `allowBurn` and whitelist `address(0)` at deployment when enabled.
- `RuleWhitelist` and `RuleWhitelistOwnable2Step` constructors now include `allowMintBurn`; when enabled, `address(0)` is pre-listed at deployment.
- Solidity style guide ordering (type declarations → state variables → events → errors → modifiers → functions; constructor → external → public → internal → private) enforced across all `src/` contracts.
- `supportsInterface` in `RuleConditionalTransferLight` and `RuleConditionalTransferLightOwnable2Step` now advertises `IERC7551Compliance` and the full ERC-3643 `ICompliance` interface ID instead of the narrow `IERC3643IComplianceContract`.
- `supportsInterface` in `RuleTransferValidation` (cascades to all validation rules) now also advertises `IERC7551Compliance` and `IERC3643IComplianceContract`.
- Update contract version to `0.3.0`

### Dependencies

- Update RuleEngine to `v3.0.0-rc2`.
- Update OpenZeppelin Contracts to `v5.6.1`.
- Update OpenZeppelin Contracts Upgradeable to `v5.6.1`.

### Documentation

- Wake Arena (Ackee Blockchain Security) AI-assisted static analysis report and project feedback added to `doc/security/audits/tools/v0.2.0/`.
- README Security section updated with Wake Arena findings summary table.
- README Access Control section updated to document intentional `DEFAULT_ADMIN_ROLE` implicit-role behaviour, `grantRole` no-op semantics, and off-chain monitoring guidance (I2).
- `RuleERC2980` documentation updated to clarify that a frozen address acting as `transferFrom` spender is also blocked (code 62) (I1).
- `RuleERC2980` documentation and README updated to document burn/redemption behavior and the new constructor `allowBurn` option.
- `RuleWhitelist` documentation and README updated to document constructor `allowMintBurn` and zero-address mint/burn handling.
- README updated to document Hardhat support for optional compilation and smoke testing alongside Foundry-first workflows.
- `CLAUDE.md` / `AGENTS.md` convention added: always use pre-computed library constants for ERC-165 IDs; use a flat mock interface when no constant exists.

### Testing

- Added `RuleERC2980` constructor tests covering default burn-blocked behavior and `allowBurn=true` zero-address whitelisting.
- Added `RuleWhitelist` constructor tests covering `allowMintBurn=true` zero-address pre-listing.
- Added a Hardhat smoke test (`test/hardhat/smoke.test.js`) and npm scripts for Hardhat compile/smoke execution.
- Updated `RuleConditionalTransferLightApproveAndTransfer` transfer-failure test to assert OpenZeppelin `SafeERC20` revert semantics.
- Removed now-unused `RuleConditionalTransferLight_TransferFailed` declaration; no behavior change.

## v0.2.0 - 2026-03-10

Commit: [`d72a98a`](https://github.com/CMTA/Rules/commit/d72a98abbba29cd82a7056b59104e82ac65389e7) 

### Added

- `RuleSpenderWhitelist` — validation rule that blocks `transferFrom` when spender is not listed; direct transfers are always allowed. Restriction code 66.
- `RuleSpenderWhitelistOwnable2Step` — Ownable2Step variant of `RuleSpenderWhitelist`.
- Technical documentation file `doc/technical/RuleSpenderWhitelist.md`.
- Transfer-context mocks in `src/mocks`: `MockERC20WithTransferContext` and `MockERC721WithTransferContext`.
- Transfer-context mocks in `src/mocks` now inherit OpenZeppelin `ERC20` / `ERC721` and emit rule callbacks through `ITransferContext`.
- Transfer-context tests for ERC-20/ERC-721 mock integration in `test/TransferContext/TransferContextMocks.t.sol`.
- `RuleERC2980` — ERC-2980 Swiss Compliant rule combining a whitelist (recipient-only) and a frozenlist (blocks sender, recipient, and spender); frozenlist takes priority. Restriction codes 60–63.
- `RuleERC2980Ownable2Step` — Ownable2Step variant of `RuleERC2980`.
- `IERC2980` interface with NatSpec documenting the deviation from the ERC example interfaces (single-item functions revert on invalid input rather than returning `bool`).
- `isVerified(address)` to `RuleERC2980Base` and `RuleWhitelistWrapperBase`, implementing `IIdentityRegistryVerified`; for ERC-2980 it reflects whitelist membership only (frozen status is excluded).
- `VersionModule` — abstract module implementing `IERC3643Version`; all rules now expose `version()` returning `"0.2.0"`.
- New deployable rules: `RuleIdentityRegistry`, `RuleMaxTotalSupply`, `RuleConditionalTransferLight`.
- Ownable2Step variants for all rules: `RuleWhitelistOwnable2Step`, `RuleBlacklistOwnable2Step`, `RuleSanctionsListOwnable2Step`, `RuleMaxTotalSupplyOwnable2Step`, `RuleIdentityRegistryOwnable2Step`, `RuleWhitelistWrapperOwnable2Step`, `RuleConditionalTransferLightOwnable2Step`.
- Transfer-context struct API: `MultiTokenTransferContext` / `FungibleTransferContext` with an extra `data` field.
- Explicit sanctions oracle clearing via `clearSanctionListOracle()`.
- CMTAT deployment scripts for whitelist and blacklist configurations.
- `DeployCMTATWithBlacklistAndSanctionsList` deployment script — deploys a CMTAT token wired to a `RuleEngine` configured with both `RuleBlacklist` and `RuleSanctionsList`.
- Technical documentation for all rules in `doc/technical/`: added `RuleMaxTotalSupply.md`, `RuleIdentityRegistry.md`, `RuleERC2980.md`, `RuleConditionalTransferLight.md`; updated `RuleWhitelist.md`, `RuleBlacklist.md`, `RuleSanctionList.md`, `RuleWhitelistWrapper.md`.

### Changed

- RBAC variants now use `AccessControlEnumerable` (replacing plain `AccessControl`); role members can be enumerated with `getRoleMember` / `getRoleMemberCount`.
- Default admin implicitly holds all roles via a `hasRole` override; may not appear in role member enumerations unless explicitly granted.
- Authorization hooks (`_authorize*()`) now use `onlyRole(ROLE)` modifier instead of direct `_checkRole` calls.
- All `internal` functions marked `virtual` to allow downstream overriding.
- Validation flow refactored to internal hooks (no `this.` calls) via `RuleTransferValidation` and `RuleNFTAdapter`.
- `RuleConditionalTransferLight` and `RuleMaxTotalSupply` are ERC-20 only; ERC-721/1155 compliance interfaces are limited to validation rules.
- Address list batch updates emit only add/remove events (no summary events).
- Reorganized validation contracts into `abstract/base`, `abstract/core`, `abstract/invariant`, and `deployment` folders.
- Rule transfer-context dispatch now treats `sender == from` as direct transfer (non-spender path) in `RuleNFTAdapter`.
- Concrete utilities and harness contracts used by tests were moved from `test/` into `src/mocks` and `src/mocks/harness`.

### Dependencies

- Updated Solidity toolchain to 0.8.34.
- Update OpenZeppelin to 5.6.0
- Update CMTAT to v3.2.0
- Update RuleEngine to v3.0.0-rc1

### Documentation

- Access-control role table with keccak256 hashes.
- Rule-engine flow diagrams, API accuracy, directory layout notes.
- Static analysis reports (Aderyn, Slither) with project feedback in `doc/security/audits/tools/v0.2.0/`.
- Gas benchmarks in `doc/GAS.md` and `.gas-snapshot`.

## v0.1.0 - 2025-12-03

Commit: `09376412269d2397fa7db6562e63bc65376d12b9`

First release !

- Update Rules to CMTAT v3.0.0 and latest RuleEngine version

- Use [EnumerableSet](https://docs.openzeppelin.com/contracts/5.x/api/utils#EnumerableSet) from OpenZeppelin to store address status for blacklist and whitelist rules.
- Add function `canTransferFrom`, `detectTransferRestrictionFrom` which takes the spender argument
- Add functions `canTransfer`, `canTransferFrom`, `detectTransferRestriction`,`detectTransferRestrictionFrom` which takes the `tokenId` argument.
- Add support of [ERC-165](https://eips.ethereum.org/EIPS/eip-165) in each rule.
