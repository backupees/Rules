# Aderyn `v0.5.0` — triage

```bash
aderyn -x mocks --output doc/security/audits/tools/v0.5.0/aderyn-report.md
```

Tool: **Aderyn 0.6.5** · Compiler: solc `0.8.36` · Run date: **2026-08-13**
Scope: production contracts only, mocks excluded via `-x mocks`. **3 942 nSLOC.**
**0 High · 9 Low categories, 336 instances.**

This run supersedes the earlier `v0.5.0` runs and was made after the cap-manager split
(`TotalSupplyCapManager`, `BalanceCapManager`).

**Executive triage: nothing to fix.** Aderyn reports no High or Medium finding. Every Low category is a false
positive, a by-design pattern, an environment note, or cosmetic. **No new category appeared**; the instance
growth is exactly the two files added by the cap-manager split. Aderyn scopes to project sources from the Foundry config,
so no `lib/` citation appears (verified: `grep -c 'lib/' aderyn-report.md` → 0).

## Per-category triage

| ID | Finding | Instances | Disposition | Reason (verified against source) |
|---|---|---|---|---|
| L-1 | Centralization Risk | 80 | **By design** | Every privileged action is an intentional operator capability: list management, oracle configuration, supply and balance caps, exemptions, approvals. Each is documented per rule under Access Control, and the trust model is stated in the audit report. A compliance rule without a privileged operator would not do its job. |
| L-2 | Unspecific Solidity Pragma | 87 | **By design** | A library must float `^0.8.20` so integrators can pin their own compiler. This repository's own builds are pinned by `foundry.toml` (0.8.36). Pinning in source would force every consumer onto one compiler. |
| L-3 | Address State Variable Set Without Checks | 3 | **False positive** | Verified against each cited file. `TotalSupplyCapManager` and `ChainlinkPoRFeedManager` both validate before assigning — non-zero, has-code, and the required call answerable — through `_validateTokenContract` / `_setReservesFeed`, which Aderyn does not follow into. `RuleSanctionsListBase` is a different case: its internal `_setSanctionListOracle` assigns unguarded **on purpose**, because `clearSanctionListOracle` legitimately writes `address(0)` to disable screening; the non-zero check lives in `setSanctionListOracle` and in the constructor, which only calls it for a non-zero oracle. |
| L-4 | Literal Instead of Constant | 2 | **Cosmetic** | The `10` in `10 ** (to - from)` is the decimal base of a scaling conversion, not a magic number. Naming it would not make the expression clearer. |
| L-5 | PUSH0 Opcode | 89 | **Environment** | The repo targets the `prague` EVM, where PUSH0 exists. Relevant only when deploying to a chain that predates Shanghai, which is a deployer decision, not a code defect. |
| L-6 | Modifier Invoked Only Once | 1 | **By design** | `RuleWhitelistShared`'s mint/burn manager modifier is the extension point subclasses override; single use in the base is the pattern, not an accident. |
| L-7 | Empty Block | 70 | **By design** | `_authorize*` hooks whose entire body is the `onlyRole(...)` modifier, plus constructor pass-throughs. The project convention makes these hooks `internal view virtual` so the check is compiler-enforced; the body is deliberately empty. |
| L-8 | Costly operations inside loop | 3 | **By design** | Batch add/remove must write per element — that is what a batch operation is. Two are in `AddressSetBatchLib`, the shared implementation; the third is `RuleMintAllowanceBase`. |
| L-9 | Unchecked Return | 1 | **By design** | `AccessControlModuleStandalone` ignores `_grantRole`'s boolean, which reports only whether the role was newly granted. Granting a role the account already holds is an intended no-op. |

## Delta from the previous run

| | Previous (pre cap-manager split) | This run | Δ |
|---|---|---|---|
| nSLOC | 3 915 | **3 942** | +27 |
| Categories | 9 | **9** | — |
| Instances | 332 | **336** | +4 |

The entire increase is **two new files**: `TotalSupplyCapManager` and `BalanceCapManager` each add one
`Unspecific Solidity Pragma` and one `PUSH0 Opcode` instance. Every other category — including the four that
describe behaviour (`Address State Variable Set Without Checks`, `Costly operations inside loop`,
`Unchecked Return`, `Modifier Invoked Only Once`) and the two largest (`Centralization Risk` 80,
`Empty Block` 70) — is identical instance-for-instance.

That is what a pure code move should look like: per-file categories track the file count, and nothing
behavioural shifts. `Centralization Risk` staying at 80 is the sharpest signal, since the setters moved from the
bases into the managers without any being added or removed.
