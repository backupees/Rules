# Audit & Security-Analysis Overview

> This is a security **overview** (analyses index + triage). It is **not** the vulnerability-reporting policy
> (that belongs in a root `SECURITY.md`).

**Current package version:** `v0.4.0`
**Scope:** production contracts under `src/` — mocks/tests (`src/mocks`, `test/`) and dependencies (`lib/`) are excluded from static-analysis runs unless a run is explicitly marked *mocks included*.

> ⚠️ This project has **not** undergone a formal third-party security audit. The analyses below are automated
> static analysis plus AI-assisted review, with the project team's triage.

## Analyses

| Date | Type | Tool / Source | Version | Reports |
|---|---|---|---|---|
| 2026-07-08 | Static analysis | Slither 0.11.5 | v0.4.0 | [report](./tools/v0.4.0/slither-report.md) · [feedback](./tools/v0.4.0/slither-report-feedback.md) |
| 2026-07-08 | Static analysis | Aderyn 0.6.5 | v0.4.0 | [report](./tools/v0.4.0/aderyn-report.md) · [feedback](./tools/v0.4.0/aderyn-report-feedback.md) |
| 2026-04-16 | Static analysis | Slither / Aderyn | v0.3.0 | [slither](./tools/v0.3.0/slither-report.md) · [aderyn](./tools/v0.3.0/aderyn-report.md) |
| 2026-03-16 | AI-assisted review | Wake Arena (Ackee) | v0.2.0 | [tools/v0.2.0](./tools/v0.2.0/) |

## Static-analysis results (v0.4.0)

| Tool | High | Medium | Low | Info | Relevant to fix? |
|---|---|---|---|---|---|
| Slither 0.11.5 | 2 | 6 | 16 | 12 | **No** — all false-positive or by-design ([feedback](./tools/v0.4.0/slither-report-feedback.md)) |
| Aderyn 0.6.5 | 0 | 0 | 8 findings | 0 | **No** — all Low, by-design or false-positive ([feedback](./tools/v0.4.0/aderyn-report-feedback.md)) |

**Result: nothing to fix in `v0.4.0`.** The two High-severity Slither `arbitrary-send-erc20` hits are false positives — `approveAndTransferIfAllowed` (light + multi-token variants) is gated by `onlyTransferApprover`, a recorded approval, an allowance check, and a bound token. All other findings are accepted by design (centralization, unspecific pragma, PUSH0, template-method modifiers/empty blocks, `EnumerableSet` loop cost, spec-aligned naming) or tool limitations (`unused-return`/`unused-state`, per-contract analysis). Instance counts rose vs `v0.3.0` only because `v0.4.0` adds the `RuleMintAllowance` and `RuleConditionalTransferLightMultiToken` families; no new category appeared.

## Substantive findings that were fixed (AI / manual review)

From the Wake Arena AI review (v0.2.0) and internal `RuleMintAllowance` review:

| Source | ID | Finding | Resolution |
|---|---|---|---|
| Wake Arena | H-1 | ConditionalTransferLight approvals not scoped by token | **Fixed** — single-token binding enforced in `bindToken`; `RuleConditionalTransferLight_TokenAlreadyBound` added. |
| Wake Arena | M-1 | Incomplete `supportsInterface` breaks ERC-165 discovery | **Fixed** — pre-computed interface IDs + `IERC7551Compliance`; full ERC-3643 `ICompliance` ID (`0x3144991c`) handled. |
| Wake Arena | I-1 | RuleERC2980 docs omit frozen spender on `transferFrom` | **Fixed (doc)** — README / AGENTS / CLAUDE updated. |
| Wake Arena | I-2 | `hasRole` admin implicitly passes all role checks | **Fixed (doc)** — documented intentional design + off-chain monitoring guidance. |
| Internal review | — | `RuleMintAllowance` allowance shared across bindings | **Fixed** — single-target binding enforced (`RuleMintAllowance_TokenAlreadyBound`). |
| Internal review | — | `SanctionListOracle` mock `removeFromSanctionsList` set `true` instead of `false` | **Fixed** — corrected to un-sanction; regression test added (mock/test-only). |

See the per-version report directories under [`tools/`](./tools/) for the full outputs and triage.
