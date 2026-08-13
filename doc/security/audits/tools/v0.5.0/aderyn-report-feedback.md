# Aderyn `v0.5.0` — triage

```bash
aderyn -x mocks --output doc/security/audits/tools/v0.5.0/aderyn-report.md
```

Tool: **Aderyn 0.6.5** · Compiler: solc `0.8.36` · Run date: **2026-08-13**
Scope: production contracts only, mocks excluded via `-x mocks`. **3 915 nSLOC.**
**0 High · 9 Low categories, 332 instances.**

This run supersedes the two earlier `v0.5.0` runs: 2026-08-11 at solc 0.8.34, and an earlier 2026-08-13 run
made before `RuleMaxBalance` and the `ChainlinkPoRFeedManager` split landed.

**Executive triage: nothing to fix.** Aderyn reports no High or Medium finding. Every Low category is a false
positive, a by-design pattern, an environment note, or cosmetic. **No new category appeared**; the instance
growth is proportional to the seven contracts added. Aderyn scopes to project sources from the Foundry config,
so no `lib/` citation appears (verified: `grep -c 'lib/' aderyn-report.md` → 0).

## Per-category triage

| ID | Finding | Instances | Disposition | Reason (verified against source) |
|---|---|---|---|---|
| L-1 | Centralization Risk | 80 | **By design** | Every privileged action is an intentional operator capability: list management, oracle configuration, supply and balance caps, exemptions, approvals. Each is documented per rule under Access Control, and the trust model is stated in the audit report. A compliance rule without a privileged operator would not do its job. |
| L-2 | Unspecific Solidity Pragma | 85 | **By design** | A library must float `^0.8.20` so integrators can pin their own compiler. This repository's own builds are pinned by `foundry.toml` (0.8.36). Pinning in source would force every consumer onto one compiler. |
| L-3 | Address State Variable Set Without Checks | 3 | **False positive** | Each cited assignment is preceded by validation Aderyn does not follow into: `TokenSupplyReader._validateTokenContract`, `ChainlinkPoRFeedManager._setReservesFeed` and `RuleMaxBalanceBase._setBalanceToken` each check non-zero, has-code, and that the required call is answerable before assigning. |
| L-4 | Literal Instead of Constant | 2 | **Cosmetic** | The `10` in `10 ** (to - from)` is the decimal base of a scaling conversion, not a magic number. Naming it would not make the expression clearer. |
| L-5 | PUSH0 Opcode | 87 | **Environment** | The repo targets the `prague` EVM, where PUSH0 exists. Relevant only when deploying to a chain that predates Shanghai, which is a deployer decision, not a code defect. |
| L-6 | Modifier Invoked Only Once | 1 | **By design** | `RuleWhitelistShared`'s mint/burn manager modifier is the extension point subclasses override; single use in the base is the pattern, not an accident. |
| L-7 | Empty Block | 70 | **By design** | `_authorize*` hooks whose entire body is the `onlyRole(...)` modifier, plus constructor pass-throughs. The project convention makes these hooks `internal view virtual` so the check is compiler-enforced; the body is deliberately empty. |
| L-8 | Costly operations inside loop | 3 | **By design** | Batch add/remove must write per element — that is what a batch operation is. Two are in `AddressSetBatchLib`, the shared implementation; the third is `RuleMintAllowanceBase`. |
| L-9 | Unchecked Return | 1 | **By design** | `AccessControlModuleStandalone` ignores `_grantRole`'s boolean, which reports only whether the role was newly granted. Granting a role the account already holds is an intended no-op. |

## Delta from the previous run

| | Previous (2026-08-13, pre-`RuleMaxBalance`) | This run | Δ |
|---|---|---|---|
| nSLOC | 3 674 | **3 915** | +241 |
| Categories | 9 | **9** | — |
| Instances | 315 | **332** | +17 |

| Category | Before | After | Cause |
|---|---|---|---|
| Centralization Risk | 77 | 80 | The three `RuleMaxBalance` privileged setters (cap, token, exemptions) |
| Unspecific Solidity Pragma | 79 | 85 | Six new source files |
| PUSH0 Opcode | 81 | 87 | Same six files |
| Empty Block | 68 | 70 | The two new `_authorizeMaxBalanceManager` overrides, one per deployment variant |
| Everything else | — | unchanged | — |

**Every increase is accounted for by the new contracts, and no category moved that should not have.** That is
the check that rules out a scope regression: nSLOC rose 6.6% and instances rose 5.4%, roughly in step, while
the four categories with no new code (L-3, L-4, L-6, L-8, L-9) are identical instance-for-instance.

**The dependency and compiler bumps produced no new findings.** solc `0.8.34` → `0.8.36`, OpenZeppelin
`v5.6.1` → `v5.7.0`, RuleEngine `v3.0.0-rc4` → `v3.0.0-rc5` and CMTAT `v3.3.0-rc1` → `v3.3.0-rc3` all landed
between the two runs. Notably `L-5 PUSH0` did **not** move beyond the new files, which is what you would expect
given the EVM target is unchanged.

**The `ChainlinkPoRFeedManager` split produced no new findings.** Its `_set*` functions and the feed read moved
between files without changing; `L-3` still reports three instances, now including the manager rather than
`RuleChainlinkPoRBase`.
