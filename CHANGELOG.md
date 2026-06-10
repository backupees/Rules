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

- `RuleMintAllowance` and `RuleMintAllowanceOwnable2Step` — operation rule enforcing a per-minter mint quota managed by an operator. Each mint reduces the minter's allowance; the operator can set an absolute quota or increment/decrement it. Regular transfers and burns are not restricted. Restriction code 70 (`CODE_MINTER_ALLOWANCE_EXCEEDED`).

### Changed

- `RuleMintAllowance` now enforces single-target binding like `RuleConditionalTransferLight`: a second `bindToken` call reverts with `RuleMintAllowance_TokenAlreadyBound` until the current RuleEngine/token is unbound.

### Documentation

- Added technical documentation: `doc/technical/RuleMintAllowance.md`.
- Updated restriction code table, rule index, role summary, and Ownable2Step list in README.
- Documented that `RuleMintAllowance` does not work with pure ERC-3643 3-arg mint callbacks; it requires the spender-aware CMTAT/RuleEngine path.

### Testing

- Added unit tests (`test/RuleMintAllowance/RuleMintAllowance.t.sol`, `test/RuleMintAllowance/RuleMintAllowanceOwnable2Step.t.sol`) and CMTAT integration test (`test/RuleMintAllowance/CMTATIntegration.t.sol`) — 51 tests, >98% line coverage on `RuleMintAllowanceBase`.

## v0.4.0

### Added

- `RuleConditionalTransferLightMultiToken` and `RuleConditionalTransferLightMultiTokenOwnable2Step` — multi-token conditional transfer rules with token-scoped approvals keyed by `(token, from, to, value)`.

### Changed

- Update contract version in `VersionModule` to `0.4.0`.
- Ownable2Step rule deployments now explicitly advertise ERC-165 `IERC165` (`0x01ffc9a7`), ERC-173 (`0x7f5828d0`), and Ownable2Step (`0x9ab669ef`) interface IDs.

### Dependencies

- Update RuleEngine to `v3.0.0-rc3`.

### Documentation

- Added technical documentation: `doc/technical/RuleConditionalTransferLightMultiToken.md`.
- Updated README operation-rule sections and tables to include `RuleConditionalTransferLightMultiToken`.

### Testing

- Added `RuleConditionalTransferLightMultiToken` tests proving approvals are token-scoped and cannot be consumed cross-token.
- Added explicit RuleEngine integration tests for `RuleConditionalTransferLightMultiToken` documenting caller-context behavior in shared RuleEngine topology.
- Added `Ownable2StepERC165Support` test covering all Ownable2Step rule deployments.
- Extended `Ownable2StepERC165Support` with negative assertions to ensure Ownable2Step rule deployments do not advertise unrelated interfaces (`IAccessControl`, `0xdeadbeef`).

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
