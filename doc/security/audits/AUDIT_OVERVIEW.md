# Audit & Security-Analysis Overview

> This is a security **overview** (analyses index + triage). It is **not** the vulnerability-reporting policy
> (that belongs in a root `SECURITY.md`).

**Current package version:** `v0.5.0`
**Scope:** production contracts under `src/` — mocks/tests (`src/mocks`, `test/`) and dependencies (`lib/`) are excluded from static-analysis runs unless a run is explicitly marked *mocks included*.

> ⚠️ This project has **not** undergone a formal third-party security audit. The analyses below are automated
> static analysis plus AI-assisted review, with the project team's triage.

## Analyses

| Date | Type | Tool / Source | Version | Reports |
|---|---|---|---|---|
| 2026-08-12 | AI-assisted review | Claude Code (Anthropic) | v0.5.0 | [**CLAUDE_ANALYSIS.md**](./tools/v0.5.0/CLAUDE_ANALYSIS.md) (code quality, `src/`) · [**CLAUDE_ANALYSIS_SCRIPT.md**](./tools/v0.5.0/CLAUDE_ANALYSIS_SCRIPT.md) (deployment scripts) |
| 2026-07 | AI-assisted review | Claude (Anthropic) + custom security-audit skills | v0.4.0 | [**CLAUDE_AUDIT.md**](./tools/v0.4.0/claude-audit/CLAUDE_AUDIT.md) |
| 2026-08-11 | Static analysis | Slither 0.11.5 | v0.5.0 | [report](./tools/v0.5.0/slither-report.md) · [feedback](./tools/v0.5.0/slither-report-feedback.md) |
| 2026-08-11 | Static analysis | Aderyn 0.6.5 | v0.5.0 | [report](./tools/v0.5.0/aderyn-report.md) · [feedback](./tools/v0.5.0/aderyn-report-feedback.md) |
| 2026-07-14 | Static analysis | Slither 0.11.5 | v0.4.0 | [report](./tools/v0.4.0/slither-report.md) · [feedback](./tools/v0.4.0/slither-report-feedback.md) |
| 2026-07-14 | Static analysis | Aderyn 0.6.5 | v0.4.0 | [report](./tools/v0.4.0/aderyn-report.md) · [feedback](./tools/v0.4.0/aderyn-report-feedback.md) |
| 2026-04-16 | Static analysis | Slither / Aderyn | v0.3.0 | [slither](./tools/v0.3.0/slither-report.md) · [aderyn](./tools/v0.3.0/aderyn-report.md) |
| 2026-03-16 | AI-assisted review | Wake Arena (Ackee) | v0.2.0 | [tools/v0.2.0](./tools/v0.2.0/) |

## Static-analysis results (v0.5.0)

Scope: production contracts only — mocks excluded (`-x mocks` / `mocks` filter) and vendored dependencies
excluded via the `lib` filter. Run 2026-08-11.

| Tool | High | Medium | Low | Info | Relevant to fix? |
|---|---|---|---|---|---|
| Slither 0.11.5 | 2 | 11 | 17 | 16 | **No** — all false-positive or by-design; see [feedback](./tools/v0.5.0/slither-report-feedback.md) |
| Aderyn 0.6.5 | 0 | 0 | 10 categories (333 instances) | 0 | **No** — all Low, by-design / environment / cosmetic; see [feedback](./tools/v0.5.0/aderyn-report-feedback.md) |

**Nothing to fix in `v0.5.0`.** Every delta from v0.4.0 traces to the three contracts added in this release
(`RuleChainlinkPoR`, `RuleReceiverWhitelist`, `IdentityRegistryWhitelist`) and each was verified against the
source before dismissal. The two new Slither categories are `uninitialized-local` (variables assigned inside a
`try` whose `catch` reverts or returns) and `timestamp` (the Proof-of-Reserve staleness comparison, which is the
feature itself).

Note for readers comparing runs: the Slither command must filter **`lib`**, not `submodules` — this is a Foundry
project, so a generic filter pulls the whole vendored dependency tree into scope and inflates the count roughly
four-fold with OpenZeppelin-internal findings.

The substantive issues fixed in this release — the guarded `totalSupply()` reads (codes 51 / 78), the live
feed-decimals read that prevents a stale-cache over-mint, and the removal of two inert public roles from
`IdentityRegistryWhitelist` — were found by **manual review, not by either tool**. A clean static-analysis report
means the tools' pattern sets matched nothing; it is not evidence of correctness.

## Static-analysis results (v0.4.0)

Both tools were **re-run on 2026-07-14**, after the security remediation landed. Counts below are from that run.

| Tool | High | Medium | Low | Info | Relevant to fix? |
|---|---|---|---|---|---|
| Slither 0.11.5 | 2 | 6 | 16 | 12 | **No** — all false-positive or by-design ([feedback](./tools/v0.4.0/slither-report-feedback.md)) |
| Aderyn 0.6.5 | 0 | 0 | 9 findings | 0 | **No** — all Low, by-design or false-positive ([feedback](./tools/v0.4.0/aderyn-report-feedback.md)) |

**Result: nothing to fix in `v0.4.0`.** The two High-severity Slither `arbitrary-send-erc20` hits are false positives — `approveAndTransferIfAllowed` (light + multi-token variants) is gated by `onlyTransferApprover`, a recorded approval, an allowance check, and a bound token. All other findings are accepted by design (centralization, unspecific pragma, PUSH0, template-method modifiers/empty blocks, `EnumerableSet` loop cost, spec-aligned naming) or tool limitations (`unused-return`/`unused-state`, per-contract analysis).

Slither's tally is **unchanged** from the pre-remediation run. Aderyn moved 8 → 10 Low, of which one was real and was fixed, leaving 9:

- **L-7 `Loop Contains require/revert` (new, 3 instances)** — batch adds now revert on `address(0)` instead of skipping it. Aderyn recommends "forgive on fail and continue", which is exactly the behaviour this release removed: a silent skip left the emitted `AddAddresses` event naming the sentinel as a set member when it was not. **The recommendation is deliberately rejected; do not act on it.**
- **`Unused Import` (2 instances) — found and FIXED during this run.** A dead `RuleTransferValidation` import in the two `RuleSpenderWhitelist` deployment files (pre-existing, not a regression). It was the only actionable item across both tools; both imports were removed, the build is clean, 511 tests pass, and a re-run confirms the finding is gone.

## AI-assisted review results (v0.4.0)

**0 Critical · 0 High · 0 Medium · 2 Low · 8 Informational** — plus 8 observations verified safe or accepted by design. Full detail, including invariant and access-control verification, in [`CLAUDE_AUDIT.md`](./tools/v0.4.0/claude-audit/CLAUDE_AUDIT.md).

| ID | Severity | Finding | Status |
|---|---|---|---|
| F-1 | **Low** | `RuleIdentityRegistry` over-screens vs ERC-3643: it verified sender, spender and minter, where the spec mandates the **receiver only**. Blocked issuance when the minter was unregistered, and **trapped de-listed holders** (they could neither receive nor send). | ✅ **Fixed** — conformant by default; stricter checks moved behind opt-in flags *(breaking)* |
| F-4 | **Low** | `RuleConditionalTransferLightMultiToken` keys approvals by `msg.sender`, not by `token`, so behind a `RuleEngine` no wiring delivers per-token isolation. | ⚠️ **Documented** — rule declared direct-binding-only; code unchanged (a true fix needs an upstream `RuleEngine` interface change) |
| F-2 | Info | Supply-cap restriction views panic on overflow instead of returning code `50`. | ✅ **Fixed** — overflow-safe views |
| F-3 | Info | `approveAndTransferIfAllowed` was inoperable behind a `RuleEngine` (`bindToken` conflated the ERC-20 target with the authorized caller). | ✅ **Fixed** — `bindRuleEngine` splits the two roles |
| F-5 | Info | The whitelist wrapper does not ERC-165-check its child rules. | ⚙️ **Partially fixed** — `IAddressList` now advertised; the wrapper guard remains open |
| F-7 | Info | `RuleMintAllowance.canTransfer` is hardcoded to "allowed" and disagrees with enforcement. | ⚠️ **By design** — documented as non-authoritative |
| F-8 | Info | Multi-token `detectTransferRestriction` depends on `msg.sender`, so third-party pre-flight always reads "not approved". | ✅ **Fixed** — caller-explicit `…ForToken` views |
| F-9 | Info | `unbindToken` leaves stale approvals / mint quota. | ✅ **Mitigated** — `resetApproval` / `clearMintAllowances` added |
| F-10, F-14 | Info | Multi-token doc contradicted itself on approval scoping; project guide stale. | ✅ **Fixed** (documentation) |

Additionally, **two standards-conformance defects were fixed** that were not in the original finding list: enabling mint/burn by whitelisting `address(0)` made `isVerified(address(0))` (ERC-3643) and `whitelist(address(0))` (a **mandatory** ERC-2980 getter) return `true`. Mint/burn permission is now an explicit `allowMint` / `allowBurn` flag and the zero address can never enter a list *(breaking)*.

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
