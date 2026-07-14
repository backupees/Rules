# Slither Report — Feedback

Report version: `v0.4.0`
Slither report: [slither-report.md](./slither-report.md)
Tool: Slither 0.11.5 · Scope: production contracts only (**mocks excluded**) · 168 contracts, 101 detectors, 36 results
Feedback date: 2026-07-14 (re-run after the v0.4.0 security remediation)

**Delta from the 2026-07-08 run: none.** Same tool version, same scope, and the detector tally is identical
(2 High · 6 Medium · 16 Low · 12 Informational, 36 results). The security remediation landed in this release —
ERC-3643 conformance in `RuleIdentityRegistry`, the explicit `allowMint` / `allowBurn` flags, the
`bindToken` / `bindRuleEngine` split, the overflow-safe supply-cap views — introduced **no new Slither finding and
resolved none**, which is expected: every finding below is a false positive or a by-design pattern, so none of them
was ever tracking a real defect that a fix could clear. The triage below therefore stands unchanged.

Verdicts:

| Verdict | Meaning |
|---|---|
| **Acknowledged** | Known, accepted by design; no change planned. |
| **By design** | Behaviour is intentional and required by the architecture. |
| **Fixed** | Resolved in the codebase. |
| **To fix** | Will be addressed in a future revision. |
| **False positive** | Tool mis-identification; no real issue exists. |
| **Out of scope** | Reported location is in dependency code outside this repository. |

---

## arbitrary-send-erc20 (High) — 2 instances

**Verdict: False positive**

Flagged functions:
- `RuleConditionalTransferLightBase.approveAndTransferIfAllowed(address,address,uint256)` (`src/rules/operation/abstract/RuleConditionalTransferLightBase.sol#L86-L101`)
- `RuleConditionalTransferLightMultiTokenBase.approveAndTransferIfAllowed(address,address,address,uint256)` (`src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L121-L138`)

`from` is a parameter, but neither is an arbitrary-drain primitive. In both:

1. Access is restricted by `onlyTransferApprover`.
2. A transfer approval must have been recorded (`_approveTransfer(...)`) — the multi-token variant additionally requires `isTokenBound(token)`.
3. The contract checks `IERC20(token).allowance(from, address(this)) >= value` before transferring.
4. `SafeERC20.safeTransferFrom` only hardens ERC-20 return handling; it does not change the authorization model.

The second instance is new in `v0.4.0` — it is the multi-token sibling of the `v0.3.0` finding and shares the identical guard chain.

---

## unused-return (Medium) — 6 instances

**Verdict: False positive**

Flagged calls are `EnumerableSet.add/remove` in internal single-item helpers (`RuleAddressSetInternal`, `RuleERC2980Internal`). The public single-item entrypoints already perform presence/absence pre-checks, making the boolean return redundant in the internal helpers.

---

## calls-loop (Low) — 16 instances

**Verdict: By design**

All instances stem from `RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(...)`, which must query each child whitelist rule to implement OR aggregation. The external calls in this loop are intrinsic to the wrapper design, and child rules are read-only.

---

## assembly (Informational) — 2 instances

**Verdict: By design**

- `RuleConditionalTransferLightApprovalBase._transferHash(...)` (`#L125-L134`)
- `RuleConditionalTransferLightMultiTokenBase._transferHash(...)` (`#L334-L348`)

Both use a small, memory-safe inline-assembly block to compute the transfer-tuple hash efficiently. Intentional and bounded. The second instance is new in `v0.4.0` (multi-token variant of the same pattern).

---

## naming-convention (Informational) — 2 instances

**Verdict: By design**

`_operator` naming in `RuleERC2980Base.whitelist/frozenlist` mirrors the ERC-2980 interface. Keeping spec-aligned argument names is intentional.

---

## unused-state (Informational) — 8 instances

**Verdict: False positive**

All instances are `RuleNFTAdapter` selector constants reported as unused in specific concrete contracts. They are part of inherited dispatch logic used across adapter paths; this is a per-contract inheritance-analysis limitation.

---

## Delta from v0.3.0

- **arbitrary-send-erc20**: 1 → **2** (new: `RuleConditionalTransferLightMultiTokenBase.approveAndTransferIfAllowed`, same guard chain).
- **assembly**: 1 → **2** (new: `RuleConditionalTransferLightMultiTokenBase._transferHash`, same memory-safe pattern).
- **unindexed-event-address** (2, Info, `lib/`): no longer reported — dependency paths excluded via `lib` filter.
- All other detectors and instance counts unchanged; all dispositions carried over.

## Executive triage

**Nothing to fix.** No finding is exploitable. The two High-severity `arbitrary-send-erc20` hits are false positives (authorized, approval-gated, allowance-checked compliance flow); everything else is by-design or a tool limitation.
