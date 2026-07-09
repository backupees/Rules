# Aderyn Report — Feedback

Report version: `v0.4.0`
Aderyn report: [aderyn-report.md](./aderyn-report.md)
Tool: Aderyn 0.6.5 · Scope: production contracts only, 63 files (**mocks excluded**)
Feedback date: 2026-07-08

This document provides the project team's assessment of each finding reported by the Aderyn static analyser. Verdicts:

| Verdict | Meaning |
|---|---|
| **Acknowledged** | Known, accepted by design; no change planned. |
| **By design** | Behaviour is intentional and required by the architecture. |
| **Fixed** | Resolved in the codebase. |
| **To fix** | Will be addressed in a future revision. |
| **False positive** | Tool mis-identification; no real issue exists. |

All 8 findings are **Low** severity. No High or Medium issues were reported.

---

## L-1: Centralization Risk — 62 instances

**Verdict: By design**

This library implements compliance rules for regulated security tokens (CMTAT / ERC-3643). Admin and operator roles are intentionally held by the issuer/compliance operator — an explicit trust assumption, not a bug.

---

## L-2: Unspecific Solidity Pragma — 63 instances

**Verdict: By design**

The repository intentionally uses `pragma solidity ^0.8.20` to stay integrator-friendly, while the project itself is built deterministically via `foundry.toml` (`solc = 0.8.34`).

---

## L-3: Address State Variable Set Without Checks — 1 instance

**Verdict: False positive**

Flagged location: `RuleSanctionsListBase._setSanctionListOracle` (`src/rules/validation/abstract/base/RuleSanctionsListBase.sol#L125`).

The zero-address guard is enforced at the public boundary `setSanctionListOracle(...)` (`#L61-L62`, reverts with `RuleSanctionsList_OracleAddressZeroNotAllowed`). The internal setter accepts `address(0)` intentionally because `clearSanctionListOracle()` must disable the oracle.

---

## L-4: PUSH0 Opcode — 63 instances

**Verdict: By design — not applicable**

The project targets `evm_version = "prague"` in `foundry.toml`; deployment targets are expected to support Shanghai+ opcodes including `PUSH0`.

---

## L-5: Modifier Invoked Only Once — 2 instances

**Verdict: By design (template method pattern)**

Flagged modifiers are deliberate authorization wrappers over abstract `_authorize*` hooks. Inlining would weaken consistency across the AccessControl and Ownable variants.

---

## L-6: Empty Block — 55 instances

**Verdict: By design (template method pattern / interface compliance)**

Most empty blocks are `_authorize*` hook implementations where the check is provided by modifiers (`onlyRole`, `onlyOwner`). Others are intentional no-ops required by shared interfaces in rules that are read-only for specific paths.

---

## L-7: Costly operations inside loop — 6 instances

**Verdict: By design — unavoidable**

Flagged loops perform `EnumerableSet` insert/remove operations across batch APIs. These are inherently storage writes (`SSTORE`) per item, so linear gas growth is expected and unavoidable.

---

## L-8: Unchecked Return — 13 instances

**Verdict: Mixed — majority false positives**

| Instance | Assessment |
|---|---|
| `_grantRole(DEFAULT_ADMIN_ROLE, admin)` in `AccessControlModuleStandalone` | **Acknowledged / low impact** — constructor path; a duplicate grant returns `false` and is not expected on fresh deployment. |
| `_addAddresses(...)` / `_removeAddresses(...)` batch helpers | **False positive** — `void` helpers, no return value to check. |
| `_listedAddresses.add/remove` in `RuleAddressSetInternal` single-item helpers | **False positive** — correctness guaranteed by outer pre-checks in public single-item methods. |
| `_whitelist.add/remove` and `_frozenlist.add/remove` in `RuleERC2980Internal` single-item helpers | **False positive** — same pre-check pattern. |
| batch `_add*Addresses` / `_remove*Addresses` helpers | **False positive** — no unchecked boolean return at the API boundary. |

---

## Delta from v0.3.0

No new finding *categories*. Instance counts increased because `v0.4.0` adds the `RuleMintAllowance` and `RuleConditionalTransferLightMultiToken` contract families:

| ID | v0.3.0 | v0.4.0 |
|---|---|---|
| L-1 Centralization Risk | 46 | 62 |
| L-2 Unspecific Pragma | 54 | 63 |
| L-3 Address Set Without Checks | 1 | 1 |
| L-4 PUSH0 Opcode | 54 | 63 |
| L-5 Modifier Invoked Once | 2 | 2 |
| L-6 Empty Block | 38 | 55 |
| L-7 Costly ops in loop | 6 | 6 |
| L-8 Unchecked Return | 13 | 13 |

## Executive triage

**Nothing to fix.** Every finding is Low severity and either by-design (centralization, pragma, PUSH0, template-method modifiers/empty blocks, EnumerableSet loop cost) or a false positive (L-3, and the majority of L-8). None is exploitable.

## Summary

| ID | Title | Instances | Verdict |
|---|---|---|---|
| L-1 | Centralization Risk | 62 | By design |
| L-2 | Unspecific Solidity Pragma | 63 | By design |
| L-3 | Address State Variable Set Without Checks | 1 | False positive |
| L-4 | PUSH0 Opcode | 63 | By design — not applicable |
| L-5 | Modifier Invoked Only Once | 2 | By design |
| L-6 | Empty Block | 55 | By design |
| L-7 | Costly operations inside loop | 6 | By design — unavoidable |
| L-8 | Unchecked Return | 13 | Mixed (majority false positives) |
