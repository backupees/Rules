# Slither `v0.5.0` — triage

```bash
slither . --checklist --filter-paths "node_modules,lib,test,forge-std,mocks" \
  > doc/security/audits/tools/v0.5.0/slither-report.md
```

Tool: **Slither 0.11.5** · Run date: **2026-08-13** (re-run of `v0.5.0`, replacing the 2026-08-11 run)
Scope: production contracts only. Mocks excluded via the `mocks` filter, vendored dependencies via `lib`.
199 contracts, 101 detectors, **43 results**.

**Executive triage: nothing to fix.** No finding is exploitable. Two are High by detector severity and both are
false positives on a permissioned path. One informational finding changed disposition since the last run, and it
is a correction rather than a code change — see [`unused-state`](#unused-state-correction-to-the-previous-triage).

### Scope check

Both scope assertions pass on this run:

```
grep -c 'lib/\|node_modules/' slither-report.md   → 0
grep -c 'test/\|src/mocks/'   slither-report.md   → 0
```

The filter list matters on this repository. A first run of `v0.5.0` used a generic `submodules` filter; because
this is a Foundry project the vendored dependencies live in `lib/`, so they entered scope and the run reported
**170 results, 351 of them citing `lib/openzeppelin-contracts/`**. If a future run's count jumps by an order of
magnitude, check the filter before reading anything into it.

## Per-detector triage

| Detector | Severity | Instances | Disposition | Reason (verified against source) |
|---|---|---|---|---|
| `arbitrary-send-erc20` | **High** | 2 | **False positive** | `RuleConditionalTransferLightMultiTokenBase.approveAndTransferIfAllowed` passes a caller-supplied `from` to `safeTransferFrom`, but the call is reachable only through `onlyTransferApprover`, requires a previously recorded approval for the exact `(token, from, to, value)` tuple, and still needs the holder's own ERC-20 allowance. The holder's approval is the authorisation; the rule cannot move tokens the holder has not already approved. |
| `uninitialized-local` | Medium | 2 | **False positive** | `RuleChainlinkPoRBase`'s `newFeedDecimals` and `currentFeedDecimals`. Both are declared before a `try` and assigned inside it — Solidity requires this, since a `try` cannot declare a variable that outlives its own scope. The matching `catch` **reverts** or **returns**, so control never reaches a read with the variable unset. |
| `unused-return` | Medium | 8 | **False positive** | Six are the batch helpers in `RuleAddressSetInternal` and `RuleERC2980Internal`, e.g. `return _whitelist.removeBatch(addressesToRemove);` — the `(removed, skipped)` tuple is **returned straight to the caller**, so nothing is discarded; Slither flags the forwarding pattern itself. The other two are deliberate probes: `TokenSupplyReader`'s `try …totalSupply()` (only the revert matters) and `RuleChainlinkPoRBase`'s partial destructuring of `latestRoundData()`, which ignores `roundId` / `startedAt` / `answeredInRound` on purpose. |
| `calls-loop` | Low | 16 | **By design** | `RuleWhitelistWrapperBase`'s child-rule scan and the batch list operations. The gas cost is documented with measurements in [`RuleWhitelistWrapper.md`](../../../../technical/RuleWhitelistWrapper.md#gas-cost-of-the-child-rule-scan), including the operator guidance to keep the child list at or below 10. |
| `timestamp` | Low | 1 | **By design** | `RuleChainlinkPoRBase._maxBackedSupply` compares `block.timestamp` against the feed's `updatedAt`. That comparison **is** the Proof-of-Reserve staleness feature. It is guarded against underflow, and `maxStalenessSeconds` is configured from the feed heartbeat — hours — so validator drift of a few seconds cannot flip the outcome. |
| `assembly` | Informational | 2 | **By design** | `RuleConditionalTransferLightApprovalBase._transferHash` and `IdentityRegistryWhitelistBase._walletKey`, both written in assembly to satisfy the project's `asm-keccak256` lint convention. The second is pinned by a test asserting it is byte-identical to `keccak256(abi.encode(wallet))`. |
| `dead-code` | Informational | 2 | **False positive** | **New this run.** `RuleAddressSetInternal._requireNotZeroAddress` and `RuleERC2980Internal._requireNotZeroAddress` are reported as never used. Both **are** used — passed as internal function pointers to `AddressSetBatchLib.addBatch` (`RuleAddressSetInternal.sol:49`, `RuleERC2980Internal.sol:52` and `:101`). Slither does not resolve internal function pointers. The zero-address rejection is still exercised by the test suite. |
| `naming-convention` | Informational | 6 | **By design** | Four are `_userAddress` / `_identity` in `IdentityRegistryWhitelistBase`, reproducing the ERC-3643 `IIdentityRegistry` parameter names **verbatim** so the interface reads identically to the standard. Two are pre-existing in `RuleERC2980Base`. |
| `unused-state` | Informational | 4 | **Cosmetic** | The four `TRANSFERRED_SELECTOR_*` constants in `RuleNFTAdapter`. See below — this corrects the previous triage. |

## `unused-state`: correction to the previous triage

The 2026-08-11 feedback recorded these as a **false positive**, on the grounds that the selector constants "are
consumed by the adapter's dispatch, not referenced by name from the subclass Slither reports them against".

**That reason is wrong.** Each constant occurs exactly once in the entire repository — its own declaration:

| Constant | Occurrences in `src/`, `test/`, `script/` |
|---|---|
| `TRANSFERRED_SELECTOR_ERC3643` | 1 (declaration) |
| `TRANSFERRED_SELECTOR_RULE_ENGINE` | 1 (declaration) |
| `TRANSFERRED_SELECTOR_ERC7943` | 1 (declaration) |
| `TRANSFERRED_SELECTOR_ERC7943_FROM` | 1 (declaration) |

There is no dispatch that reads them. Slither is right: they are unreferenced.

**Impact: none.** They are `internal constant`, so they occupy no storage slot and, being unused, are not
emitted into the deployed bytecode. Nothing is wasted at runtime and no behaviour depends on them. They read as
documentation of the four `transferred` overload selectors the adapter supports.

**Disposition: cosmetic, not fixed.** Either delete them or add a test asserting each equals the selector of the
corresponding overload, which would make them load-bearing and keep the ERC-7943 signatures pinned. Recorded
here rather than fixed because this run is a re-analysis, not a code change.

The instance count halved (8 → 4) only because the same four constants were previously reported against both
`RuleIdentityRegistry` and `RuleIdentityRegistryOwnable2Step`, and are now reported against the Ownable2Step
variant alone. No constant was removed and no behaviour changed.

## Delta from the 2026-08-11 run of `v0.5.0`

2026-08-11: 2 High · 11 Medium · 17 Low · 16 Informational (46 results, 191 contracts).
2026-08-13: 2 High · 10 Medium · 17 Low · 14 Informational (**43 results**, 199 contracts).

Contract count rose by 8 while results fell by 3. Both are explained by work landed between the two runs.

| Change | Cause |
|---|---|
| +8 contracts | The deployment-script rework: `script/base/CMTATDeploymentBase.sol` plus the four rewritten scripts (`CLAUDE_ANALYSIS_SCRIPT.md`). `script/` is not in the filter list, so scripts are in scope. |
| `dead-code` 0 → 2 | The `AddressSetBatchLib` refactor (`CLAUDE_ANALYSIS.md` D-1) moved the zero-address guard behind an internal function pointer, which Slither cannot follow. False positive. |
| `unused-return` 9 → 8 | Same refactor: the batch loops now live in one library and forward their `(added, skipped)` tuple instead of discarding `EnumerableSet` return values in duplicated loops. |
| `unused-state` 8 → 4 | Reporting shape only — the same four constants, now attributed to one contract instead of two. |

No new detector fired on the deployment scripts.
