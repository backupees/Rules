# Slither `v0.5.0` — triage

```bash
slither . --checklist --filter-paths "node_modules,lib,test,forge-std,mocks" \
  > doc/security/audits/tools/v0.5.0/slither-report.md
```

Tool: **Slither 0.11.5** · Compiler: solc `0.8.36` · Run date: **2026-08-13**
Scope: production contracts only. Mocks excluded via the `mocks` filter, vendored dependencies via `lib`.
208 contracts, 101 detectors, **44 results**.

This run supersedes the earlier `v0.5.0` runs and was made after the cap-manager split
(`TotalSupplyCapManager`, `BalanceCapManager`).

**Executive triage: nothing to fix.** No finding is exploitable. The two High-severity results are false
positives on a permissioned path. One finding is new since the previous run, and it is the same false-positive
class as three already dismissed.

### Scope check

Both scope assertions pass:

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
| `uninitialized-local` | Medium | 2 | **False positive** | `ChainlinkPoRFeedManager`'s `newFeedDecimals` and `currentFeedDecimals`. Both are declared before a `try` and assigned inside it — Solidity requires this, since a `try` cannot declare a variable that outlives its own scope. The matching `catch` **reverts** or **returns**, so control never reaches a read with the variable unset. |
| `unused-return` | Medium | 9 | **False positive** | Six are batch helpers in `RuleAddressSetInternal` and `RuleERC2980Internal`, e.g. `return _whitelist.removeBatch(addressesToRemove);` — the `(removed, skipped)` tuple is **returned straight to the caller**, so nothing is discarded; Slither flags the forwarding pattern itself. The other three are deliberate probes: `TokenSupplyReader`'s `try …totalSupply()`, `ChainlinkPoRFeedManager`'s partial destructuring of `latestRoundData()`, and the one new this run — see below. |
| `calls-loop` | Low | 16 | **By design** | `RuleWhitelistWrapperBase`'s child-rule scan and the batch list operations. The gas cost is documented with measurements in [`RuleWhitelistWrapper.md`](../../../../technical/contracts/RuleWhitelistWrapper.md#gas-cost-of-the-child-rule-scan), including the guidance to keep the child list at or below 10. |
| `timestamp` | Low | 1 | **By design** | `ChainlinkPoRFeedManager._maxBackedSupply` compares `block.timestamp` against the feed's `updatedAt`. That comparison **is** the Proof-of-Reserve staleness feature. It is guarded against underflow, and `maxStalenessSeconds` is configured from the feed heartbeat — hours — so validator drift of a few seconds cannot flip the outcome. |
| `assembly` | Informational | 2 | **By design** | `RuleConditionalTransferLightApprovalBase._transferHash` and `IdentityRegistryWhitelistBase._walletKey`, both written in assembly to satisfy the project's `asm-keccak256` lint convention. The second is pinned by a test asserting it is byte-identical to `keccak256(abi.encode(wallet))`. |
| `dead-code` | Informational | 2 | **False positive** | `RuleAddressSetInternal._requireNotZeroAddress` and `RuleERC2980Internal._requireNotZeroAddress` are reported as never used. Both **are** used — passed as internal function pointers to `AddressSetBatchLib.addBatch`. Slither does not resolve internal function pointers. The zero-address rejection is exercised by the test suite. |
| `naming-convention` | Informational | 6 | **By design** | Four are `_userAddress` / `_identity` in `IdentityRegistryWhitelistBase`, reproducing the ERC-3643 `IIdentityRegistry` parameter names **verbatim** so the interface reads identically to the standard. Two are pre-existing in `RuleERC2980Base`. |
| `unused-state` | Informational | 4 | **Cosmetic** | The four `TRANSFERRED_SELECTOR_*` constants in `RuleNFTAdapter`. Each occurs exactly once in the repository — its own declaration — so Slither is right that they are unreferenced. Impact is nil: they are `internal constant`, so they occupy no storage slot and, being unused, are not emitted into the deployed bytecode. Either delete them or add a test asserting each equals the corresponding overload's selector, which would make them load-bearing and pin the ERC-7943 signatures. |

## The one new finding

`unused-return` rose from 8 to 9. The new instance is in `RuleMaxBalanceBase._setBalanceToken`:

```solidity
try IBalanceOf(newBalanceToken).balanceOf(address(this)) returns (uint256) {
    // callable
} catch {
    revert RuleMaxBalance_TokenBalanceUnavailable(newBalanceToken);
}
```

**False positive, and the same class as three findings already dismissed.** The call is a *probe*: its only
purpose is to establish that `balanceOf` does not revert, turning what would otherwise be a silent read-path
failure — every transfer blocked with code `83` — into an immediate, named configuration error. Discarding the
value is the point; there is no balance to act on at configuration time. This mirrors
`TokenSupplyReader._probeTotalSupplyCallable`, dismissed on identical grounds.

## Delta from the previous run

| | Previous (pre cap-manager split) | This run |
|---|---|---|
| Contracts | 206 | **208** |
| Results | 44 | **44** |
| Severity | 2 High · 11 Med · 17 Low · 14 Info | identical |

**Every detector reports the same instance count, one for one.** The split of `RuleMaxTotalSupplyBase` and
`RuleMaxBalanceBase` into `TotalSupplyCapManager` and `BalanceCapManager` moved code between files without
changing it, so `unused-return`, `uninitialized-local`, `timestamp` and the rest report exactly what they did
before, now attributed to the new contracts where relevant. Two contracts were added and produced **no** new
finding.

That is the expected signature of a pure code move, and it is the check worth doing: a refactor that claimed to
be behaviour-preserving but shifted a detector count would deserve a second look. Storage layout and ABI were
separately verified identical for all four affected deployable contracts.
