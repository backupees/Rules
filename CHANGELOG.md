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

_Nothing yet._

## v0.5.0 - 2026-08-11

Commit: _pending — not yet committed at the time of writing._

### Summary

Two new contracts, one behavioural hardening with a migration note, and the first tests that run
against a real ERC-3643 token.

**New**
- **`RuleChainlinkPoR`** — caps total supply at the reserves reported by a Chainlink Proof of Reserve feed. Restriction codes `75`–`78`.
- **`IdentityRegistryWhitelist`** — a whitelist that fills an ERC-3643 token's *identity registry* slot, so a token can enforce investor eligibility with no ONCHAINID deployment. Not a rule: it implements no `IRule` and must never be added to a `RuleEngine`.

**Breaking behaviour: `RuleMaxTotalSupply`.** The constructor and `setTokenContract` now reject a
non-contract token and probe that `totalSupply()` is callable, and a token that later reverts yields
the new restriction code `51` instead of breaking the MUST-NOT-revert views. Deployments that passed
a placeholder address now fail at construction — see *Changed* for the migration note. This only
rejects configurations that could never have worked, which is why it is a MINOR rather than MAJOR
bump pre-1.0.

**ERC-3643 interoperability.** Both integration directions are now covered end to end: a `RuleEngine`
in the token's *compliance* slot enforcing `RuleWhitelist`, and `IdentityRegistryWhitelist` in the
*identity* slot. One suite runs against the genuine vendored `Token.sol` rather than a mock, which
requires a second Foundry profile — **`forge test` alone no longer runs everything**, see *Testing*.

### Added

- **`RuleChainlinkPoR`** — a validation rule that caps total supply at the reserves reported by a [Chainlink Proof of Reserve](https://docs.chain.link/data-feeds/proof-of-reserve) data feed. Before every mint it reads `latestRoundData()` from the configured `AggregatorV3Interface`, scales the answer from the feed's decimals to the token's, and rejects the mint when `totalSupply + value` would exceed it. Modelled on Chainlink's `SecureMintPolicy` from the ACE policy library, minus its configurable reserve margin. Restriction codes `75` (reserves exceeded), `76` (feed stale), `77` (feed answer invalid), `78` (total supply unavailable). Available as `RuleChainlinkPoR` (AccessControl) and `RuleChainlinkPoROwnable2Step`.
  - **Limit = reserves, exactly** — no margin, buffer or headroom parameter. Compose with `RuleMaxTotalSupply` for a static cap, or report conservative reserves upstream for a cushion.
  - **Staleness threshold** — `maxStalenessSeconds` rejects mints when the feed has not been updated recently; `0` disables the check.
  - **Mints only** — transfers and burns always pass, including while the feed is stale or unavailable, so a lapsed feed never traps holders.
  - **Feed decimals read live, never cached** — the extra `STATICCALL` costs ~2,900 gas per mint (+2.6%), which buys immunity to an aggregator migration silently mis-scaling the reserves by `10 ** delta`. In the overstating direction a cached value would authorise unbacked minting with no on-chain signal. Rationale, measurements and residual risk are in the [rule doc](./doc/technical/RuleChainlinkPoR.md#why-the-decimals-are-read-live-and-what-it-costs).
  - **Revert-free read path** — one `code.length` check covers both feed calls (Solidity's extcodesize revert on a `try` to a codeless address is uncatchable), `decimals()` and `latestRoundData()` are both wrapped in `try/catch`, `MAX_FEED_DECIMALS` is re-checked at read time so the scaling exponent cannot overflow, decimal scaling saturates rather than overflows, and the supply comparison uses remaining headroom. The ERC-1404 / ERC-3643 views therefore return a code instead of reverting under every feed failure mode.
  - **Token validated at configuration** — a non-contract address is rejected explicitly (`RuleChainlinkPoR_TokenIsNotAContract`) and `totalSupply()` is probed (`RuleChainlinkPoR_TokenTotalSupplyUnavailable`), so a token that cannot serve the restriction check fails loudly at setup instead of silently bricking the read path. At run time a reverting or codeless token yields code `78` rather than a revert.
  - `maxBackedSupply()` previews the current limit without simulating a mint.
  - **Documented:** one instance protects one token. The rule reads `totalSupply()` from its configured `tokenContract` rather than from the token that triggered the check, and has no binding to enforce the pairing — sharing an instance across RuleEngines silently evaluates both tokens against the first one's supply and feed. Same exposure as `RuleMaxTotalSupply`; see [One instance per protected token](./doc/technical/RuleChainlinkPoR.md#one-instance-per-protected-token).
- **`RuleReceiverWhitelist`** — a whitelist that screens **only the receiver**, reproducing ERC-3643's eligibility rule as a CMTAT compliance rule. It fills the gap between `RuleWhitelist` (both parties) and `RuleSpenderWhitelist` (spender only). Restriction code `81`. Available as `RuleReceiverWhitelist` (AccessControl) and `RuleReceiverWhitelistOwnable2Step`.
  - The sender and the spender are **never** screened. That is the point, not an omission: screening the sender traps de-listed holders, and ERC-3643 checks only the receiver precisely so a lapsed investor can still exit their position.
  - Mint is screened on the receiver like any other transfer — no `allowMint`/`allowBurn` flags, since ERC-3643 gates minting on receiver eligibility alone. Compose with `RuleMaxTotalSupply` or `RuleChainlinkPoR` to cap issuance.
  - Burn (`to == address(0)`) is exempt explicitly, because the zero address can never be listed and every burn would otherwise be rejected.
  - Equivalence with the standard is pinned against the **real vendored ERC-3643 token** in `test/ERC3643Real/ERC3643ReceiverWhitelistParity.t.sol`: the rule runs in the token's compliance slot over the same address set the identity registry holds, and must never change the outcome.
- `AggregatorV3Interface` and `IDecimals` in `src/rules/interfaces/`, so the library reads Chainlink feeds without taking a dependency on the Chainlink contracts package.
- **`IdentityRegistryWhitelist`** — a whitelist that plugs into an **ERC-3643 token's identity registry slot** (`token.setIdentityRegistry(...)`), so a token can enforce investor eligibility without deploying ONCHAINID contracts. `registerIdentity` whitelists, `deleteIdentity` removes, `isVerified` answers the token's per-transfer check. Only the subset of `IIdentityRegistry` that `Token.sol` actually calls is implemented. This is **not** a compliance rule: no `IRule` surface, and it must not be added to a `RuleEngine`.
  - Implements **no** ERC-734 surface. `recoveryAddress` must be given a real ONCHAINID as `_investorOnchainID`; the registry only supplies `isVerified`, `registerIdentity`, `deleteIdentity` and `investorCountry`. Consequently `registerIdentity` rejects duplicates exactly like the reference registry, and the replacement wallet is registered by the token during recovery rather than beforehand — no behavioural divergence from stock ERC-3643 remains.
  - The ERC-3643 token must hold `IDENTITY_REGISTRAR_ROLE`, because `recoveryAddress` makes the token call `registerIdentity` and `deleteIdentity`.
  - Reuses `RuleAddressSetInternal` — the same `EnumerableSet` machinery as `RuleWhitelist` / `RuleBlacklist` — for storage, the zero-address guard and the revert errors, so no whitelist contract is deployed and none is re-implemented. Only the internal layer is inherited: `RuleAddressSet`'s public mutators are not `virtual` and could not keep the `keyHasPurpose` reverse index in step.
  - **No identity data is kept.** The `_identity` and `_country` arguments exist so the ERC-3643 signature matches, then are discarded; `investorCountry` is a constant `0`. The contract is a wrapper that adapts the token's registry calls onto a plain whitelist. `Token.sol` reads the country in exactly one place (`recoveryAddress`, a pass-through it hands straight back), so the token is unaffected; the exposure is a *custom* compliance module reading `investorCountry`, which would see every investor as country 0.
  - `isVerified(address(0))` is always `false`; the zero address can never be registered.

### Changed

- **`RuleMaxTotalSupply` now validates its token contract and guards the supply read** (same hardening as `RuleChainlinkPoR`, threat `EXT-4`). The constructor and `setTokenContract` reject a non-contract address (`RuleMaxTotalSupply_TokenIsNotAContract`) and probe that `totalSupply()` is callable (`RuleMaxTotalSupply_TokenTotalSupplyUnavailable`). At run time a token whose `totalSupply()` reverts yields the new restriction code `51` (`CODE_SUPPLY_ORACLE_UNAVAILABLE`) instead of reverting the ERC-1404 / ERC-3643 views, which MUST NOT revert. Codeless targets are excluded by construction rather than by a runtime check: the setters require code and EIP-6780 (Cancun) makes that permanent, recorded as a deployment precondition in each rule doc.
  - **Migration:** deployments that passed a placeholder or non-contract address as `tokenContract` now revert at construction. This only rejects configurations that could never have worked — the previous behaviour was to accept them and then revert on every restriction check. Integrators switching on restriction codes should handle `51`, which can only appear where the view previously threw.

### Documentation

- New [`doc/technical/RuleReceiverWhitelist.md`](./doc/technical/RuleReceiverWhitelist.md), including why receiver-only screening is the conformant choice and how the parity suite tests it.
- New [`doc/technical/IdentityRegistryWhitelist.md`](./doc/technical/IdentityRegistryWhitelist.md), including a table of which ERC-3643 token functions call the registry and how, the `recoveryAddress` call sequence, and five documented limitations.
- New [`doc/technical/RuleChainlinkPoR.md`](./doc/technical/RuleChainlinkPoR.md), including a point-by-point comparison against Chainlink's `SecureMintPolicy 1.2.0` (vendored at `lib/chainlink-ace/`); `RULE_SEMANTICS.md` and `README.md` updated with the new rule.

### Testing

- New `test/ERC3643Real/ERC3643RealTokenRuleEngine.t.sol` — the same **ERC-3643 token → RuleEngine → RuleWhitelist** wiring, but against the **real vendored `Token.sol`** rather than a mock, so nothing in it is transcribed. 12 tests covering mint, transfer, transferFrom, forcedTransfer and burn, asserting the token's own `ComplianceNotFollowed` / `TransferNotPossible` errors and the rule's `RuleWhitelist_InvalidTransfer` codes.
  - Requires its own Foundry profile: `Token.sol` pins `pragma solidity 0.8.30` exactly, which cannot share a compilation unit with the project's 0.8.34. `test/ERC3643Real/**` is skipped by the default profile and built by `[profile.erc3643]`. **CI must run both `forge test` and `FOUNDRY_PROFILE=erc3643 forge test`.**
  - The `lib/ERC-3643` submodule moves from 4.1.3 to **4.2.0-beta1**; 4.1.3 pins `0.8.17`, which cannot compile alongside our `^0.8.20` contracts at all. Nothing in `src/` imports ERC-3643, so the bump affects tests only.
  - Adds minimal `IIdentity` / `IClaimIssuer` stubs under `test/utils/onchainid/`, wired by a context-scoped remapping, because ONCHAINID is an npm dependency rather than a submodule.
- New `test/ERC3643Compliance/ERC3643RuleEngineWhitelist.t.sol` — an ERC-3643 token wired to a `RuleEngine` as its **compliance** contract (`setCompliance`), enforcing `RuleWhitelist`: **ERC-3643 token → RuleEngine → RuleWhitelist**. Covers `mint`, `transfer`, `transferFrom`, `forcedTransfer` and `burn`, and pins that the compliance slot and the identity-registry slot block independently — an address verified by the registry but absent from the rule is rejected, and vice versa. Exercises the `setTokenSelfBindingApproval` path that exists in `ERC3643ComplianceExtendedModule` for ERC-3643 self-binding.
- `ERC3643TokenMock` gained an optional compliance slot, with `canTransfer` / `transferred` / `created` / `destroyed` / `bindToken` call sites transcribed from `Token.sol`. Optional so the identity-registry suites keep running without an engine.

- 79 new tests across unit, decimal-scaling, Ownable2Step access-control, and CMTAT + RuleEngine end-to-end suites, including a full-domain fuzz asserting the read path never reverts. 100% line coverage on both deployment variants.
- Decimal-scaling suite covering token decimals 0 / 6 / 18 against feed decimals 0 / 8 / 18 / 36, the truncation behaviour at `tokenDecimals == 0`, and a fuzz cross-checking `_scaleReserve` against `answer * 10**tokenDecimals / 10**feedDecimals` computed with full-precision `mulDiv`.

## v0.4.0 - 2026-07-14

Commit: `44cec0ebc7d9eba7644f9f4d1c52e832e2791369`

### Summary

Two new rule families, two standards-conformance fixes, and hardening from an internal review.

**New rules**
- **`RuleMintAllowance`** — a per-minter mint quota. The operator sets an absolute quota (or increments/decrements it) and each mint debits the minter's allowance. It is the only rule keyed on the mint `spender`, so it requires the spender-aware CMTAT/RuleEngine callback path. Restriction code `70`.
- **`RuleConditionalTransferLightMultiToken`** — conditional transfers with approvals keyed by `(token, from, to, value)`. **Direct-binding only:** it must not be added to a `RuleEngine`.

**Breaking: two standards-conformance fixes.** Both change default behaviour and require deployer action — see *Changed* for the migration steps.
- **`RuleIdentityRegistry` now follows ERC-3643 and verifies only the RECEIVER.** It previously screened the sender, the spender and the minter. The sender check was the damaging one: it *trapped de-listed holders*, who could neither receive nor send, when the spec checks only the receiver precisely so a lapsed investor can still exit their position. Stricter screening survives as opt-in `checkSender` / `checkSpender` flags, both defaulting to `false`.
- **Mint/burn permission is now an explicit `allowMint` / `allowBurn` flag**, not membership of `address(0)`. Enabling mint/burn by whitelisting the zero address made mandatory getters lie — `isVerified(address(0))` and `RuleERC2980.whitelist(address(0))` both returned `true` — and made `removeAddress(address(0))` silently halt all issuance. The zero address can no longer enter any list. New codes `24`/`25` and `64`/`65` say "minting is not allowed" instead of the misleading "sender is not whitelisted".

**Usability and operations**
- `RuleConditionalTransferLight` **works behind a `RuleEngine`**: `bindToken` (the ERC-20 target) and the new `bindRuleEngine` (the authorized caller) are now separate roles, which fixes `approveAndTransferIfAllowed`.
- Caller-explicit pre-flight views (`detectTransferRestrictionForToken` / `canTransferForToken`) so a wallet or explorer gets a truthful answer from the multi-token rule.
- Stale-state cleanup after rebinding: `resetApproval(...)` and `clearMintAllowances(...)`.
- Overflow-safe supply-cap views — they return code `50` instead of reverting with an arithmetic panic.

**Internal review.** An AI-assisted, test-backed review of `src/` reported 0 Critical/High/Medium, 2 Low and 8 Informational findings; see [`CLAUDE_AUDIT.md`](./doc/security/audits/tools/v0.4.0/claude-audit/CLAUDE_AUDIT.md). This is **not** a formal third-party audit, and the project has not had one. Test suite grew 425 → **511 tests** (97.8% line, 97.3% branch coverage) and now includes a stateful, mutation-verified invariant suite.

### Added

- `RuleConditionalTransferLight`: **split the binding into two independent roles**, so the rule works fully behind a `RuleEngine`. New `bindRuleEngine(address)` / `unbindRuleEngine()` (compliance-manager gated, emitting `RuleEngineBound` / `RuleEngineUnbound`) authorise a RuleEngine to call the transfer execution hooks, while `bindToken` continues to designate the **ERC-20 token** the rule acts on. `transferred` now accepts a call from either the bound token or the bound RuleEngine (new `isTransferExecutor(address)` view). This fixes `approveAndTransferIfAllowed`, which was previously unusable behind a RuleEngine: the single binding slot had to be *both* the ERC-20 target and the authorised caller, and behind an engine those are different addresses — binding the engine broke the helper (an engine is not an ERC-20) while binding the token left the engine unauthorised and reverted every transfer and mint. Backward compatible: existing direct-binding deployments are unaffected, and a deployment that binds the engine via `bindToken` keeps working as before (though it should migrate to use both bindings). See finding F-3.
- `RuleConditionalTransferLightMultiToken`: new caller-explicit pre-flight views `detectTransferRestrictionForToken(token, from, to, value)` and `canTransferForToken(token, from, to, value)`. The standardized ERC-1404 / ERC-3643 views (`detectTransferRestriction`, `canTransfer`) derive the token key from `msg.sender`, so an off-chain `eth_call` from a wallet or explorer always read "not approved" even for an approved transfer; the new views take the token explicitly and give every caller the real answer. Additive — the standardized signatures are unchanged, and both paths are backed by the same internal helper so they can never disagree for the bound token.
- ERC-165: `RuleWhitelist`, `RuleBlacklist`, `RuleSpenderWhitelist` (and their `Ownable2Step` variants) now advertise the `IAddressList` interface (`0x5d10e182`). Purely additive — no call is rejected. This is the prerequisite for `RuleWhitelistWrapper` to interface-check its child rules (improvement I-4, finding F-5). Adds `AddressListInterfaceId` (pre-computed constant) and `IAddressListInterfaceIdHelper` (flattened interface used to derive it): `type(IAddressList).interfaceId` cannot be used, because it omits `contains(address)` inherited from `IIdentityRegistryContains`. `RuleWhitelistWrapper` deliberately does **not** advertise it — it exposes no address set of its own, so a wrapper cannot be nested inside another wrapper.
- `RuleConditionalTransferLight` / `RuleConditionalTransferLightMultiToken`: new `resetApproval(...)` operator function that discards **every** outstanding approval for a transfer key in one call (returns the cleared count, emits `TransferApprovalReset`). It deliberately does **not** require a bound token, so it can clean up approvals that survived an `unbindToken` — and, for the multi-token rule, approvals stranded under a key that can never be consumed.
- `RuleMintAllowance`: new `clearMintAllowances(address[] calldata minters)` operator function that zeroes the listed minters' quotas (non-reverting batch), for discarding stale quotas before rebinding.
- `RuleConditionalTransferLightMultiToken` and `RuleConditionalTransferLightMultiTokenOwnable2Step` — multi-token conditional transfer rules with token-scoped approvals keyed by `(token, from, to, value)`.
- `RuleMintAllowance` and `RuleMintAllowanceOwnable2Step` — operation rule enforcing a per-minter mint quota managed by an operator. Each mint reduces the minter's allowance; the operator can set an absolute quota or increment/decrement it. Regular transfers and burns are not restricted. Restriction code 70 (`CODE_MINTER_ALLOWANCE_EXCEEDED`).

### Fixed

- `RuleMaxTotalSupply`: `detectTransferRestriction` / `canTransfer` / `detectTransferRestrictionFrom` no longer revert with an arithmetic panic when `currentSupply + value` would overflow `uint256`. The mint check now compares against the remaining headroom (`value > maxTotalSupply - currentSupply`), so these ERC-1404 / ERC-3643 views always return a restriction code as required. Enforcement (`transferred`) is unchanged.

### Changed

- **BREAKING — `RuleIdentityRegistry` is now ERC-3643 conformant: only the RECEIVER is verified.** The rule previously screened the sender, the spender **and** the minter. The specification mandates none of those — *"The receiver MUST be whitelisted on the Identity Registry and verified"*; *"`transferFrom` works the same way"*; *"`mint` and `forcedTransfer` only require the receiver"*; *"The `burn` function bypasses all checks on eligibility"*.
  - **The sender check was the most damaging.** ERC-3643 screens only the receiver precisely so that an investor whose identity lapses (expired claim, revoked identity) can still **exit their position** by sending to a verified counterparty. Screening the sender trapped de-listed holders: they could neither receive nor send.
  - It also fixes finding **F-1**: an unverified minter can now mint to a verified recipient, as the spec requires (previously reverted with `CODE_ADDRESS_SPENDER_NOT_VERIFIED`).
  - Stricter screening remains available as an **explicit opt-in**: new `checkSender` / `checkSpender` flags (constructor parameters, plus `setCheckSender(bool)` / `setCheckSpender(bool)`, emitting `IdentityCheckSenderUpdated` / `IdentityCheckSpenderUpdated`). Both default to `false` — the conformant behaviour. Mint and burn stay exempt from the spender check even when `checkSpender` is on.
  - **Constructor:** `RuleIdentityRegistry(admin, identityRegistry, checkSender, checkSpender)` — pass `false, false` for the ERC-3643 default.
  - **Deployer migration:** a deployment relying on the old (stricter) behaviour must pass `true, true` to preserve it. No restriction codes changed.
- **BREAKING — `RuleWhitelist`, `RuleWhitelistWrapper`, `RuleERC2980`: mint/burn permission is now an explicit flag, not membership of `address(0)`.** Previously these rules enabled mint/burn by *whitelisting the zero address*, which made the standardized identity getters assert falsehoods: `isVerified(address(0))` returned `true` (ERC-3643 defines `isVerified` as "is this wallet a valid investor holding the required claims" — the zero address is not a wallet), and `RuleERC2980.whitelist(address(0))` returned `true` (a **mandatory** ERC-2980 getter). It also meant `removeAddress(address(0))` silently disabled all minting and burning.
  - New state: `allowMint` / `allowBurn`, with `setAllowMint(bool)` / `setAllowBurn(bool)` (admin/owner gated, emitting `AllowMintUpdated` / `AllowBurnUpdated`), so issuance can still be permanently closed at runtime while redemptions stay open.
  - New restriction codes: `RuleWhitelist` / `RuleWhitelistWrapper` → `24` (`CODE_MINT_NOT_ALLOWED`) and `25` (`CODE_BURN_NOT_ALLOWED`); `RuleERC2980` → `64` / `65`. A blocked mint now reports "minting is not allowed" instead of the misleading "sender is not whitelisted".
  - The zero address can no longer enter any list: both single **and batch** adds revert (`RuleAddressSet_ZeroAddressNotAllowed` / `RuleERC2980_ZeroAddressNotAllowed`). This is the one input a batch does not skip — see the batch note below.
  - **Constructors:** `RuleWhitelist(admin, forwarder, checkSpender, allowMintBurn)` keeps its shape — `allowMintBurn` now sets *both* flags instead of whitelisting `address(0)`. `RuleWhitelistWrapper` gains an `allowMintBurn` parameter (it holds no addresses of its own and must decide mint/burn itself). `RuleERC2980`'s third parameter is renamed `allowBurn` → `allowMintBurn` and now governs both operations.
  - **Deployer migration:** a deployment that enabled mint/burn by whitelisting `address(0)` must instead pass `allowMintBurn = true` (or call the setters). Permission semantics are otherwise unchanged: a permitted mint still requires a whitelisted **recipient**, and a permitted burn still requires a whitelisted **sender**.
  - **Batch adds reject `address(0)` rather than skipping it.** The batch convention still skips *duplicates* (an idempotent no-op the emitted event describes truthfully), but silently dropping the sentinel would make `AddAddresses` / `AddWhitelistAddresses` / `AddFrozenlistAddresses` report a member that is not in the set — re-polluting, off-chain, the very view this change cleans up on-chain.
  - **Removed capability (`RuleBlacklist` / `RuleSpenderWhitelist`):** these rules inherit the same address set, so blacklisting `address(0)` — which previously acted as an undocumented "halt all issuance" kill switch, since a mint has `from == address(0)` — is no longer possible. They did **not** receive `allowMint` / `allowBurn` flags: a deny-list has no legitimate reason to list the sentinel, and issuance is better halted at the token (CMTAT pause/deactivate) or with an allow-list rule. If you relied on that idiom, migrate before upgrading.
- Access-control hooks: **all `_authorize*()` / `_only*()` hooks are now `internal view virtual`**, both the abstract declarations and every override. An authorization hook checks and reverts; `view` makes "authorization never mutates state" a compiler-enforced invariant rather than a convention. Compile-time only — `view` on an `internal` function has no gas or runtime impact. Normalised `RuleWhitelistWrapperBase._authorizeCheckSpenderManager` (declaration), the three `RuleWhitelistWrapper` overrides (which disagreed with their own `Ownable2Step` twin), and the six `_onlyComplianceManager` overrides across the operation rules. The convention is now recorded in `CLAUDE.md`/`AGENTS.md`. One documented exception remains: `RuleConditionalTransferLightMultiTokenBase._authorizeComplianceBindingChange` delegates to `_onlyComplianceManager()`, which `lib/RuleEngine` declares non-`view`, and Solidity checks mutability against a virtual's declared type — it can only become `view` once that is changed upstream.
- `RuleSpenderWhitelist` / `RuleSpenderWhitelistOwnable2Step`: remove a dead `RuleTransferValidation` import. The symbol was referenced nowhere in either file (not in the inheritance list, an `override(...)` specifier, or a body). Cosmetic — no bytecode or behavioural change. Surfaced by Aderyn 0.6.5 (`Unused Import`) in the post-remediation re-run.
- `RuleERC2980`: split the shared list-management errors into per-list errors so a revert identifies which list rejected. `RuleERC2980_AddressAlreadyListed` becomes `RuleERC2980_AddressAlreadyWhitelisted` / `RuleERC2980_AddressAlreadyFrozen`, and `RuleERC2980_AddressNotFound` becomes `RuleERC2980_AddressNotWhitelisted` / `RuleERC2980_AddressNotFrozen`. **Breaking (ABI):** the removed errors' 4-byte selectors no longer exist; off-chain tooling matching on them must update.
- Update contract version in `VersionModule` to `0.4.0`.
- Ownable2Step rule deployments now explicitly advertise ERC-165 `IERC165` (`0x01ffc9a7`), ERC-173 (`0x7f5828d0`), and Ownable2Step (`0x9ab669ef`) interface IDs.
- `RuleMintAllowance` now enforces single-target binding like `RuleConditionalTransferLight`: a second `bindToken` call reverts with `RuleMintAllowance_TokenAlreadyBound` until the current RuleEngine/token is unbound.
- `RuleMintAllowance` no longer advertises the full ERC-3643 `ICompliance` interface through ERC-165 because its mint quota requires spender-aware callbacks.

### Dependencies

- Update RuleEngine to `v3.0.0-rc4`. Role constants were isolated into dedicated storage contracts (`RulesManagementModuleRolesStorage`, `ERC3643ComplianceRolesStorage`); concrete rules that reference `RULES_MANAGEMENT_ROLE` / `COMPLIANCE_MANAGER_ROLE` now inherit the corresponding storage contract.

### Documentation

- `RuleConditionalTransferLightMultiToken`: document that the rule is **direct-binding-only** and **must not be added to a `RuleEngine`**. Approvals are recorded under the `token` argument but consumed under `msg.sender`, so behind an engine every wiring either reverts or silently loses per-token isolation. Added a "Deployment topology" section with the exhaustive case analysis to `doc/technical/RuleConditionalTransferLightMultiToken.md`, documented the caller-dependent `detectTransferRestriction`, and propagated the constraint to the README binding-model table, `RULE_SEMANTICS.md` and the project guide.
- `RuleWhitelistWrapper`: document the child-rule scan cost model and publish operator guidance. The wrapper makes one external `STATICCALL` per child (**~8.8k gas each**) and the scan runs during transfer *execution*, so it is paid by the transferring user on every transfer — not only in views. At the default `maxRules = 10` the worst case is ~90k gas per transfer (~121k with `checkSpender`). Two amplifiers are documented: a transfer that will be *rejected* never early-exits and therefore always scans all children, and `checkSpender = true` adds a third target address that must also be resolved. The scan is linear (marginal cost measured flat at ~8.8k gas/child from 25 to 200 children). Guidance: keep the child list at or below the default cap, order children by expected hit rate, and treat raising `maxRules` as a permanent per-transfer cost on every holder (a cap of 100 ⇒ ~884k gas/transfer, measured). This is a cost problem rather than a liveness one — transfers still fit in a block until roughly 3,400 children. The list size remains the **operator's responsibility**; no lower cap is hard-coded.
- Add `doc/technical/INVARIANT_TESTS.md` — documents the stateful invariant suite: handler architecture and ghost variables, each of the four invariants and what it proves, the mutation-testing negative controls, the coverage map against the threat-model invariants, and how to add a new invariant. Linked from a new "Invariant testing" section in the README.
- Add `doc/technical/RULE_SEMANTICS.md` — a per-rule comparison table (who each rule screens for `from` / `to` / spender on `transferFrom` / mint / burn, behaviour when the oracle/registry is unset, stateful?, and which pre-flight view is authoritative), with a highlights summary and link added to the README.
- `RuleMintAllowance`: document that `canTransfer` / `detectTransferRestriction` are **not authoritative** (hardcoded to "allowed" because the 3-arg path has no minter identity) and that a mint pre-flight must use the spender-aware `canTransferFrom(minter, address(0), to, value)` / `detectTransferRestrictionFrom`. Added a bold callout and an eligibility-views table to `doc/technical/RuleMintAllowance.md` and a warning to the README rule section.
- Add [`CLAUDE_AUDIT.md`](./doc/security/audits/tools/v0.4.0/claude-audit/CLAUDE_AUDIT.md) — the published AI-assisted security audit report for `v0.4.0` (0 Critical/High/Medium, 2 Low, 8 Info), with invariant verification, access-control verification, the remediation record and the open improvement backlog. Backed by the working deliverables `THREAT_MODEL.md`, `RESULT.md` and `TEST_IMPROVEMENT.md`, plus Slither call-graph / inheritance / function-summary comprehension artifacts.
- Add a "Manual Threat Model & Review" section to `README.md`.
- `CLAUDE.md` / `AGENTS.md`: correct the version string to `0.4.0`, document the two integration topologies and the CMTAT v3.3+ mint `spender` convention, and add the missing `RuleMintAllowance`, `RuleConditionalTransferLightMultiToken`, `RuleNFTAdapter` and restriction code `70` entries.
- Added technical documentation: `doc/technical/RuleConditionalTransferLightMultiToken.md`.
- Updated README operation-rule sections and tables to include `RuleConditionalTransferLightMultiToken`.
- Added technical documentation: `doc/technical/RuleMintAllowance.md`.
- Updated restriction code table, rule index, role summary, and Ownable2Step list in README.
- Documented that `RuleMintAllowance` does not work with pure ERC-3643 3-arg mint callbacks; it requires the spender-aware CMTAT/RuleEngine path.

### Testing

- Add `test/TransferContext/OverloadParity.t.sol` — asserts overload parity across all 7 rules that inherit `RuleNFTAdapter`: every ERC-7943 `tokenId` overload returns exactly what its fungible counterpart returns (`tokenId` is ignored by design), the write overloads accept/reject identically, and the `ITransferContext` struct entrypoints dispatch to the same internal hooks. Closes the per-rule gap for `RuleBlacklist`, `RuleSanctionsList`, `RuleERC2980` and `RuleIdentityRegistry`, and pins threat `AC-5` (the `ctx` entrypoints are unguarded but view-only on validation rules, so they mutate nothing).
- Add `test/invariant/` — the project's first stateful invariant suite (`StdInvariant`, `fail_on_revert = true`). Handler-driven fuzzing over the two stateful rules: `RuleConditionalTransferLight` (approval conservation, `INV-5`) and `RuleMintAllowance` (exact quota accounting via a ghost mirror, `INV-7`). 4 invariants × 8 192 calls each, 0 reverts. The handlers also prove mint/burn never consume an approval and that non-mint transfers never touch a quota. Both invariants were mutation-verified (injecting an approval double-spend and an off-by-one quota deduction makes them fail). Adds an `[invariant]` section to `foundry.toml`.
- Add `test/ThreatModel/ThreatModelTests.t.sol` — 18 threat-model proof-of-concept tests (15 unit/integration, 3 fuzz) covering the identity-registry mint path, `RuleMaxTotalSupply` view overflow, the multi-token approval-key divergence, `approveAndTransferIfAllowed` under a `RuleEngine`, residual state after `unbindToken`, `_transferHash` injectivity, mint-quota accounting, and `RuleWhitelistWrapper` child-rule composition. Tests suffixed `_CurrentBehaviour` assert behaviour the audit considers wrong: fixing the underlying issue must make them fail.
- Add `test/MintBurnFlags/MintBurnFlags.t.sol` and `test/RuleConditionalTransferLightMultiToken/MultiTokenSurface.t.sol` — cover the new `allowMint` / `allowBurn` setters, their access control and events, the dedicated mint/burn restriction codes, and the multi-token pre-flight surface. Also `test/InterfaceId/AddressListInterfaceId.t.sol`, `test/StaleState/StaleStateHygiene.t.sol`, `test/RuleConditionalTransferLight/RuleConditionalTransferLightBindRuleEngine.t.sol`.
- Close the last reachable coverage gaps introduced by this release: the `messageForTransferRestriction` lookups for the new mint/burn codes (`24`/`25` on the whitelist family, `64`/`65` on ERC-2980) and the wrapper's degenerate `from == 0 && to == 0` branch — the anti-drift guard that keeps `RuleWhitelistWrapper` and `RuleWhitelistBase` agreeing — were all reachable but unexecuted. 5 tests added; **every uncovered line in `src/` is now an abstract declaration with no body.**
- Regenerate the coverage report in `doc/coverage` (`forge coverage --report lcov` + `genhtml`).
- **Full suite: 511 tests across 78 suites — 97.8% line coverage (1 082/1 106), 97.3% branch coverage (220/226)** (up from 425 tests / 94.91% lines).
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
