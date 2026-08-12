# Slither Report — Feedback

Report version: `v0.5.0`
Slither report: [slither-report.md](./slither-report.md)
Tool: Slither 0.11.5 · Scope: production contracts only (**mocks excluded**, dependencies excluded via the `lib`
filter) · 191 contracts, 101 detectors, 46 results
Feedback date: 2026-08-11

> **Note (2026-08-12):** after this run, code `77` was split into `77` (a round returned but unusable) and a new
> `79` (feed unreadable). That is a diagnostic refinement with no behavioural change — the same inputs block the
> same mints — so no finding below is affected, but line numbers in `RuleChainlinkPoRBase` have shifted.

**Executive triage: nothing to fix.** No finding is exploitable and none tracks a real defect. Two categories are
new in this release and both were verified against the source before being dismissed — see `uninitialized-local`
and `timestamp` below.

## Scope note — read this before comparing runs

The command must filter **`lib`**, not `submodules`:

```bash
slither . --checklist --filter-paths "node_modules,lib,test,forge-std,mocks"
```

A first run of this release used a generic `submodules` filter instead. Because this is a Foundry project, the
vendored dependencies live in `lib/`, so they were pulled into scope and the run reported **170 results — 351 of
them citing `lib/openzeppelin-contracts/`**, i.e. OpenZeppelin's own `Math.mulDiv` assembly rather than anything
in this repository. Re-running with the documented filter gives 46. If a future run's count jumps by an order of
magnitude, check the filter before reading anything into it.

## Per-detector triage

| Detector | Severity | Instances | Disposition | Reason (verified against source) |
|---|---|---|---|---|
| `arbitrary-send-erc20` | **High** | 2 | **False positive** | `RuleConditionalTransferLightMultiTokenBase.approveAndTransferIfAllowed` (L126-142) passes a caller-supplied `from` to `safeTransferFrom`, but the call is reachable only through `onlyTransferApprover`, requires a previously recorded approval for the exact `(token, from, to, value)` tuple, and still needs the holder's own ERC-20 allowance. The holder's approval is the authorisation; the rule cannot move tokens the holder has not already approved. |
| `uninitialized-local` | Medium | 2 | **False positive** | `RuleChainlinkPoRBase`'s `newFeedDecimals` and `currentFeedDecimals`. Both are declared before a `try` and assigned inside it — Solidity requires this, since a `try` cannot declare a variable that outlives its own scope. The matching `catch` **reverts** (L216) or **returns** (L286), so control never reaches a read with the variable unset. |
| `unused-return` | Medium | 9 | **False positive / by design** | Six are the pre-existing `EnumerableSet` add/remove calls in `RuleAddressSetInternal` (L84-86, L92-94) and `RuleERC2980Internal`, where the return is guaranteed by an outer `require` that already checked membership. The three new ones — in `RuleChainlinkPoRBase._setTokenMetadata` / `_maxBackedSupply` and `RuleMaxTotalSupplyBase._validateTokenContract` — are `try ITotalSupply(x).totalSupply() returns (uint256) {}` probes whose **only** purpose is to detect a revert; discarding the value is the point. |
| `calls-loop` | Low | 16 | **By design** | `RuleWhitelistWrapperBase`'s child-rule scan and the batch list operations. The gas cost is documented with measurements in [`RuleWhitelistWrapper.md`](../../../../technical/RuleWhitelistWrapper.md#gas-cost-of-the-child-rule-scan), including the operator guidance to keep the child list at or below 10. |
| `timestamp` | Low | 1 | **By design** | `RuleChainlinkPoRBase._maxBackedSupply` compares `block.timestamp` against the feed's `updatedAt`. That comparison **is** the Proof-of-Reserve staleness feature, not incidental use. It is guarded (`block.timestamp > updatedAt` before subtracting, so a future-dated feed cannot underflow), and `maxStalenessSeconds` is configured from the feed heartbeat — hours — so validator timestamp drift of a few seconds cannot flip the outcome. |
| `assembly` | Informational | 2 | **By design** | `RuleConditionalTransferLightApprovalBase._transferHash` and `IdentityRegistryWhitelistBase._walletKey`, both written in assembly to satisfy the project's `asm-keccak256` lint convention. The second is pinned by a test asserting it is byte-identical to `keccak256(abi.encode(wallet))`. |
| `naming-convention` | Informational | 6 | **By design** | Four are `_userAddress` / `_identity` in `IdentityRegistryWhitelistBase`. These reproduce the ERC-3643 `IIdentityRegistry` parameter names **verbatim** so the interface reads identically to the standard; renaming them for style would make the drop-in claim harder to verify. Two are pre-existing in `RuleERC2980Base`. |
| `unused-state` | Informational | 8 | **False positive** | The ERC-7943 selector constants in `RuleNFTAdapter` (e.g. `TRANSFERRED_SELECTOR_ERC7943_FROM`) are consumed by the adapter's dispatch, not referenced by name from the subclass Slither reports them against. |

## Delta from `v0.4.0`

v0.4.0: 2 High · 6 Medium · 16 Low · 12 Informational (36 results, 168 contracts).
v0.5.0: 2 High · 11 Medium · 17 Low · 16 Informational (46 results, 191 contracts).

| Change | Cause |
|---|---|
| `uninitialized-local` 0 → 2 | New — the two `try feed.decimals()` blocks in `RuleChainlinkPoR` |
| `unused-return` 6 → 9 | New — the `totalSupply()` revert-probes added to `RuleChainlinkPoR` and `RuleMaxTotalSupply` |
| `timestamp` 0 → 1 | New — `RuleChainlinkPoR`'s staleness check |
| `naming-convention` 2 → 6 | New — ERC-3643 parameter names in `IdentityRegistryWhitelist` |
| contracts 168 → 191 | `RuleChainlinkPoR`, `RuleReceiverWhitelist`, `IdentityRegistryWhitelist` + their Ownable2Step variants, bases and invariant stores |

**Every delta traces to code added in v0.5.0, and every one was verified as a false positive or by-design.** The
High and Low `calls-loop` counts are unchanged, so nothing in this release touched the pre-existing patterns.

Worth stating plainly: the hardening that *did* land in v0.5.0 — the guarded `totalSupply()` reads (codes 51/78),
the live feed-decimals read, the removal of the inert address-list roles — resolved **no** Slither finding,
because none of them was ever tracking a real defect. Static analysis did not surface any of those issues; they
came from manual review. That is the honest reading of a clean tool report, and the reason it should not be
mistaken for an audit.
