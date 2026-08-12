# Aderyn Report — Feedback

Report version: `v0.5.0`
Aderyn report: [aderyn-report.md](./aderyn-report.md)
Tool: Aderyn 0.6.5 · Scope: production contracts only (**mocks excluded** via `-x mocks`)
Feedback date: 2026-08-11

**Executive triage: nothing to fix.** 0 High. All 10 Low categories are by design, environmental, cosmetic, or
false positives. One category is new in this release (`L-4`) and one grew materially (`L-3`); both were verified
against the source before being dismissed.

## Per-finding triage

| ID | Finding | Instances | Disposition | Reason (verified against source) |
|---|---|---|---|---|
| L-1 | Centralization Risk | 77 | **By design** | Every hit is a privileged operator action — list management, oracle configuration, approvals, binding. A permissioned compliance library *is* centralised by construction; the question is whether each capability is intended and documented, and each is, under the Access Control section of its rule doc. |
| L-2 | Unspecific Solidity Pragma | 78 | **By design** | Sources declare `^0.8.20`. A library must float its pragma so integrators can compile against their own pinned version; this repository pins `solc = "0.8.34"` in `foundry.toml` for its own builds, which is where a pin belongs. |
| L-3 | Address State Variable Set Without Checks | 4 | **False positive** | Each cited assignment is preceded by validation the tool does not follow into. `RuleChainlinkPoRBase#L223` (`reservesFeed = …`) sits after a zero-address check, a `code.length` check and a `decimals()` probe. `RuleMaxTotalSupplyBase#L38` and `#L74` both call `_validateTokenContract(...)` — zero-address, has-code, and a `totalSupply()` probe — immediately before assigning. `RuleSanctionsListBase#L125` is the deliberate clear-oracle path, where `address(0)` is the documented disable value. |
| L-4 | Literal Instead of Constant | 2 | **Cosmetic** | `RuleChainlinkPoRBase#L350` and `#L357`: the `10` in `10 ** uint256(to - from)`. That is the decimal base of the fixed-point conversion, not a tunable magic number; naming it `TEN` would add indirection without adding meaning. The exponent bounds it references (`MAX_TOKEN_DECIMALS`, `MAX_FEED_DECIMALS`) **are** named constants. |
| L-5 | PUSH0 Opcode | 79 | **Environment** | `foundry.toml` targets `evm_version = 'prague'`, which has PUSH0. Only relevant to a deployer targeting a chain that predates Shanghai, who would need to recompile with a lower target anyway. |
| L-6 | Modifier Invoked Only Once | 2 | **By design** | The modifier is the extension point: `onlyAddressListAdd` wraps `_authorizeAddressListAdd()`, which concrete deployment variants override with their own access-control policy. Inlining it would remove the hook. |
| L-7 | Empty Block | 68 | **By design** | Almost all are `_authorize*() internal view virtual override onlyRole(X) {}` — the body is empty because the *modifier* is the implementation. The rest are constructor pass-throughs. This is the template-method pattern the repo documents as its access-control convention. |
| L-8 | Loop Contains `require`/`revert` | 3 | **By design** | The batch add/remove loops reject `address(0)` per invariant I-12. The revert is deliberate rather than a skip: silently dropping the zero address would make the emitted batch event describe a member that is not in the set. That reasoning is recorded in `RuleAddressSetInternal._addAddresses`. |
| L-9 | Costly operations inside loop | 7 | **By design** | Batch list operations must write storage per element; there is no batching primitive for `EnumerableSet`. Callers who want one transaction per address can use the single-address entrypoints. |
| L-10 | Unchecked Return | 13 | **By design** | `EnumerableSet.add` / `.remove` returns are ignored where the outer code has already established the outcome — e.g. `RuleAddressSetInternal#L85` and `#L93` are called only after a `require(!_isAddressListed(...))` / `require(_isAddressListed(...))` in the public wrapper. `AccessControlModuleStandalone#L35` ignores `_grantRole`'s return, which is `false` only when the admin already holds the role. Each site carries a comment saying so. |

## Delta from `v0.4.0`

v0.4.0: 0 High · 9 Low categories.
v0.5.0: 0 High · 10 Low categories (333 instances).

| Finding | v0.4.0 | v0.5.0 | Cause |
|---|---|---|---|
| L-1 Centralization Risk | 68 | 77 | +9 — new privileged setters on `RuleChainlinkPoR`, `RuleReceiverWhitelist`, `IdentityRegistryWhitelist` |
| L-2 Unspecific Pragma | 63 | 78 | +15 — one per new source file |
| L-3 Address Set Without Checks | 1 | 4 | +3 — the new `tokenContract` / `reservesFeed` setters (all validated; see above) |
| L-4 Literal Instead of Constant | — | 2 | **new category** — `_scaleReserve`'s decimal base |
| L-5 PUSH0 | 64 | 79 | +15 — one per new source file |
| L-7 Empty Block | 61 | 68 | +7 — new `_authorize*` hooks |
| L-6, L-8, L-9, L-10 | 2, 3, 7, 13 | 2, 3, 7, 13 | unchanged |

The renumbering (v0.4.0's L-4 PUSH0 is v0.5.0's L-5, and so on) is Aderyn inserting the new `Literal Instead of
Constant` category at position 4 — not a change in the underlying findings.

**Every increase is proportional to the three contracts added in this release.** L-1, L-2, L-5 and L-7 are
per-file or per-privileged-function categories, so they scale with contract count rather than with risk; a
release that adds contracts and changes nothing else will always grow them. The categories that would signal a
behavioural change — L-6, L-8, L-9, L-10 — are all unchanged.

## What this report is not

Aderyn found nothing in the areas where this release actually changed behaviour: the guarded `totalSupply()`
reads, the live feed-decimals read that prevents a stale-cache over-mint, the removal of two inert public roles,
and the ERC-3643 receiver-only screening semantics. Those came from manual review and targeted tests. A clean
static-analysis report means the tool's pattern set found nothing — not that the code is correct.
