# Aderyn `v0.5.0` — triage

```bash
aderyn -x mocks --output doc/security/audits/tools/v0.5.0/aderyn-report.md
```

Tool: **Aderyn 0.6.5** · Run date: **2026-08-13** (re-run of `v0.5.0`, replacing the 2026-08-11 run)
Scope: production contracts only, mocks excluded via `-x mocks`. 3 674 nSLOC.
**0 High · 9 Low categories, 315 instances.**

**Executive triage: nothing to fix.** Aderyn reports no High or Medium finding. Every Low category is a false
positive, a by-design pattern, an environment note, or cosmetic. Aderyn scopes to project sources from the
Foundry config, so no `lib/` citation appears (verified: `grep -c 'lib/' aderyn-report.md` → 0).

## Per-category triage

| ID | Finding | Instances | Disposition | Reason (verified against source) |
|---|---|---|---|---|
| L-1 | Centralization Risk | 77 | **By design** | Every privileged action is an intentional operator capability: list management, oracle configuration, supply caps, approvals. Each is documented per rule under Access Control, and the trust model is stated in the audit report. A compliance rule without a privileged operator would not do its job. |
| L-2 | Unspecific Solidity Pragma | 79 | **By design** | A library must float `^0.8.20` so integrators can pin their own compiler. This repository's own builds are pinned by `foundry.toml` (0.8.34). Pinning in source would force every consumer onto one compiler. |
| L-3 | Address State Variable Set Without Checks | 3 | **False positive** | Each cited assignment is preceded by validation Aderyn does not follow into: `TokenSupplyReader._validateTokenContract` (non-zero, has code, `totalSupply()` callable) and `RuleChainlinkPoRBase._setReservesFeed` (non-zero, has code, `decimals()` within bounds). |
| L-4 | Literal Instead of Constant | 2 | **Cosmetic** | The `10` in `10 ** (to - from)` is the decimal base of a scaling conversion, not a magic number. Naming it would not make the expression clearer. |
| L-5 | PUSH0 Opcode | 81 | **Environment** | The repo targets the `prague` EVM, where PUSH0 exists. Relevant only when deploying to a chain that predates Shanghai, which is a deployer decision, not a code defect. |
| L-6 | Modifier Invoked Only Once | 1 | **By design** | `RuleWhitelistShared`'s mint/burn manager modifier is the extension point subclasses override; single use in the base is the pattern, not an accident. |
| L-7 | Empty Block | 68 | **By design** | `_authorize*` hooks whose entire body is the `onlyRole(...)` modifier, plus constructor pass-throughs. The project convention makes these hooks `internal view virtual` so the check is compiler-enforced; the body is deliberately empty. |
| L-8 | Costly operations inside loop | 3 | **By design** | Batch add/remove must write per element — that is what a batch operation is. Two of the three are now in `AddressSetBatchLib`, the shared implementation; the third is `RuleMintAllowanceBase`. |
| L-9 | Unchecked Return | 1 | **By design** | `AccessControlModuleStandalone` ignores `_grantRole`'s boolean, which reports only whether the role was newly granted. Granting a role the account already holds is an intended no-op. |

## Delta from the 2026-08-11 run of `v0.5.0`

2026-08-11: 10 Low categories, **333 instances**.
2026-08-13: 9 Low categories, **315 instances**.

Three categories moved sharply. All three trace to one change — the `AddressSetBatchLib` refactor
(`CLAUDE_ANALYSIS.md` D-1), which replaced duplicated batch loops in `RuleAddressSet`, `RuleAddressSetInternal`
and `RuleERC2980Internal` with a single shared implementation.

| Category | Before | After | Cause |
|---|---|---|---|
| *Loop Contains `require`/`revert`* | 3 | **category gone** | The zero-address guard is now passed to the shared loop as an internal function pointer, so no loop *lexically* contains a `require`. The guard still reverts — behaviour is unchanged and the tests covering zero-address rejection still pass. |
| Unchecked Return | 13 | 1 | The duplicated loops discarded `EnumerableSet.add` / `.remove` return values. The library **uses** them (`if (set.add(...))`) to count added versus skipped entries, so twelve instances disappeared by being consumed rather than suppressed. |
| Costly operations inside loop | 7 | 3 | One implementation instead of several. |
| Unspecific Solidity Pragma | 78 | 79 | One new file: `script/base/CMTATDeploymentBase.sol`. |
| PUSH0 Opcode | 79 | 81 | Same, plus the rewritten deployment scripts. |
| Address State Variable Set Without Checks | 4 | 3 | One assignment removed by the same refactor. |
| Modifier Invoked Only Once | 2 | 1 | One modifier gained a second call site. |

**This is a reduction earned by a refactor, not a scope change.** nSLOC and contract count both rose over the
same interval, and the categories that fell are exactly the ones the consolidated loop touches. Instance counts
in the untouched categories (Centralization Risk 77, Empty Block 68) are identical across both runs, which is
the check that rules out a scope regression.
