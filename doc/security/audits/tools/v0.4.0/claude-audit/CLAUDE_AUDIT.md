# Claude Security Audit — CMTA Rules `v0.4.0`

| | |
|---|---|
| **Tool** | Claude (Anthropic), driven by a set of custom smart-contract security-audit skills |
| **Codebase audited** | CMTA Rules `v0.4.0` — production contracts under `src/` |
| **Severity framework** | Code4rena (Critical / High / Medium / Low / Info) |
| **Method** | Threat model → privileged-surface enumeration → targeted manual review → executable proofs-of-concept → adversarial self-review of every finding |
| **Date** | 2026-07 |

**Method note.** The review was driven by a set of internal, task-specific security-audit skills covering the
CMTAT/ERC-3643 compliance model, access control, arithmetic, state and replay analysis, oracle handling, and
EIP-conformance checking. Every candidate finding was then put through an adversarial pass whose explicit job was to
*dismiss or downgrade* it; several were downgraded as a result, and those adjustments are recorded on the findings
below. **The specific internal skills used are intentionally not enumerated here.**

External tooling used alongside the manual review: **Foundry** (`forge test`, `forge coverage`) and **Slither**
printers (call-graph / inheritance / function-summary) as a comprehension aid only — no static-analysis output was
promoted to a finding without independent manual verification.

---

## 1. Scope

**In scope:** all production contracts under `src/` — 11 rules (each in an `AccessControl` and an `Ownable2Step`
variant), the shared abstract bases, and the reusable modules.

**Out of scope:** `lib/` (CMTAT, RuleEngine, OpenZeppelin) and `src/mocks/`. Dependencies are treated as trusted,
but their call contracts are load-bearing and are cited wherever they determine in-scope behaviour — in particular
`CMTAT._mintOverride`, which passes the **minter as `spender`** on every mint, and `RuleEngineBase.transferred`,
which makes the *engine* (not the token) the `msg.sender` inside a rule. Several findings hinge on exactly these two
facts.

---

## 2. Executive summary

**No Critical or High severity issue was found.**

| Severity | Count |
|---|---|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| **Low** | **2** |
| **Info** | **8** |
| Verified-safe / by-design dispositions | 8 |

The two Low findings are both cases of a rule quietly behaving differently from its siblings, or from its own
documentation — not exploitable by an untrusted party, but capable of causing a real operational failure.

### Hypotheses that were checked and found NOT to hold

Two threats were specifically probed **because they would have been High**. Neither exists. They are stated
explicitly, because an unmentioned risk reads as one that was never considered:

| Hypothesis | Would have been | Result |
|---|---|---|
| An ERC-2771 trusted forwarder can impersonate a bound token and forge/consume approvals | **High** | ❌ **Does not exist.** The three rules that use `_msgSender()` as a *binding identity* (`RuleConditionalTransferLight`, `…MultiToken`, `RuleMintAllowance`) deliberately do **not** inherit `ERC2771Context`. The six rules that *do* inherit it never treat `_msgSender()` as a token or participant identity — `from`/`to`/`spender` are always explicit parameters. The two contract families are disjoint. |
| The hand-rolled keccak assembly in `_transferHash` collides, letting one approval be spent on a different transfer | **High** | ❌ **Does not exist.** Each address is left-aligned into its own 32-byte word (`shl(96, addr)`) and `value` occupies a full word, so the preimage is injective. The `memory-safe` annotation is valid. Confirmed by a 256-run fuzz test over distinct tuples. |

---

## 3. Findings

### 3.1 Summary

| ID | Finding | Severity | Status | Component | PoC |
|---|---|---|---|---|---|
| **F-1** | `RuleIdentityRegistry` over-screens vs ERC-3643 (screens sender + spender + minter; spec mandates **receiver only**) | Low | ✅ **Fixed** | `RuleIdentityRegistryBase.sol` | `test_IR1_MintSucceedsWhenMinterNotVerified`, `test_IR1_DelistedHolderCanStillExit` |
| **F-4** | `…MultiToken` approvals keyed by `msg.sender`, not `token` — no per-token isolation behind a RuleEngine | Low | ⚠️ **Documented** (behaviour unchanged) | `RuleConditionalTransferLightMultiTokenBase.sol` | `test_CTL2_MultiTokenApprovalKeyMismatchLeavesStaleApproval_CurrentBehaviour` |
| F-2 | Supply-cap restriction views panic on overflow instead of returning code `50` | Info | ✅ **Fixed** | `RuleMaxTotalSupplyBase.sol` | `test_MTS1_DetectTransferRestrictionReturnsCodeOnOverflow` |
| F-3 | `approveAndTransferIfAllowed` inoperable behind a RuleEngine | Info | ✅ **Fixed** | `RuleConditionalTransferLightBase.sol` | `test_CTL1_ApproveAndTransferIfAllowedWorksOnceEngineIsBound` |
| F-5 | Wrapper does not ERC-165-check its child rules | Info | ⚙️ **Partially fixed** (prerequisite shipped) | `RuleWhitelistWrapperBase.sol` | `test_WW2_NonAddressListChildRuleBricksWrapper_CurrentBehaviour` |
| F-7 | `RuleMintAllowance` eligibility views hardcoded to "allowed" | Info | ⚠️ **Documented** (by design) | `RuleMintAllowanceBase.sol` | `test_MA1_HardcodedEligibilityViewsDisagreeWithEnforcement_CurrentBehaviour` |
| F-8 | `…MultiToken.detectTransferRestriction` depends on `msg.sender` | Info | ✅ **Fixed** | `RuleConditionalTransferLightMultiTokenBase.sol` | `test_CTL2_DetectTransferRestrictionIsMsgSenderDependent_CurrentBehaviour` |
| F-9 | `unbindToken` leaves stale approvals / mint quota | Info | ✅ **Mitigated** | `RuleMintAllowanceBase.sol` | `test_BIND1_MintAllowanceSurvivesRebind_CurrentBehaviour` |
| F-10 | Multi-token documentation contradicted itself on approval scoping | Info | ✅ **Fixed** (doc) | `doc/technical/…MultiToken.md` | ✗ |
| F-14 | Project guide stale (version string, missing rules, missing code `70`) | Info | ✅ **Fixed** (doc) | `CLAUDE.md` / `AGENTS.md` | ✗ |
| F-6 | Wrapper cross-rule OR (`from` in child A, `to` in child B) | — | **NOT-A-FINDING** — documented design (OR semantics) | `RuleWhitelistWrapperBase.sol` | `test_WW1_CrossRuleOrAllowsTransferNoSingleChildAllows` |
| F-11 | ERC-2771 forwarder cannot impersonate a bound token | — | **NOT-A-FINDING** — verified safe | `src/rules/operation/*` | ✗ |
| F-12 | `_transferHash` assembly is injective and memory-safe | — | **NOT-A-FINDING** — verified safe | `…ApprovalBase.sol` | `testFuzz_HASH1_ApprovalBucketsAreDistinct` |
| F-13 | Sanctions screening fails open when the oracle is unset | — | **NOT-A-FINDING** — by design (mirrors `clearIdentityRegistry`) | `RuleSanctionsListBase.sol` | ✗ |
| F-15 | Blacklist screens the minter (no mint carve-out) | — | **NOT-A-FINDING** — correct for a deny-list | `RuleBlacklistBase.sol` | ✗ |
| F-16 | ERC-2980: only `to` must be whitelisted; frozen `from` cannot burn | — | **NOT-A-FINDING** — spec-conformant | `RuleERC2980Base.sol` | ✗ |
| F-17 | `RuleNFTAdapter.transferred(ctx)` unguarded on validation rules | — | **NOT-A-FINDING** — view-only, mutates nothing | `RuleNFTAdapter.sol` | `test_AC5_ContextEntrypointsAreUnguardedButViewOnly` |
| F-18 | CEI inversion in `approveAndTransferIfAllowed` | — | **NOT-A-FINDING** — no exploitable reentrancy | `RuleConditionalTransferLightBase.sol` | ✗ |

**Tally: 0 Critical, 0 High, 0 Medium, 2 Low, 8 Info; 8 dispositions verified safe or by-design.**

---

### 3.2 F-1 — `RuleIdentityRegistry` over-screens relative to ERC-3643 (Low) ✅ Fixed

**Severity:** Low *(adversarial pass downgraded this from an initially-proposed Medium: the behaviour is
fail-closed — no unverified party gains any capability — which caps the severity. Accepted.)*

ERC-3643 mandates exactly **one** identity check:

> *"The **receiver** MUST be whitelisted on the Identity Registry and verified"* … *"`transferFrom` **works the
> same way**"* … *"`mint` and `forcedTransfer` **only require the receiver** to be whitelisted and verified"* …
> *"The `burn` function **bypasses all checks** on eligibility."*

The rule screened **three** parties the specification does not require: the **sender**, the **spender**, and — via
the CMTAT v3.3 convention that passes the minter as `spender` — the **minter**.

**Impact.**

1. **Issuance halts silently.** An issuer who registers all investors but not their own operational minter EOA finds
   *every mint reverting* with `CODE_ADDRESS_SPENDER_NOT_VERIFIED` (57) — a code naming a "spender" on a call that
   has no spender. Nothing points at the minter.
2. **De-listed holders were trapped — the more damaging deviation, and one not present in the original finding.**
   ERC-3643 screens only the receiver *precisely so that* an investor whose identity lapses (expired claim, revoked
   identity) can still **exit their position** by sending to a verified counterparty. Screening the sender meant such
   a holder could neither receive **nor** send: their tokens were frozen in place with no path out.

**Resolution.** The rule is now conformant by default — only the receiver is verified; a mint checks only the
receiver; a burn bypasses everything. The stricter checks are preserved behind **explicit opt-in flags**
(`checkSender`, `checkSpender`, both defaulting to `false`); mint and burn stay exempt from the spender check even
when `checkSpender` is enabled. F-1 is fixed as a *consequence of conformance* rather than as an ad-hoc patch.
**Breaking** — see Remediation.

---

### 3.3 F-4 — Multi-token approvals are keyed by `msg.sender`, not by `token` (Low) ⚠️ Documented

The rule's entire premise is per-token approval scoping. Approvals are **written** under a caller-supplied `token`
(`_approveTransfer` → `_transferHash(token, …)`) but **consumed** under `msg.sender`
(`transferred` → `_transferred(_msgSender(), …)`). The two keys agree only when the caller *is* the token.

Behind a `RuleEngine` — the topology the README presents as the default — `msg.sender` is the **engine**, and an
exhaustive case analysis shows **no wiring in which the rule delivers its purpose**:

| Wiring | Outcome |
|---|---|
| Nothing bound | Every transfer reverts (engine unauthorized) |
| Bind the **token** (the natural reading of "MultiToken") | Every transfer reverts — the token never calls the rule; the engine does |
| Bind the engine, approve with the **token** address | Cannot even record the approval |
| Bind **both**, approve with the token address | Approval written under `H(token,…)`, consumed under `H(engine,…)` → reverts, and the approval is **stranded in storage permanently** |
| Bind the engine, approve with the **engine** address | The only configuration that runs — and approvals become **shared across every token behind that engine**, i.e. exactly the cross-token reuse the rule exists to prevent |

**Impact.** In the only functioning configuration, an approval recorded for `(alice → bob, 100)` intending token A is
equally consumable on token B. Requires the multi-tenant topology, colliding `(from, to, value)` tuples, and a
trusted `OPERATOR_ROLE` — hence Low, not Medium.

**Resolution: documented, behaviour unchanged.** The rule is now declared **direct-binding-only**; the technical doc
carries the full case table and an explicit *"Do not add this rule to a `RuleEngine`"*. Supporting true per-token
scoping behind an engine would require the token address to be threaded into `IRuleEngine.transferred(...)` — an
**upstream RuleEngine interface change**, not fixable in this repository. An optional `bindToken` guard that would
make the constraint *enforced* rather than documented remains open (see Potential Improvements).

*Note:* F-10 (the technical doc simultaneously claiming "Approvals of one token cannot be spent by another" and
admitting the opposite nine lines later) was the most likely cause of real harm here, and is fixed.

---

### 3.4 Info findings (condensed)

| ID | Finding | Impact | Resolution |
|---|---|---|---|
| **F-2** | `currentSupply + value` overflows in `RuleMaxTotalSupply`'s restriction views, producing `Panic(0x11)` instead of code `50`. These are ERC-1404/ERC-3643 views that must **never** revert. | View-purity/conformance defect. Fail-closed either way (enforcement reverts on the same input), so no bypass. *Adversarial pass downgraded Low → Info: only reachable at `value ≈ 2²⁵⁶`, which cannot correspond to a real mint.* | ✅ Fixed — overflow-safe headroom comparison |
| **F-3** | `approveAndTransferIfAllowed` was structurally impossible behind a RuleEngine: `bindToken` had **one slot serving two roles** — the ERC-20 target (`getTokenBound()`) *and* the authorized caller (`isTokenBound(msg.sender)`). In direct mode they coincide; behind an engine they diverge, and both choices fail. | Binding the engine broke the helper (an engine is not an ERC-20); binding the token left the engine unauthorized and **reverted every transfer and mint**. | ✅ Fixed — the two roles decoupled |
| **F-5** | The wrapper calls `IAddressList(child).areAddressesListed(...)` but, unlike `RuleEngineBase._checkRule`, never verifies the child implements `IAddressList`. A valid-but-wrong `IRule` bricks the scan. | Requires the trusted `RULES_MANAGEMENT_ROLE`; fail-closed; breakage is *input-dependent* (the scan short-circuits once every address is resolved, so some pairs keep working). | ⚙️ Prerequisite shipped (ERC-165 advertisement); the guard itself is open |
| **F-7** | `RuleMintAllowance.canTransfer` / `detectTransferRestriction` are hardcoded to "allowed" — the 3-arg signature carries no minter identity — so the standardized view disagrees with enforcement. | An integrator gating on `canTransfer` is misled. | ⚠️ By design; **documented** where integrators look |
| **F-8** | `…MultiToken.detectTransferRestriction` derives the token from `msg.sender`, so an off-chain `eth_call` from a wallet/explorer always reads "not approved" even for an approved transfer. | Fail-closed, but carries no signal for third-party pre-flight. | ✅ Fixed — caller-explicit views added |
| **F-9** | `unbindToken` clears neither `approvalCounts` nor `mintAllowance`; rebinding makes stale state consumable. The conditional-transfer rule warned about this; the mint-allowance rule did not. | Trusted-role only. | ✅ Mitigated — explicit clearing functions + the missing warning |
| **F-10** | Multi-token doc asserted "Approvals of one token cannot be spent by another" nine lines above a Notes section admitting the opposite. | An integrator reading the first sentence deploys into the broken topology. | ✅ Fixed (doc) |
| **F-14** | Project guide stated version `0.2.0` (code returns `0.4.0`), omitted two rule families and restriction code `70`. | Docs only. | ✅ Fixed (doc) |

---

## 4. Invariant Verification

Every invariant defined in the threat model, with the **test that establishes it**. An invariant asserted without
evidence is an opinion.

| # | Property | Holds? | Evidence |
|---|---|---|---|
| `INV-1` | `canTransfer* == (detectTransferRestriction* == 0)` | ✅ | Each rule derives one from the other; verified by inspection across all 11 rules |
| `INV-2` | `transferred` reverts **iff** `detectTransferRestriction*` is non-zero | ⚠️ **Fails for `RuleMintAllowance`** — by design | `test_MA1_HardcodedEligibilityViewsDisagreeWithEnforcement_CurrentBehaviour` → **F-7**; the 3-arg view cannot see the minter |
| `INV-3` | Restriction views never revert | ✅ **(after the F-2 fix)** | Previously failed. Now regression-guarded by `testFuzz_MTS1_DetectRestrictionNeverReverts` over the **full `uint256` domain** |
| `INV-4` | Only the bound entity may call the stateful `transferred` / `created` / `destroyed` | ✅ | `test_CTL1_UnboundCallerCannotConsumeApproval`; `onlyBoundToken` / `onlyTransferExecutor` on every stateful hook |
| `INV-5` | `approvalCounts` never underflows; one approval ⇒ one transfer | ✅ **(stateful)** | `invariant_approvalConservation`, `invariant_noApprovalExceedsTotalRecorded` — **8 192 calls, 0 reverts**, `fail_on_revert = true`. **Mutation-verified**: removing the decrement makes it fail |
| `INV-6` | `_transferHash` is injective | ✅ | `testFuzz_HASH1_ApprovalBucketsAreDistinct` (256 runs) → **F-12** |
| `INV-7` | `mintAllowance` non-increasing across mints, never underflows, `Σ minted ≤ Σ granted` | ✅ **(stateful)** | `invariant_allowanceMatchesGhost` (independent ghost mirror), `invariant_mintedNeverExceedsCredited` — **8 192 calls, 0 reverts**. **Mutation-verified**: an off-by-one in the quota deduction makes it fail |
| `INV-8` | Batch ops never revert on duplicates; single-item ops always do | ✅ | `RuleWhitelistAdd.t.sol`, `RuleWhitelistRemove.t.sol`, `RuleERC2980.t.sol`. *(The one input a batch does not skip is `address(0)` — it reverts, so the emitted event can never report a member that is not in the set.)* |
| `INV-9` | Every emitted code satisfies `canReturnTransferRestrictionCode` and has a message | ✅ | Per-rule unit tests |
| `INV-10` | `_msgSender()` is never used as a binding identity in an `ERC2771Context` rule | ✅ | **F-11** — the two contract families are disjoint. *Held by static reasoning only; a live regression harness is the top open item* |
| `INV-11` | Every `_authorize*` hook bound to a concrete role in every deployment variant | ✅ | All 20 deployment contracts reviewed; all 40 overrides retain their `onlyRole(...)` / `onlyOwner` modifier |
| `INV-12` | Mint/burn handled explicitly by every rule | ✅ **(after the F-1 fix)** | Previously failed on the spender leg of `RuleIdentityRegistry` |

**Two invariants (`INV-5`, `INV-7`) are now established by a stateful fuzzing suite rather than by fixed-sequence
unit tests**, and both were **mutation-tested** — a real bug was injected, the suite was confirmed to fail, and the
mutation reverted. That is the difference between "we think this holds" and "we tried hard to break it".

---

## 5. Access-Control Verification

| Rule | Privileged entrypoint | Expected guard | Verified |
|---|---|---|---|
| all address-set rules | `addAddress(es)` / `removeAddress(es)` | `ADDRESS_LIST_ADD_ROLE` / `ADDRESS_LIST_REMOVE_ROLE` / `onlyOwner` | ✅ |
| whitelist family | `setCheckSpender`, `setAllowMint`, `setAllowBurn` | `DEFAULT_ADMIN_ROLE` / `onlyOwner` | ✅ |
| `RuleSanctionsList` | `setSanctionListOracle`, `clearSanctionListOracle` | `SANCTIONLIST_ROLE` / `onlyOwner` | ✅ |
| `RuleMaxTotalSupply` | `setMaxTotalSupply`, `setTokenContract` | `DEFAULT_ADMIN_ROLE` / `onlyOwner` | ✅ |
| `RuleIdentityRegistry` | `setIdentityRegistry`, `clearIdentityRegistry`, `setCheckSender`, `setCheckSpender` | `DEFAULT_ADMIN_ROLE` / `onlyOwner` | ✅ |
| `RuleERC2980` | 8 list-management functions + `setAllowMint` / `setAllowBurn` | 4 dedicated roles / `DEFAULT_ADMIN_ROLE` / `onlyOwner` | ✅ |
| `RuleWhitelistWrapper` | `addRule`, `removeRule`, `setRules`, `clearRules`, `setMaxRules` | `RULES_MANAGEMENT_ROLE` / `onlyOwner` | ✅ |
| `RuleConditionalTransferLight*` | `approveTransfer`, `cancelTransferApproval`, `resetApproval`, `approveAndTransferIfAllowed` | `OPERATOR_ROLE` / `onlyOwner` | ✅ |
| `RuleConditionalTransferLight*` | `transferred`, `created`, `destroyed` | **bound entity only** | ✅ `test_CTL1_UnboundCallerCannotConsumeApproval` |
| `RuleMintAllowance` | `setMintAllowance`, `increase…`, `decrease…`, `clearMintAllowances` | `ALLOWANCE_OPERATOR_ROLE` / `onlyOwner` | ✅ |
| `RuleMintAllowance` | `transferred`, `created`, `destroyed` | **bound entity only** (`onlyBoundToken`) | ✅ |
| all operation rules | `bindToken`, `unbindToken`, `bindRuleEngine`, `unbindRuleEngine` | `COMPLIANCE_MANAGER_ROLE` / `onlyOwner` | ✅ |
| `RuleNFTAdapter` | `transferred(ctx)` overloads | *(none, on validation rules)* | ✅ **Acceptable** — the hooks are `view`: an arbitrary caller can run the check and be reverted by it, but cannot mutate state (**F-17**, pinned by `test_AC5_ContextEntrypointsAreUnguardedButViewOnly`) |

**No unbound authorization hook, no missing guard, and no selector reachable by an unintended role.**

**Negative results verified:** an arbitrary caller cannot consume an approval, cannot toggle any rule flag, cannot
mint past a quota, and cannot bind or unbind anything. A `RULES_MANAGEMENT_ROLE` holder cannot approve transfers; an
`OPERATOR_ROLE` holder cannot rebind the token.

**Centralization premise (stated plainly, not a finding).** `AccessControlModuleStandalone.hasRole` grants the
**default admin every role by construction**. Role separation is therefore *advisory* against a compromised admin —
it limits blast radius between honest operators, not against the admin itself. This is inherent to a
regulated-issuer compliance model, in which an issuer must retain ultimate control, and is a deliberate design
choice rather than a defect. It is called out so no reader mistakes the role table for a security boundary it does
not provide.

Additionally, all 40 access-control hooks are now `internal view virtual` — making *"authorization never mutates
state"* a **compiler-enforced invariant** rather than a convention. One documented exception remains, structurally
blocked by an upstream (`lib/`) declaration.

---

## 6. Remediation — what was implemented

Verified against `git log`, `CHANGELOG.md` and the test suite — **not** against the recommendation text. A finding
whose recommendation was written is not a finding that was fixed.

### 6.1 Code fixes

| Finding | Status | What actually changed in the code | Verified by |
|---|---|---|---|
| **F-1** | ✅ **Fixed** *(breaking)* | `RuleIdentityRegistry` made ERC-3643 conformant: **only the receiver** is verified. The sender/spender/minter checks moved behind opt-in `checkSender` / `checkSpender` flags (constructor params + setters), both defaulting to `false`. Mint/burn stay exempt from the spender check even when opted in. | **3 PoCs inverted into regression tests** + 10 new tests. `test_IR1_DelistedHolderCanStillExit` pins the exit path that was previously blocked. |
| **F-2** | ✅ **Fixed** | Supply-cap views compare against remaining headroom (`value > maxTotalSupply - currentSupply`) instead of doing a checked addition that panics. Enforcement path unchanged. | **PoC inverted**: `test_MTS1_DetectTransferRestrictionReturnsCodeOnOverflow`. The pre-existing fuzz test was widened to the **full `uint256` domain** — it had been bounded to *avoid* the overflow region, i.e. shaped so it could never find the bug. |
| **F-3** | ✅ **Fixed** | `bindToken`'s two conflated roles were **decoupled**: `bindToken(token)` designates the ERC-20 target; new `bindRuleEngine(engine)` authorizes the engine to call `transferred`. Execution accepts **either** (`isTransferExecutor`). The helper now works in both topologies. Backward compatible. | 9 new tests. `test_CTL1_UnsupportedWiringsStillFail` proves the engine is *rejected* until bound, so the new binding is load-bearing, not cosmetic. |
| **F-8** | ✅ **Fixed** | Added caller-explicit `detectTransferRestrictionForToken` / `canTransferForToken`. The standardized ERC-1404 signatures are unchanged (the token cannot be threaded into them without breaking the standard) but both paths are backed by **one internal helper**, so they are structurally incapable of disagreeing. | 7 new tests, incl. `testFuzz_ViewsAgreeForTheBoundToken` — the regression guard that matters if someone later edits one path. |
| **F-9** | ✅ **Mitigated** | Added `resetApproval(...)` (single- and multi-token) and `clearMintAllowances(address[])`, plus the stale-state warning that was missing from `RuleMintAllowance.bindToken`. The reset functions **deliberately do not require a bound token** — cleaning up *after* `unbindToken` is their entire purpose, and a bound-token check would have made the stale state permanently unclearable. | 9 new tests. Default behaviour is unchanged: state still survives unbind unless explicitly cleared. This adds the tool, not a change to the trust model. |
| **F-5** | ⚙️ **Partially fixed** | **Step 1 shipped:** the six address-set rules now advertise `IAddressList` via ERC-165 (`0x5d10e182`). *Note:* `type(IAddressList).interfaceId` **cannot** be used — it silently omits `contains(address)`, inherited from `IIdentityRegistryContains`, so the wrapper's future check would have looked for an ID no conforming contract could match. A pre-computed constant derived from a flattened interface is used instead. **Step 2 (the wrapper's `_checkRule` guard) is open.** | 7 tests, incl. a regression guard proving the naive interface ID is *wrong* and differs from the correct one by exactly the `contains` selector. |

### 6.2 Conformance fix beyond the findings

An additional **breaking** conformance defect was found and fixed while remediating F-1 — it was not in the original
finding list, and it violated **two** standards at once:

| Issue | Fix |
|---|---|
| `RuleWhitelist`, `RuleWhitelistWrapper` and `RuleERC2980` enabled mint/burn by **whitelisting `address(0)`**. That made standardized getters assert falsehoods: `isVerified(address(0))` returned `true` (ERC-3643 defines `isVerified` as *"is this wallet a valid investor holding the required claims"* — the zero address is not a wallet), and `RuleERC2980.whitelist(address(0))` returned `true` — a **mandatory** ERC-2980 getter. It also meant `removeAddress(address(0))` **silently disabled all minting and burning**. | Mint/burn permission is now an **explicit `allowMint` / `allowBurn` flag** (set together by the `allowMintBurn` constructor parameter, independently settable at runtime so issuance can still be permanently closed while redemptions stay open). The zero address can **never** enter any list. New dedicated restriction codes (`24`/`25`, `64`/`65`) — a blocked mint now says *"minting is not allowed"* instead of the misleading *"sender is not whitelisted"*. Verified: with mint/burn **enabled**, `isVerified(0)`, `contains(0)`, `whitelist(0)` and `frozenlist(0)` are **all `false`**. |

### 6.3 Documentation-only (behaviour unchanged — stated so it does not read as a code fix)

| Finding | What changed |
|---|---|
| **F-4** | `…MultiToken` declared **direct-binding-only**, with the exhaustive case table showing why no RuleEngine wiring works. **The code is unchanged.** |
| **F-7** | `RuleMintAllowance.canTransfer` documented as **not authoritative**, with an eligibility-views table directing integrators to `canTransferFrom`. Behaviour is intentional and unchanged. |
| **F-10**, **F-14** | Contradictory multi-token doc corrected; project guide refreshed (version, missing rules, missing restriction code). |
| — | New `RULE_SEMANTICS.md`: a per-rule comparison table (who each rule screens on `from`/`to`/spender/mint/burn, unset-oracle behaviour, stateful?, authoritative view). This directly de-risks the recurring theme behind several findings — rules answering the same question with different conventions, previously discoverable only by reading source. |

### 6.4 Deliberately declined

| Item | Reason |
|---|---|
| Hard-cap the wrapper's child-rule count below the existing `maxRules = 10` | **Declined: the child-list size is the operator's responsibility.** `maxRules` already bounds it, the cost is now documented, and a lower hard ceiling would remove legitimate configurations to protect a privileged actor from mis-configuring their own deployment. Documented instead: the scan costs ~8.8k gas per child, is **linear** (measured flat to 200 children), and runs on the *transfer* path — so it is a permanent per-holder tax, **not** a liveness risk (a transfer would not fail to fit in a block until ~3 400 children). |
| A runtime `_looksLikeToken` probe on the approval/transfer hot path | **Declined on gas/complexity grounds.** It would add a call to the token on every operation to guard a misconfiguration a trusted operator already controls. (The same check placed *only* in `bindToken` — a one-time admin call, zero hot-path cost — remains an open option; see below.) |

### 6.5 Breaking changes and deployer migration

Two breaking changes landed. Both require action before upgrading:

1. **`RuleIdentityRegistry` constructor** → `(admin, identityRegistry, checkSender, checkSpender)`. Pass
   `false, false` for the ERC-3643-conformant default. A deployment relying on the old stricter behaviour must pass
   `true, true`. **The default screening loosens** — no restriction codes changed.
2. **Mint/burn flags.** `RuleWhitelist`'s constructor keeps its shape (`allowMintBurn` now sets flags instead of
   whitelisting `address(0)`); `RuleWhitelistWrapper` gains an `allowMintBurn` parameter; `RuleERC2980`'s third
   parameter is renamed `allowBurn` → `allowMintBurn`. A deployment that enabled mint/burn by whitelisting
   `address(0)` must instead pass `allowMintBurn = true`. **Removed capability:** blacklisting `address(0)` as an
   undocumented "halt all issuance" kill switch is no longer possible — halt issuance at the token (CMTAT
   pause/deactivate) instead.

**A version bump is required** before release: the package still reports `0.4.0`, while three constructors changed
arity and four restriction codes were added.

### 6.6 Test and coverage impact

| | Before | After |
|---|---|---|
| Tests | 407 | **511** |
| Production line coverage | 94.9% | **97.8%** (1 082 / 1 106) |
| Branch coverage | not measured | **97.3%** (220 / 226) |
| Stateful invariant tests | **0** | 4 (mutation-verified) |
| Fuzz tests | 3 | 10 |

**Every reachable line of production code is now covered.** The 24 uncovered lines are, without exception, abstract
declarations with no body (`_transferred`, `_detectTransferRestriction`, the `_authorize*` hooks), overridden by
every concrete rule — uncoverable by definition, and no test can move the number.

That claim is stated precisely because an earlier draft of this report asserted it *without* checking. A
line-by-line audit of the LCOV output found **5 genuinely reachable lines that no test executed**, all of them
introduced by the remediation itself:

- the four `messageForTransferRestriction` returns for the newly-added mint/burn codes (`24`/`25` on the whitelist
  family, `64`/`65` on ERC-2980) — a rejected mint would have reported the right *code* while the message lookup
  for it was never exercised, which is precisely the opaque failure the dedicated codes existed to remove;
- the wrapper's degenerate `from == 0 && to == 0` branch, added during review specifically to stop
  `RuleWhitelistWrapper` drifting from `RuleWhitelistBase` — an anti-drift guard that nothing checked.

All five are now covered (5 new tests). The lesson is worth recording: a *percentage* moving in the right direction
concealed a real gap, because the denominator grew at the same time. The check that mattered was enumerating the
uncovered lines and reading them, not watching the headline number.

---

## 7. Potential Improvements (open backlog)

**These are hardening and quality items, not vulnerabilities.** They are kept separate from the findings on purpose:
conflating them would inflate the apparent risk of the codebase.

| # | Improvement | Addresses | Effort | Breaking? | Priority |
|---|---|---|---|---|---|
| 1 | **ERC-2771 relay harness** — relay a call through a real forwarder and assert `_msgSender()` resolves to the signer; add a guard test proving the operation rules are *not* ERC-2771 contexts | `INV-10` / F-11 | M | No (tests) | **P1** |
| 2 | **Wrapper child-rule ERC-165 guard** — override `_checkRule` to require `IAddressList` | F-5 (step 2) | S | Yes (`addRule` starts reverting for non-conforming children) | **P1** |
| 3 | **Enforce direct-binding-only on `…MultiToken`** — reject binding a non-token in `bindToken` | F-4 | S | Yes | **Decision** |
| 4 | **Hostile-dependency tests** — reverting/misbehaving sanctions oracle and identity registry | `EXT-1`, `EXT-2` | S | No (tests) | P2 |
| 5 | **Wrapper gas snapshot** — commit a benchmark at 1/5/10 children so a scan-cost regression surfaces as a diff | `WW-4` | S | No | P3 |
| 6 | **Upstream: `internal view virtual` for the four `lib/RuleEngine` access-control hooks** | `INV-11` hardening | S | Upstream | **Blocked** |

**Rationale.**

1. **The ERC-2771 harness is the highest-value open item.** `INV-10` is the invariant whose violation would have
   been the audit's **only High finding**, and it currently holds *by static reasoning alone*. Nothing in CI enforces
   the separation: a future refactor that adds `MetaTxModuleStandalone` to an operation rule would silently hand the
   forwarder the ability to impersonate the bound token and forge approvals — and **no test would fail**. This item
   is not "extra coverage"; it converts a High-severity near-miss from *assumed* to *enforced*.

2. The wrapper guard's prerequisite (the ERC-165 advertisement) is already shipped, so this is now a small, isolated
   change. It must use the pre-computed interface constant, not `type(IAddressList).interfaceId`.

3. **Design decision for the maintainers, presented neutrally.** Documentation prevents a *careful* integrator from
   misdeploying `…MultiToken`; nothing stops a careless one, and the one wiring that "works" silently shares
   approvals across every token behind the engine. A `bindToken` guard would make the constraint unrepresentable at
   the cost of one `staticcall` per binding and **zero hot-path gas**. The alternative — leaving it documented — is
   defensible if the operator set is small and trusted. *Note:* the existing RuleEngine-integration test currently
   asserts the working-but-defeating wiring, and would need to become a negative test.

6. **Blocked upstream.** Four access-control hooks are declared non-`view` in `lib/RuleEngine`, and Solidity checks
   mutability against a virtual's *declared* type. The local overrides are all `view`, but the guarantee cannot be
   made project-wide until the upstream declarations change.

---

## 8. Scope & duplicate check

**In scope.** Every finding is anchored in `src/`, or in documentation describing `src/`. No finding depends on a bug
in `lib/CMTAT`, `lib/RuleEngine`, or OpenZeppelin.

**Duplicates.** None of the findings duplicate an entry in the audit overview, nor a Slither/Aderyn hit. The two
static analysers reported **nothing to fix** for `v0.4.0` — every hit was a false positive or by-design — and this
review found no overlap with them. F-4's *symptom* was already asserted by an existing integration test (so the
behaviour was known to the team); what this review adds is the stranded-approval consequence, the cross-token
consumption proof, and the self-contradictory documentation.

**Observations considered and dismissed** — recorded so no reader mistakes an omission for an oversight:

| Observation | Disposition |
|---|---|
| ERC-2771 forwarder can impersonate role holders | Trusted actor — the forwarder is immutable and set at construction |
| Admin implicitly holds every role | By design (regulated-issuer model); documented |
| Sanctions screening fails open when the oracle is unset; `clearSanctionListOracle` is a one-call kill switch | By design; symmetric with `clearIdentityRegistry`; matches the constructor's optional-oracle contract |
| ERC-2980 requires only `to` to be whitelisted; a frozen `from` cannot burn | Spec-conformant ERC-2980 semantics |
| `RuleBlacklist` screens the minter (no mint carve-out) | Correct and intended — a deny-list *must* screen the minter; the mirror image of the whitelist rules |
| CEI inversion in `approveAndTransferIfAllowed` | Deliberate and documented; the rule custodies no value, and reentrancy could at most consume approvals the operator already granted for the same tuple |
| Reverting sanctions oracle / identity registry bricks transfers | Trusted external dependency; a revert bubbles up with no state corruption |
| `RuleMaxTotalSupply.setTokenContract` can repoint the supply oracle | Trusted role; the rule's NatSpec already states `tokenContract` is trusted to report `totalSupply` honestly |
| Unbounded child-rule loop in the wrapper | Bounded by `maxRules` and the scan's early-exit; cost now measured and documented |
| Wrapper cross-rule OR (`from` in child A, `to` in child B) | Documented design — the wrapper's stated semantics are "listed in **any** child" |

---

## 9. Conclusion

`v0.4.0` contains **no Critical, High, or Medium severity vulnerability**, and the two threats that would have been
High were specifically probed and found not to exist.

The issues that *were* found share a single theme, and it is worth naming: **rules that answer the same question
with different conventions, or differently from their own documentation.** Not one of them is exploitable by an
untrusted party — but each could cause a real operational failure for an honest issuer (halted issuance, a trapped
investor, a stranded approval, a misleading pre-flight). The remediation therefore prioritised making the rules
*consistent and spec-conformant* over adding defensive checks, and added `RULE_SEMANTICS.md` so the remaining
differences are documented rather than discovered.

Two standards-conformance defects were fixed in the process — one against ERC-3643 (`isVerified`), one against
ERC-2980 (the mandatory `whitelist` getter) — neither of which was in the original finding list.

**Reminder:** this project has **not** undergone a formal third-party security audit. This report is an AI-assisted
review with executable proofs, not a substitute for one.
