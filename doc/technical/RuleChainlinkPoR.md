# Rule Chainlink Proof of Reserve

[TOC]

`RuleChainlinkPoR` ensures the total supply of a token never exceeds the reserves actually backing it. Before every mint it reads the latest reserve value from a [Chainlink Proof of Reserve](https://docs.chain.link/data-feeds/proof-of-reserve) data feed and checks whether the new total supply (current supply plus the requested mint amount) would exceed what the reserves can back. If it would, the mint is rejected.

The maximum mintable supply equals the reported reserves **exactly** — there is no margin, buffer or headroom parameter. If you need a safety cushion, express it upstream (report conservative reserves on the feed) or compose with `RuleMaxTotalSupply` for a static ceiling.

Only mint operations (`from == address(0)`) are gated. Plain transfers do not change the total supply, and burns only reduce it, so both always pass — including while the feed is stale or unavailable. This is deliberate: a lapsed feed must never trap holders in their position.

The rule is modelled on Chainlink's [`SecureMintPolicy`](https://docs.chain.link/ace/reference/policy-library/secure-mint-policy) from the ACE policy library, re-expressed as an ERC-1404 / ERC-3643 compliance rule for this library and deliberately simplified: the ACE policy's configurable reserve margin is not carried over.

## Configuration

### Constructor parameters

| Parameter | Description |
| --- | --- |
| `admin` / `owner` | Address granted `DEFAULT_ADMIN_ROLE` (AccessControl variant) or set as owner (Ownable2Step variant) |
| `tokenContract_` | Address of the protected token; must expose `totalSupply()` and be non-zero |
| `tokenDecimals_` | Decimals of that token, `0` to `18`; validated against `decimals()` when the token exposes it |
| `reservesFeed_` | Proof of Reserve data feed implementing `AggregatorV3Interface`; must be a contract |
| `maxStalenessSeconds_` | Maximum accepted age of the reserve data, in seconds; `0` disables the check |

Every value can be updated after deployment by the rule manager.

### Proof of Reserve feed

Any contract implementing `AggregatorV3Interface` works; in practice this is a Chainlink Proof of Reserve feed (see the [Data Feeds addresses page](https://docs.chain.link/data-feeds/smartdata/addresses)). Each rule instance supports **one** feed. If the token is backed by several reserve sources, deploy one `RuleChainlinkPoR` per feed and add them all to the same `RuleEngine` — the engine applies them conjunctively, so every feed must back the mint.

The feed's `decimals()` is read **once**, when the feed is configured, and cached in `feedDecimals`. Configuration reverts if the call fails (`RuleChainlinkPoR_FeedDecimalsUnavailable`) or reports more than `MAX_FEED_DECIMALS` (36). Caching keeps the mint path to a single external call and removes a second source of read-path reverts.

> **Warning — cached decimals.** Because the value is cached, a feed that changes its own `decimals()` after configuration is **not** picked up, and every subsequent reserve reading is mis-scaled by the difference. Chainlink's `SecureMintPolicy` re-reads `decimals()` on every mint and is not exposed to this. Chainlink aggregator proxies do not change decimals in practice, but if you replace or re-point a feed, call `setReservesFeed` again so the cache is refreshed — even when the address is unchanged.

### Token metadata

`tokenContract` is called with `totalSupply()` on every mint; `tokenDecimals` is used to scale the feed answer into token units. When the token exposes `decimals()`, the configured value is checked against it and a mismatch reverts. `0` decimals is accepted and is the common case for CMTAT equity tokens.

> **Warning — decimal scaling.** For a token that does **not** expose `decimals()`, the configured value is used as-is. An incorrect value skews the reserve comparison in either direction, allowing over-minting or blocking valid mints. Verify the token's real decimals before configuring.

#### Truncation when the feed is finer-grained than the token

When `feedDecimals > tokenDecimals` the answer is divided, and the division **truncates**. Truncation always rounds the backed supply *down*, so the rule can under-mint but never over-mint — the safe direction for a reserve check.

This is most visible at `tokenDecimals == 0` (CMTAT equity tokens), where the divisor is the largest it can be for a given feed:

| Feed answer (8 decimals) | Backed supply, `tokenDecimals = 0` |
| --- | --- |
| `1000.99999999` | 1000 |
| `1000.00000000` | 1000 |
| `0.99999999` | 0 — every non-zero mint rejected |

The last row is the case to be aware of operationally: with a 0-decimals token, reserves below one whole unit back nothing at all. That is arithmetically correct — you cannot issue a whole share against a fractional reserve — but it means a feed reporting a small residual balance blocks issuance entirely rather than allowing a token or two.

Behaviour across the decimals domain is pinned by [`test/RuleChainlinkPoR/RuleChainlinkPoRDecimals.t.sol`](../../test/RuleChainlinkPoR/RuleChainlinkPoRDecimals.t.sol), which includes a fuzz cross-checking the implementation against `answer * 10**tokenDecimals / 10**feedDecimals` computed with full-precision `mulDiv`.

### Staleness threshold

`maxStalenessSeconds` is the maximum age of the reserve data before the rule rejects mints. Choose it from the **heartbeat** of the Proof of Reserve feed: the threshold should match or slightly exceed the heartbeat. A feed whose `updatedAt` is exactly `maxStalenessSeconds` old is still accepted; older is rejected.

Setting the threshold to `0` disables the check — the rule then accepts reserve data of any age. Do this only when the feed's freshness is guaranteed by other means.

## Restriction codes

| Constant | Code | Meaning |
| --- | --- | --- |
| `CODE_RESERVES_EXCEEDED` | 75 | `totalSupply + value` would exceed the backed supply |
| `CODE_RESERVES_FEED_STALE` | 76 | The feed has not been updated within `maxStalenessSeconds` |
| `CODE_RESERVES_ANSWER_INVALID` | 77 | The feed has no code, reverted, returned a negative answer, or reported an incomplete round (`updatedAt == 0`) |

## Access Control

| Variant | Gate |
| --- | --- |
| `RuleChainlinkPoR` | `DEFAULT_ADMIN_ROLE` (the default admin implicitly holds all roles) |
| `RuleChainlinkPoROwnable2Step` | Contract owner, with two-step ownership transfer |

All three setters are gated on `_authorizeChainlinkPoRManager()`.

## Methods

### `setReservesFeed(AggregatorV3Interface newReservesFeed)`

Replaces the data feed and re-caches its decimals. Reverts on the zero address, on an address with no code, when `decimals()` reverts, or when it reports more than 36. Emits `ReservesFeedUpdated`.

### `setTokenMetadata(address newTokenContract, uint8 newTokenDecimals)`

Replaces the protected token and its decimals. Reverts on the zero address, on decimals above 18, and on a mismatch with the token's own `decimals()` when exposed. Emits `TokenMetadataUpdated`.

### `setMaxStalenessSeconds(uint256 newMaxStalenessSeconds)`

Updates the staleness threshold. Emits `MaxStalenessSecondsUpdated`.

### `maxBackedSupply() → (uint8 restrictionCode, uint256 backedSupply)`

Previews the limit a mint is measured against, without simulating one. `restrictionCode` is `0` when the feed answer is usable, otherwise it is the code a mint would return (76 or 77) and `backedSupply` is `0`. Never reverts.

### View getters

`reservesFeed()`, `tokenContract()`, `feedDecimals()`, `tokenDecimals()`, `maxStalenessSeconds()`.

## Transfer restriction logic

For a mint (`from == address(0)`):

1. Read `latestRoundData()` from `reservesFeed`.
2. Reject with `CODE_RESERVES_ANSWER_INVALID` if the feed has no code, the call reverts, `answer < 0`, or `updatedAt == 0`.
3. Reject with `CODE_RESERVES_FEED_STALE` if `maxStalenessSeconds != 0` and `block.timestamp - updatedAt > maxStalenessSeconds`.
4. Scale the answer from `feedDecimals` to `tokenDecimals` to obtain `backedSupply`.
5. Reject with `CODE_RESERVES_EXCEEDED` if `tokenContract.totalSupply() + value > backedSupply`.

Anything else returns `TRANSFER_OK`. `detectTransferRestrictionFrom` delegates to the same logic and **ignores the spender**: this rule caps supply, it does not screen the minter.

### Read-path safety

`detectTransferRestriction*` and `canTransfer*` are ERC-1404 / ERC-3643 views that MUST NOT revert. The implementation therefore:

- checks `address(reservesFeed).code.length` before calling, and wraps `latestRoundData()` in `try/catch`;
- saturates instead of overflowing when scaling up (`answer * 10 ** (tokenDecimals - feedDecimals)`);
- bounds `feedDecimals` at 36 and `tokenDecimals` at 18 at configuration time, so the scaling exponent can never overflow;
- compares against the remaining headroom (`value > backedSupply - currentSupply`) instead of computing `currentSupply + value`, which could overflow.

`tokenContract` is **trusted** to return a correct, non-reverting `totalSupply` — same trust assumption as `RuleMaxTotalSupply`.

### Failure modes are fail-closed for mints only

A broken or stale feed blocks **minting**, never transfers or burns. This is the safe direction: the rule's purpose is to prevent unbacked issuance, and issuance can wait for the feed to recover. Holders retain full mobility of their existing balance throughout.

## Usage scenario

An issuer runs a tokenized commodity with a Chainlink Proof of Reserve feed reporting the custodian's holdings with 8 decimals; the token has 18 decimals and a 24 h feed heartbeat. They deploy:

```solidity
RuleChainlinkPoR rule = new RuleChainlinkPoR(
    admin,
    address(token),
    18,                    // token decimals
    AggregatorV3Interface(porFeed),
    1 days + 1 hours       // heartbeat plus slack
);
ruleEngine.addRule(rule);
token.setRuleEngine(ruleEngine);
```

With reserves reported at 1 000 units, at most 1 000 tokens may exist. A mint that would push the supply past 1 000 reverts with code 75; a mint attempted more than 25 h after the last feed update reverts with code 76. When the custodian deposits more and the feed updates, the headroom reopens automatically — no rule reconfiguration needed.

## Relationship to Chainlink's `SecureMintPolicy`

This rule implements the same core idea as [`SecureMintPolicy`](https://github.com/smartcontractkit/chainlink-ace/blob/main/packages/policy-management/src/policies/SecureMintPolicy.sol) from the Chainlink ACE policy library (compared against `SecureMintPolicy 1.2.0`, vendored at `lib/chainlink-ace/`): read a Proof of Reserve feed before every mint and reject issuance the reserves cannot back. It is **not a port**. The two live in different execution models, and that drives most of the differences below.

The decisive difference is **how a rejection is signalled**. `SecureMintPolicy.run()` reverts with `PolicyRejected`; it is called by an ACE `PolicyEngine` that only ever needs a yes/no at execution time. `RuleChainlinkPoR` must additionally satisfy the ERC-1404 / ERC-3643 read path, where `detectTransferRestriction` / `canTransfer` are views that **MUST NOT revert** and must return a numeric reason code. Every "returns a code where ACE reverts" row below follows from that one constraint.

### Summary

| Dimension | Chainlink `SecureMintPolicy` 1.2.0 | `RuleChainlinkPoR` |
| --- | --- | --- |
| Integration model | ACE `PolicyEngine`, bound to one selector | ERC-1404 / ERC-3643 rule, via `RuleEngine` or bound directly |
| Rejection signalling | Reverts (`PolicyRejected`) | Returns restriction code `75` / `76` / `77`; reverts only on the write path |
| Feed decimals | Read **live** on every `run()` | Read once and **cached** in `feedDecimals` |
| Feed decimals bound | Unbounded (`uint8`) | `<= MAX_FEED_DECIMALS` (36) |
| Feed call reverts | Propagates — mint reverts | `try/catch` → code `77` |
| Incomplete round (`updatedAt == 0`) | Not checked | Code `77` |
| Staleness arithmetic | `block.timestamp - updatedAt` — underflow-panics on a future timestamp | Guarded with `block.timestamp > updatedAt` |
| Token decimals accepted | `1` to `18` | `0` to `18` (CMTAT equity tokens report 0) |
| Reserve margin | 5 modes (percentage / absolute, positive / negative) | None — limit equals reserves exactly |
| Scale-up overflow | Checked arithmetic → revert | Saturates at `type(uint256).max` |
| Supply source | `subject`, supplied by the engine at call time | `tokenContract`, set in configuration |
| Single-token binding | Enforced — `onInstall` reverts with `PolicyAlreadyBound` | Not enforced (see below) |
| Pre-flight preview | None | `maxBackedSupply()` |
| Upgradeability | Upgradeable (ERC-7201 storage, initializers) | Non-upgradeable |
| Access control | `onlyOwner` | `DEFAULT_ADMIN_ROLE` or `Ownable2Step` |
| Setter no-op guards | Reverts if the new value equals the current one | No such guard |

### Where this rule is stricter

- **Feed failures degrade to a code, not a revert.** A feed with no code, a reverting `latestRoundData()`, a negative answer or an incomplete round all yield code `77`. ACE has no `updatedAt == 0` check at all, so with `maxStalenessSeconds == 0` an incomplete round is accepted at face value.
- **No underflow on a future `updatedAt`.** ACE computes `block.timestamp - updatedAt` unguarded; a feed reporting a timestamp ahead of the block panics the whole call. Fail-closed for ACE, but a panic rather than a clean rejection.
- **Feed decimals are bounded at configuration time**, so the scaling exponent can never overflow. ACE accepts any `uint8`, where a feed reporting e.g. 78 decimals makes `10 ** 78` revert on every mint.
- **`0`-decimals tokens are supported.** ACE requires `decimals > 0`, which excludes CMTAT equity tokens outright.

### Where ACE is stricter, and what this rule does instead

- **Feed decimals are read live.** ACE picks up a feed whose decimals change; this rule does not, because it caches. See the caveat under [Proof of Reserve feed](#proof-of-reserve-feed).
- **One policy instance is pinned to one token.** `onInstall` records the `subject` and reverts with `PolicyAlreadyBound` on reuse, and `run()` rejects a call from any other subject. `RuleChainlinkPoR` is a stateless validation rule with no binding, so the *same instance added to two RuleEngines checks both tokens against the single configured `tokenContract`*. That is a live misconfiguration hazard: deploy one instance per protected token.

  In exchange, this rule avoids ACE's documented `subject` vs `tokenMetadata.tokenAddress` split, where the supply is read from one address while the decimals are validated against another and nothing enforces that they agree. Here `setTokenMetadata` sets the address and the decimals together and cross-checks the decimals against that same address.

## Interaction with other rules

- `RuleMaxTotalSupply` caps supply at a **static** value; `RuleChainlinkPoR` caps it at a **live, oracle-reported** one. They compose: add both to the same `RuleEngine` and the stricter one binds. This is also how you get a conservative buffer under the reserves, now that the rule itself has no margin parameter.
- `RuleMintAllowance` limits how much **each minter** may issue; `RuleChainlinkPoR` limits how much **the token as a whole** may exist. Together they give a per-minter quota inside a reserve-backed ceiling.

## Deployment topology

The rule reads `msg.sender` for nothing and holds no per-token binding, so it works identically in RuleEngine mode (Topology A) and direct mode (Topology B). See the topology section of `CLAUDE.md`.
