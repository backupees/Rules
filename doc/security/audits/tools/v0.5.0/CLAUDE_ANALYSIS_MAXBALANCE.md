# Claude Code Analysis — RuleMaxBalance and the ChainlinkPoR split

Report version: `v0.5.0`
Tool: **Claude Code** (Anthropic) — interactive review and implementation session, model Opus 5
Compiler: solc `0.8.36`, optimizer on (200 runs), EVM `prague`
Scope: the code added in this session — `RuleMaxBalanceBase`, `RuleMaxBalance`,
`RuleMaxBalanceOwnable2Step`, `RuleMaxBalanceInvariantStorage`, `IBalanceOf`, `BalanceOfMock`, and
`ChainlinkPoRFeedManager` extracted from `RuleChainlinkPoRBase`. Sibling rules are read only as the
comparison baseline.

**This is a code-quality review, not a security audit. Nothing here is a vulnerability.** No finding lets an
unauthorized party move value, bypass a restriction or brick a contract. The one item with real
correctness weight (H-1) is an *assumption that currently holds* and was undocumented and unpinned; it is now
both. The known limitation of this rule — that a per-address cap is bypassable by splitting a position across
wallets — is a documented design property, not a defect, and is covered in
[`RuleMaxBalance.md`](../../../../technical/RuleMaxBalance.md).

## Disposition summary

| ID | Finding | Outcome | Commit |
| --- | --- | --- | --- |
| A-1 | No loops in the rule; batch delegates to the shared library, already `calldata` | ✅ Nothing to do — verified | — |
| B-1 | Check order: exemption lookup before the balance read | ⬜ **Left as is** — measured, the alternative is worse for the likely traffic mix | — |
| C-1 | Exemption events emitted from public functions while scalar setters use `_setX` helpers | ✅ Fixed — `_addExemptAddress` / `_removeExemptAddress` own guards + write + event | `PENDING` |
| D-1 | `_balanceOf` mirrors `TokenSupplyReader._currentSupply` in shape | ⬜ **Left as is** — different functions, one rule; extraction would be premature | — |
| D-2 | detect-then-`require` `_transferred` pair now in a 10th rule | ⬜ Left as is — consistent with the earlier `D-3` decision | — |
| E-1 | Three functions not `virtual` (`canReturnTransferRestrictionCode`, both `transferred`) | ✅ Nothing to do — matches every sibling exactly | — |
| F-1 | `IAddressList` deliberately not advertised | ✅ **Keep** — advertising it would let the rule be misread as a whitelist | — |
| F-2 | Codes `82` / `83` unique across the library | ✅ Verified | — |
| F-3 | `address(0)` could enter the exemption set | ✅ Fixed during implementation — guard was missing on the single-add path | (in the feature commit) |
| G-1 | Documentation claims checked against the code | ✅ Verified — no mismatch found | — |
| H-1 | The cap silently depends on the token notifying *before* it moves value | ✅ Fixed — documented and pinned by a mutation-verified test | `PENDING` |
| H-2 | `remainingCapacity` returns code `OK` with headroom `0` for a holder at the cap | ⬜ Left as is — documented; `OK` means the query succeeded | — |

12 findings: 6 verified-as-correct or nothing-to-do, 2 implemented, 4 deliberately left.

## Outstanding

| ID | Item | Why it is still open |
| --- | --- | --- |
| B-1 | Check order | Deliberate. Revisit only with real traffic data showing exempt receivers exceed ~19% of inbound transfers |
| E-1 | Non-`virtual` `transferred` overloads | Library-wide, out of scope here. Same set as the earlier `E-2` scope note (~55 public views) |

---

## A. Loops and iteration

### A-1. No iteration of its own — verified, nothing to do

`RuleMaxBalanceBase` contains no loop. The batch entrypoints take `address[] calldata` and delegate to
`AddressSetBatchLib`, which already owns the only loops and was reviewed under `D-1` in the main analysis.

```solidity
function addExemptAddresses(address[] calldata targetAddresses) public virtual onlyMaxBalanceManager {
```

`calldata` rather than `memory`, so the `A-3` finding still open against `areAddressesListed` does not
recur here. The compiler is `0.8.36`, so `unchecked { ++i }` would buy nothing anywhere and is correctly
absent.

**Verdict: nothing to do.**

## B. Storage reads

### B-1. The exemption lookup runs before the balance read — measured, and kept

`_detectTransferRestriction` resolves in this order: sentinel, exemption set, balance, cap.

```solidity
if (to == address(0)) { return TRANSFER_OK; }
if (_isAddressListed(to)) { return TRANSFER_OK; }      // <- cold SLOAD on every non-exempt transfer
(bool available, uint256 balance) = _balanceOf(to);     // <- external call
uint256 cap = maxBalance;
```

Every non-exempt transfer — the common case — pays a cold `SLOAD` for a set membership test that almost
always answers "no". Reordering so the balance is read first, and the exemption set consulted only on the
paths that would otherwise reject, removes that read from the common path.

Measured by toggling the reorder in place on the real contract and re-running one harness, each path in its
own transaction:

| Path | Current order | Reordered | Δ |
| --- | --- | --- | --- |
| Non-exempt, under the cap | 14 995 | 12 684 | **−2 311** |
| Exempt receiver | 2 995 | 12 684 | **+9 689** |

The reorder is not free: an exempt receiver currently short-circuits before the external call, and afterwards
would always pay it. Break-even is at **19.3%** of inbound transfers going to exempt addresses
(`2311 / (2311 + 9689)`).

**Verdict: leave as is.** Three reasons, in order of weight:

1. **Exempt addresses are the high-traffic ones.** The exemption list exists for custodians, omnibus accounts,
   treasury and redemption contracts — precisely the addresses that receive most often. A mix above 19% is
   not a corner case for this rule, it is the expected shape.
2. **The current order keeps a useful property**: exempt receivers and burns are decided without reading a
   balance, so they keep working while the token's `balanceOf` is broken. That is pinned by
   `testBrokenTokenStillAllowsBurnAndExempt`. The reorder preserves it only by adding the exemption test to
   both failure branches, which is more code for a worse average.
3. The saving is 15% of a check whose cost is dominated by an external call neither order removes.

Revisit only with deployment data showing exempt receivers below ~19% of inbound transfers.

### B-2. Single reads elsewhere — verified

`maxBalance` is read once into `cap` before both comparisons; `balanceToken` is read once per `_balanceOf`.
No slot is read twice across an external call. Nothing to hoist.

## C. Events

### C-1. Exemption writes emitted inline while scalar writes use `_setX` helpers — fixed

Every event has exactly one emit site (verified by `grep -rc 'emit <Event>' src/`), so no invariant was at
risk. The finding is an *internal inconsistency*: `MaxBalanceUpdated` and `MaxBalanceTokenUpdated` are owned
by `_setMaxBalance` / `_setBalanceToken`, which hold validation, write and event together — while the
exemption events were emitted from the public functions, with the guards inline beside them.

That is the house style in this codebase (the same pattern the main analysis's `C-1`–`C-3` established), and
the exemption path was the exception. Concretely it mattered for one reachable case: a subclass wanting to
pre-exempt a treasury address from its constructor had to restate both `require`s, with nothing forcing the
event.

Fixed by giving the exemptions the same ownership:

```solidity
function _addExemptAddress(address targetAddress) internal virtual {
    require(targetAddress != address(0), RuleAddressSet_ZeroAddressNotAllowed());
    require(_addAddress(targetAddress), RuleAddressSet_AddressAlreadyListed());
    emit ExemptAddressAdded(targetAddress);
}
```

**Moving the guards into the helper is the point, not a side effect**: the zero-address and duplicate checks
now cover every write path, including any future constructor. No behaviour change on the existing path — the
37 unit tests pass unchanged, including the two that assert each `require`.

The batch events keep their counters (`added` / `skipped`), which is the shape `C-4` of the main analysis
established for the whole library.

## D. Duplication

### D-1. The revert-free read mirrors `TokenSupplyReader` — considered, declined

`_balanceOf` has the same shape as `TokenSupplyReader._currentSupply`, and `_setBalanceToken`'s probe the
same shape as `_probeTotalSupplyCallable`:

```solidity
try balanceToken.balanceOf(account) returns (uint256 b) { return (true, b); } catch { return (false, 0); }
```

**Declined, for the reason `D-2` of the main analysis gives for when extraction *is* right.** That extraction
happened because two rules held *byte-identical* code. Here the functions differ — `balanceOf(address)` takes
an argument and `totalSupply()` does not — so a shared base would need a hook per call shape, and only one
rule uses this one. Extracting now would add indirection to remove nothing. Reconsider if a second
balance-reading rule appears; at that point the precedent applies directly.

### D-2. A tenth detect-then-`require` pair — consistent with the existing decision

`_transferred` / `_transferredFrom` follow the pattern already reviewed as `D-3` and deliberately left, on the
grounds that the per-rule custom error is the only variation and is worth keeping. This rule makes it ten
instances. Recorded so the count in that finding stays accurate; no new decision.

## E. `virtual` / override convention

### E-1. Three functions not `virtual` — matches every sibling

`canReturnTransferRestrictionCode`, `transferred(from,to,value)` and `transferred(spender,from,to,value)`
carry `override` without `virtual`.

Checked against `RuleMaxTotalSupplyBase`, `RuleChainlinkPoRBase`, `RuleBlacklistBase` and
`RuleWhitelistBase`: **none** of them marks these three `virtual` either. The new rule is consistent with the
library rather than introducing an inconsistency, which is the evidence the convention check weighs most.

Everything else in the new code — every `internal`, every setter, every getter — is `virtual`, matching
`CLAUDE.md`'s "all `internal` functions should be `virtual`" and the outcome of `E-1`/`E-3` in the main
analysis.

**Verdict: nothing to do here.** These three belong to the library-wide set called out as out of scope in
`E-2` and should move together if they move at all.

## F. Specification conformance

### F-1. `IAddressList` is not advertised — keep it that way

The rule inherits `RuleAddressSetInternal` for the exemption set but implements and advertises **no**
`IAddressList` surface. That is worth stating explicitly, because the opposite would be an easy "improvement"
to make and would be a real defect:

`RuleWhitelistWrapperBase` discovers child rules by calling `IAddressList.areAddressesListed`. A rule that
advertised `IAddressList` could be added to a wrapper, which would read its set as *"these addresses are
allowed"* — the exact inverse of *"these addresses are exempt from a cap"*. Every exempt address would be
treated as the only permitted address, and every other holder blocked.

Advertising only `IRule` / `IERC1404Extend` / the compliance interfaces (inherited from
`RuleTransferValidation`) keeps that mistake unavailable. **Verdict: keep, and this note is the reason.**

### F-2. Restriction codes are unique — verified

`82` and `83` are free across the whole library; the used set is
`21–25, 30–32, 36–38, 46, 50–51, 55–57, 60–66, 70, 75–79, 81` plus the RuleEngine's `200/201`. Both are
returned by `canReturnTransferRestrictionCode` and mapped by `messageForTransferRestriction`, and both are
covered by tests.

### F-3. `address(0)` could enter the exemption set — found and fixed during implementation

`RuleAddressSetInternal._addAddress` does **not** guard the sentinel; each caller must, which
`IdentityRegistryWhitelistBase` does explicitly. The first version of `addExemptAddress` omitted that guard,
so the mint/burn sentinel could have been added to the exemption list — violating invariant `I-12` and
polluting the emitted event with an address that is not a holder.

Caught by `testAddExemptAddressRejectsZeroAddress` before the rule was complete. Both paths are now guarded
and tested: the single add by an explicit `require`, the batch by the function pointer
`_addAddresses` passes to `AddressSetBatchLib`, which rejects the whole batch.

## G. Code / documentation agreement

### G-1. Claims checked against the code — no mismatch

Grepped the rule's documentation for testable claims and checked each: the code table (`82`/`83`), the
who-is-screened matrix, the `maxBalance = 0` semantics, `remainingCapacity` returning `type(uint256).max` for
exempt addresses and the burn sentinel, the batch conventions, the one-instance-per-token caveat, and the
role names in the methods table. All hold.

The documented limitation — that the cap is per address and bypassable by splitting a position — is asserted
end to end by `testSplitWalletsBypassTheCapEvenWithAWhitelist`, which deliberately admits both wallets of one
investor and shows the combined holding reaching twice the cap with a whitelist active. The documentation and
the test therefore cannot drift apart silently.

## H. Behaviour at odds with the purpose

### H-1. The cap depended, silently, on *when* the token notifies — documented and pinned

The check is `balanceOf(to) + value <= maxBalance`. That is correct **only while `balanceOf(to)` still
excludes `value`** — i.e. only if the token calls the compliance hook *before* it moves the tokens.

CMTAT does:

```solidity
// CMTAT, 0_CMTATBaseCommon.sol
function transfer(address to, uint256 value) public virtual override returns (bool) {
    address from = _msgSender();
    _checkTransferred(address(0), from, to, value);   // <- compliance first
    ERC20Upgradeable._transfer(from, to, value);      // <- balances after
```

So the rule is correct as shipped. But nothing in the rule said so, and nothing failed if it stopped being
true. A token that notified compliance *after* crediting the receiver would double-count `value`, **halving
the effective cap** and rejecting a transfer that exactly reaches it — a silent, plausible-looking
off-by-a-factor rather than an obvious break.

Fixed two ways. The assumption is now stated in the contract NatSpec, naming the CMTAT call order. And it is
pinned by a test that mints exactly the cap:

```solidity
function testMintExactlyToTheCapProvesPreUpdateAccounting() public {
    cmtatContract.mint(INVESTOR, CAP);
    assertEq(cmtatContract.balanceOf(INVESTOR), CAP, "a mint of exactly the cap must succeed");
```

**The guard was verified, not assumed.** Mutating `_detectTransferRestriction` to simulate post-update
accounting (`balance += value`) makes it fail with exactly the predicted symptom:

```
[FAIL: RuleMaxBalance_InvalidTransferFrom(..., 1000, 82)] testMintExactlyToTheCapProvesPreUpdateAccounting()
```

A mint of exactly the cap rejected with code `82` — the halved cap, caught.

### H-2. `remainingCapacity` returns `OK` with zero headroom — left, and documented

For a holder already at or above the cap, `remainingCapacity` returns `(TRANSFER_OK, 0)`. The code describes
whether the *query* could be answered, not whether a transfer would succeed; a caller reading only the code
could misread "0 headroom" as "fine to proceed".

**Left as is.** The two-value return is the answer: the caller must look at `headroom`, and returning a
non-zero restriction code for a perfectly readable balance would be worse — it would make a diagnostic view
report a failure that has not been attempted. The NatSpec says the code is `0` "when the headroom is
meaningful". Recorded here rather than changed.

---

## What was measured

- **B-1** — `detectTransferRestriction`, both paths, current order vs reordered, toggled in place on the real
  contract and re-run through one harness: 14 995 / 2 995 versus 12 684 / 12 684.
- **H-1** — mutation of the balance comparison to simulate post-update accounting; the new test fails with
  code `82` and passes when reverted.
- Coverage after the session: `RuleMaxBalanceBase` 98.82% lines, **100% statements, 100% branches**;
  both deployment variants 100% across the board. The single uncovered line is the abstract
  `_authorizeMaxBalanceManager` declaration, which no test can execute because only the override runs.

All 820 tests pass on the default profile and 31 on the ERC-3643 profile.
