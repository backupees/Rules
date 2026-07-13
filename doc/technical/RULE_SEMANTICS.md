# Rule Semantics — comparison table

[TOC]

The rules in this library answer the same two questions — *may this transfer proceed?* (read path) and *record/enforce it* (write path) — but they answer with **different conventions**. In particular they differ on **whether they screen the spender**, **how they treat mint (`from == address(0)`) and burn (`to == address(0)`)**, and **what happens when their external oracle/registry is unset**. This page is the single place those differences are laid out side by side so an integrator does not have to read each rule's source to learn them.

Each cell reflects the rule's own `_detectTransferRestriction*` logic; behaviour is identical on the enforcement path (`transferred`), which reverts on any non-`TRANSFER_OK` code.

Legend: ✅ screened / can block · ❌ not screened · ⚙️ conditional (see note) · n/a not applicable.

---

## 1. Who each rule screens

"Direct" = a plain `transfer` (`transferred(from, to, value)`). The spender columns apply to the 4-arg `transferred(spender, from, to, value)` path; **mint** is that path with `from == address(0)` and `spender == minter`, **burn** with `to == address(0)` and `spender == burner` (CMTAT v3.3+).

| Rule | `from` (direct) | `to` (direct) | spender on `transferFrom` | spender on **mint** | spender on **burn** |
|---|---|---|---|---|---|
| `RuleWhitelist` | ✅ must be listed | ✅ must be listed | ⚙️ only if `checkSpender` | ❌ exempt | ❌ exempt |
| `RuleWhitelistWrapper` | ✅ listed in ≥1 child | ✅ listed in ≥1 child | ⚙️ only if `checkSpender` | ❌ exempt | ❌ exempt |
| `RuleSpenderWhitelist` | ❌ always allowed | ❌ always allowed | ✅ always (rule's purpose) | ❌ exempt | ❌ exempt |
| `RuleBlacklist` | ✅ blocks if listed | ✅ blocks if listed | ✅ blocks if listed | ✅ blocks listed minter [1] | ✅ blocks listed burner [1] |
| `RuleSanctionsList` | ✅ blocks if sanctioned | ✅ blocks if sanctioned | ✅ blocks if sanctioned | ✅ blocks sanctioned minter [1] | ✅ blocks sanctioned burner [1] |
| `RuleMaxTotalSupply` | ⚙️ mint only [2] | ❌ | ❌ ignored | ❌ caps supply, not minter | ❌ |
| `RuleIdentityRegistry` | ✅ must be verified | ✅ must be verified | ✅ must be verified | ✅ **minter must be verified** [3] | ❌ burn exempt [3] |
| `RuleERC2980` | ⚙️ frozen-check only [4] | ✅ frozen-check + must be whitelisted | ✅ frozen-check | ✅ blocks frozen minter | ✅ blocks frozen burner |
| `RuleConditionalTransferLight` | ❌ per-tuple approval [5] | ❌ per-tuple approval [5] | ❌ spender ignored | ❌ exempt | ❌ exempt |
| `RuleConditionalTransferLightMultiToken` | ❌ per-tuple approval [5] | ❌ per-tuple approval [5] | ❌ spender ignored | ❌ exempt | ❌ exempt |
| `RuleMintAllowance` | ❌ not tracked | ❌ not tracked | ❌ not tracked | ✅ **debits minter quota** [6] | ❌ not tracked |

## 2. Operational characteristics

| Rule | When its oracle/registry is unset | Stateful on transfer? [7] | Authoritative pre-flight view | Restriction codes |
|---|---|---|---|---|
| `RuleWhitelist` | n/a (local address set) | ❌ | `canTransfer` / `canTransferFrom` | 21–23 |
| `RuleWhitelistWrapper` | empty wrapper ⇒ **all rejected** (fail-closed) | ❌ | `canTransfer` / `canTransferFrom` | 21–23 |
| `RuleSpenderWhitelist` | n/a (local address set) | ❌ | `canTransfer` (always ✓) / `canTransferFrom` | 66 |
| `RuleBlacklist` | n/a (local address set) | ❌ | `canTransfer` / `canTransferFrom` | 36–38 |
| `RuleSanctionsList` | oracle == 0 ⇒ **all allowed** (fail-open) [8] | ❌ | `canTransfer` / `canTransferFrom` | 30–32 |
| `RuleMaxTotalSupply` | token contract required (non-zero) | ❌ | `canTransfer` / `canTransferFrom` [9] | 50 |
| `RuleIdentityRegistry` | registry == 0 ⇒ **all allowed** (fail-open) [8] | ❌ | `canTransfer` / `canTransferFrom` | 55–57 |
| `RuleERC2980` | n/a (local lists) | ❌ | `canTransfer` / `canTransferFrom` | 60–63 |
| `RuleConditionalTransferLight` | n/a (needs `bindToken`) | ✅ consumes an approval | `canTransfer` / `canTransferFrom` | 46 |
| `RuleConditionalTransferLightMultiToken` | n/a (needs `bindToken`) | ✅ consumes an approval | `canTransferForToken` / `detectTransferRestrictionForToken` [10] | 46 |
| `RuleMintAllowance` | n/a (needs `bindToken`) | ✅ debits quota | ⚠️ `canTransferFrom` **only** [11] | 70 |

---

## 3. Overload surface (ERC-7943 `tokenId` / `ITransferContext`)

Not every rule exposes the same entrypoints. The ERC-7943 `tokenId` overloads and the `ITransferContext` struct entrypoints come from `RuleNFTAdapter`, and **only the rules that inherit it have them**. This is a deliberate design choice, not an oversight: `RuleMaxTotalSupply` caps a fungible supply, and the conditional-transfer / mint-allowance rules key on fungible amounts, so a `tokenId` dimension would be meaningless for them.

| Rule | ERC-7943 `tokenId` overloads [12] | `transferred(FungibleTransferContext)` | `transferred(MultiTokenTransferContext)` |
|---|---|---|---|
| `RuleWhitelist` | ✅ | ✅ | ✅ |
| `RuleWhitelistWrapper` | ✅ | ✅ | ✅ |
| `RuleBlacklist` | ✅ | ✅ | ✅ |
| `RuleSpenderWhitelist` | ✅ | ✅ | ✅ |
| `RuleSanctionsList` | ✅ | ✅ | ✅ |
| `RuleERC2980` | ✅ | ✅ | ✅ |
| `RuleIdentityRegistry` | ✅ | ✅ | ✅ |
| `RuleMaxTotalSupply` | ❌ | ❌ | ❌ |
| `RuleConditionalTransferLight` | ❌ | ✅ | ❌ |
| `RuleConditionalTransferLightMultiToken` | ❌ | ✅ | ❌ |
| `RuleMintAllowance` | ❌ | ❌ | ❌ |

The `tokenId` parameter is **always ignored** by the rules that accept it — `RuleNFTAdapter` exists purely to re-expose the same restriction logic under the ERC-7943 signatures. The `tokenId` overload of any function therefore returns exactly what its fungible counterpart returns, and the `ctx` entrypoints dispatch to the same internal hooks (`ctx.sender == 0` or `ctx.sender == ctx.from` ⇒ the direct hook; otherwise the spender-aware hook). This parity is asserted for every rule above in `test/TransferContext/OverloadParity.t.sol`.

**Access control on the `ctx` entrypoints (threat `AC-5`).** `transferred(FungibleTransferContext)` / `transferred(MultiTokenTransferContext)` are `external` with **no caller restriction** on the validation rules. That is safe because those rules' hooks are `view`: an arbitrary caller can run the check and be reverted by it, but cannot mutate any state. The stateful multi-token rule guards its own `ctx` entrypoint with `onlyTransferExecutor`.

## 4. Notes & caveats

1. **Deny-lists intentionally screen the minter/burner.** `RuleBlacklist` and `RuleSanctionsList` do **not** exempt mint/burn from the spender check, so a blacklisted/sanctioned address cannot mint or burn. This is correct fail-closed behaviour for a deny-list (threat `BL-1`), the mirror image of the whitelist rules, which exempt mint/burn because the minter acts on its own authority rather than as a delegated spender.

2. **`RuleMaxTotalSupply` only acts on mints.** `_detectTransferRestriction` returns `TRANSFER_OK` unless `from == address(0)`; it caps *total supply*, so the "screened party" is the mint operation, not any address. The spender is ignored on every path.

3. **`RuleIdentityRegistry` screens the minter on mint but not the burner on burn** — see finding **F-1** (`RESULT.md`). The spender (minter) must itself be identity-verified for a mint to succeed, which diverges from the whitelist rules. Burn short-circuits (`to == address(0)` returns OK before the spender check), so the burner is not screened. If mint screening is not intended, add the `from != address(0)` guard used by the sibling whitelist rules.

4. **`RuleERC2980` does not require the sender to be whitelisted** — only that the sender is *not frozen*; only the recipient must be whitelisted (threat `E29-1`, ERC-2980 semantics). Note also that freezing `address(0)` blocks all mints and that burns require `address(0)` to be whitelisted via the `allowBurn` constructor flag (threat `E29-2`).

5. **Conditional-transfer rules screen the (from, to, value) tuple, not identities.** A transfer is allowed iff an operator has recorded an approval for that exact tuple; the individual addresses are never checked against a list. Mint/burn are exempt (`from`/`to == address(0)` returns early).

6. **`RuleMintAllowance` is the only rule that *uses* the mint spender.** On the 4-arg path with `from == address(0)`, it debits `mintAllowance[spender]`. On the 3-arg path (no spender) it performs no deduction, so it must be deployed against the CMTAT/RuleEngine v3.3+ spender-aware path.

7. **Stateful** means the rule writes storage inside the `transferred` callback. Validation rules are read-only; the three operation rules (`RuleConditionalTransferLight`, `…MultiToken`, `RuleMintAllowance`) mutate state and require `bindToken`.

8. **Fail-open when unset.** `RuleSanctionsList` (oracle == `address(0)`) and `RuleIdentityRegistry` (registry == `address(0)`) return `TRANSFER_OK` for everything — screening is disabled, not fail-closed (threats `SL-1`/`SL-2`). `clearSanctionListOracle()` / `clearIdentityRegistry()` are single-call kill switches for that screening. Compose with another rule if a hard floor is required.

9. **`RuleMaxTotalSupply` views are overflow-safe** (finding **F-2**, fixed): `detectTransferRestriction` / `canTransfer` return code `50` instead of reverting when `currentSupply + value` would overflow.

10. **`RuleConditionalTransferLightMultiToken` is direct-binding-only, and its `detectTransferRestriction` depends on `msg.sender`.** Approvals are recorded under the `token` argument but *consumed* under `msg.sender`, so the rule **must be bound directly to each token** (`CMTAT.setRuleEngine(rule)`) and **must not be added to a `RuleEngine`** — behind an engine it either reverts or silently loses all per-token isolation (finding **F-4**; full case analysis in [RuleConditionalTransferLightMultiToken.md](./RuleConditionalTransferLightMultiToken.md#deployment-topology--why-a-ruleengine-does-not-work)). For the same reason `detectTransferRestriction` / `canTransfer` derive the token key from the caller, so an off-chain `eth_call` from a non-bound address always reads "not approved" (code 46) even for an approved transfer (threat `CTL-4`, finding **F-8**). Use the caller-explicit **`detectTransferRestrictionForToken(token, …)`** / **`canTransferForToken(token, …)`** views for pre-flight — they take the token as a parameter and give every caller the real answer.

11. **`RuleMintAllowance.canTransfer` / `detectTransferRestriction` are NOT authoritative** (finding **F-7**): they are hardcoded to "allowed" because the 3-arg signature has no minter identity. Pre-flight a mint with `canTransferFrom(minter, address(0), to, value)`. See [RuleMintAllowance.md](./RuleMintAllowance.md#eligibility-views-which-one-is-authoritative).

12. **The ERC-7943 `tokenId` overloads** are `detectTransferRestriction(from,to,tokenId,value)`, `detectTransferRestrictionFrom(spender,from,to,tokenId,value)`, `canTransfer(from,to,tokenId,amount)`, `canTransferFrom(spender,from,to,tokenId,value)`, `transferred(from,to,tokenId,value)` and `transferred(spender,from,to,tokenId,value)` — all supplied by `RuleNFTAdapter`. Per ERC-7943, `amount`/`value` MUST be `1` for ERC-721. The rules ignore `tokenId` entirely; it exists so an ERC-721/ERC-1155 token can call the same compliance rule without a shim.

---

See [`../../RESULT.md`](../../RESULT.md) for the findings referenced above and [`../../THREAT_MODEL.md`](../../THREAT_MODEL.md) for the threat IDs.
