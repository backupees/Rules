# Identity Registry Whitelist (ERC-3643)

[TOC]

`IdentityRegistryWhitelist` is a whitelist that presents itself to an **ERC-3643 token as its identity registry**. Install it with `token.setIdentityRegistry(address(this))`. `registerIdentity` whitelists a wallet, `deleteIdentity` removes it, and `isVerified` answers the question the token asks on every inbound transfer.

> **This is not a compliance rule.** It implements no `IRule` surface, has no restriction codes, and **must not be added to a `RuleEngine`**. It sits on the token's *identity registry* slot, not its *compliance* slot. Do not confuse it with [`RuleIdentityRegistry`](./RuleIdentityRegistry.md), which is the mirror image: a compliance rule that *consults* an external identity registry. This contract *is* the registry.

The design goal is a **wrapper, not a registry**: it adapts the calls an ERC-3643 token makes onto a plain whitelist, and keeps **no identity state whatsoever** — no ONCHAINID, no country, no claims. `registerIdentity`'s `_identity` and `_country` arguments exist so the ERC-3643 signature matches; both are discarded. Verification means exactly one thing: is this wallet on the whitelist.

## Which ERC-3643 functions call the registry, and how

Transcribed from the reference `Token.sol` (vendored at `lib/ERC-3643/contracts/token/Token.sol`).

| Token function | Registry call | When | Effect if it returns false / reverts |
| --- | --- | --- | --- |
| `transfer(to, amount)` | `isVerified(_to)` | Before moving value | Reverts `"Transfer not possible"` |
| `transferFrom(from, to, amount)` | `isVerified(_to)` | Before moving value | Reverts `"Transfer not possible"` |
| `forcedTransfer(from, to, amount)` | `isVerified(_to)` | Before moving value | Reverts `"Transfer not possible"` |
| `mint(to, amount)` | `isVerified(_to)` | Before minting | Reverts `"Identity is not verified."` |
| `burn(user, amount)` | **none** | — | Burn never consults the registry |
| `recoveryAddress(lost, new, onchainID)` | `keyHasPurpose` on `onchainID`, then `investorCountry(lost)`, `registerIdentity(new, …)`, `deleteIdentity(lost)` | See sequence below | Reverts `"Recovery not possible"` if `keyHasPurpose` is false |

Every one of those calls is answered from the whitelist. `investorCountry` is the only one with nothing to answer from, and it returns a constant 0.

Two consequences worth internalising:

- **Only the RECEIVER is ever screened.** ERC-3643 checks `_to`, never `_from` and never the spender. A de-listed holder can still send, which is deliberate: it lets a lapsed investor exit their position rather than being trapped. `forcedTransfer` bypasses freezes but **not** this check.
- **`burn` bypasses the registry entirely**, so an issuer can always burn a de-listed holder out.

### The `recoveryAddress` sequence

```
1. keyHasPurpose(keccak256(abi.encode(newWallet)), 1)  ── on the CALLER-SUPPLIED onchainID
   └─ false ⇒ revert "Recovery not possible"
2. investorCountry(lostWallet)                          ── always 0 here; discarded in step 3
3. registerIdentity(newWallet, onchainID, country)      ── called BY THE TOKEN
4. forcedTransfer(lostWallet, newWallet, balance)       ── re-enters isVerified(newWallet)
5. deleteIdentity(lostWallet)                           ── called BY THE TOKEN
```

Step 1 is the subtle one: the token calls `keyHasPurpose` on the `_investorOnchainID` **argument it was given**, not on anything the registry returns. Passing this registry's own address as that argument routes the check here, which is what removes the ONCHAINID dependency.

Steps 3 and 5 mean **the token itself is a caller of the registry's write functions**, which drives the access-control setup below.

## Installation

```solidity
IdentityRegistryWhitelist registry = new IdentityRegistryWhitelist(admin);
token.setIdentityRegistry(address(registry));

bytes32 role = registry.IDENTITY_REGISTRAR_ROLE();
registry.grantRole(role, operator);        // maintains the whitelist
registry.grantRole(role, address(token));  // REQUIRED for recoveryAddress
```

Then, to recover a wallet:

```solidity
registry.registerIdentity(newWallet, address(0), 0);                // must come FIRST
token.recoveryAddress(lostWallet, newWallet, address(registry));    // registry as the onchainID
```

## Access Control

| Role | Description |
| --- | --- |
| `DEFAULT_ADMIN_ROLE` | Manages roles; implicitly holds every role |
| `IDENTITY_REGISTRAR_ROLE` | May call `registerIdentity` and `deleteIdentity` |

**The token must hold `IDENTITY_REGISTRAR_ROLE`**, because `recoveryAddress` makes the token call `registerIdentity` and `deleteIdentity`. Without it, every recovery reverts.

> **Warning.** Granting the role to the token means the token contract can whitelist and de-whitelist arbitrary addresses. That is inherent to ERC-3643's recovery design — the reference `IdentityRegistry` requires the token to be an `agent` for exactly the same reason — but it does widen the trust boundary: the token's agents transitively control the whitelist. Grant the role to the token only once, and treat the token's agent set as part of the registry's trust model.

## Methods

### `registerIdentity(address _userAddress, address _identity, uint16 _country)`

Adds a wallet to the whitelist. `_identity` is echoed in `IdentityRegistered` for off-chain traceability; `_country` is ignored entirely. **Neither is stored.** Reverts on the zero address. Restricted to `IDENTITY_REGISTRAR_ROLE`.

**Idempotent**: re-registering an already-registered wallet is a no-op, not an error. See [Limitation 2](#2-registeridentity-is-idempotent-diverging-from-the-reference-registry).

### `deleteIdentity(address _userAddress)`

Removes a wallet from the whitelist and clears its reverse-index entry. Reverts if the wallet is not registered. Restricted to `IDENTITY_REGISTRAR_ROLE`. Emits `IdentityRemoved`.

### `isVerified(address _userAddress) → bool`

Whitelist membership. **`isVerified(address(0))` is always `false`** — the zero address can never enter the registry, so the registry can never authorise a mint to it.

### `investorCountry(address _userAddress) → uint16`

**Always returns 0.** No country is stored. The function exists only because `recoveryAddress` calls it — omitting it would make every recovery revert — and the 0 it returns is handed straight back into `registerIdentity`, which ignores it. See [Limitation 3](#3-no-identity-data-is-kept).

### `keyHasPurpose(bytes32 _key, uint256 _purpose) → bool`

Resolves `_key` to a wallet through the reverse index and returns that wallet's `isVerified`. `_purpose` is **ignored**. See [Limitation 1](#1-keyhaspurpose-is-not-a-real-erc-734-identity).

### `registeredIdentities() → address[]` / `registeredIdentityCount() → uint256`

Enumeration helpers for off-chain auditing. `registeredIdentities` is unbounded — do not call it from another contract.

## Limitations

### 1. `keyHasPurpose` is not a real ERC-734 identity

This contract holds **no keys and no claims**. `keyHasPurpose` exists for one reason: so the registry can be passed as `_investorOnchainID` to `recoveryAddress`.

- **`_purpose` is ignored.** Purpose 1 (MANAGEMENT), purpose 2 (ACTION) and any other value all return the same whitelist answer. A caller that genuinely needs ERC-734 purpose semantics will be misled.
- **The key must be resolvable.** `_key` is `keccak256(abi.encode(wallet))`, a hash that cannot be inverted, so the contract maintains a reverse index `key → wallet`, written by `registerIdentity` and cleared by `deleteIdentity`. **A key for a wallet that was never registered resolves to `address(0)`, which is never verified — so it returns `false`.** That is fail-closed, but it produces the ordering constraint below.
- **Consequence: the new wallet must be registered *before* `recoveryAddress` is called.** In stock ERC-3643 the new wallet is *not* pre-registered — its ONCHAINID vouches for it. Here the whitelist is the only source of truth, so the replacement wallet must already be on it.
- The key derivation must match `Token.recoveryAddress` exactly (`abi.encode`, not `abi.encodePacked`); this is pinned by a test.

### 2. `registerIdentity` is idempotent, diverging from the reference registry

ERC-3643's `IdentityRegistryStorage.addIdentityToStorage` reverts with `"address stored already"` on a duplicate. **This contract does not** — with no identity state to refresh, re-registration is simply a no-op.

That divergence is forced, not incidental. Limitation 1 requires the new wallet to be registered before `recoveryAddress`; step 3 of the sequence then has the token call `registerIdentity` on that same wallet. A duplicate-rejecting implementation would abort **every** recovery. The two requirements are only satisfiable together if re-registration is an update.

The practical effect is that `registerIdentity` cannot be used to detect "was this wallet already known" — check `isVerified` first if you need that.

### 3. No identity data is kept

The contract's entire state is the whitelist plus the reverse index over it. Specifically:

| ERC-3643 concept | Here |
| --- | --- |
| ONCHAINID (`_identity`) | Echoed in `IdentityRegistered`, never stored. No `identity()` getter. |
| Investor country (`_country`) | Ignored on write; `investorCountry` is a constant `0`. |
| Claims / claim topics | Not modelled at all. |

Consequences: anything expecting `identityRegistry.identity(wallet)` to return a usable ONCHAINID will not work, and **country-based compliance cannot be built on this registry** — a compliance module that branches on `investorCountry` will see every investor as country 0. `Token.sol` itself reads neither, so the token is unaffected; it is downstream tooling that needs checking.

If you need investor metadata on-chain, this is the wrong contract — it is a whitelist wearing the registry interface, nothing more.

### 4. No claim topics, no trusted issuers

`IClaimTopicsRegistry` and `ITrustedIssuersRegistry` are not implemented and are not referenced. Whether an investor qualifies is an off-chain decision, expressed on-chain by the registrar's `registerIdentity` call. If you need on-chain claim verification, this is the wrong contract — use the full ERC-3643 registry stack.

### 5. Only the token-facing interface exists

`contains`, `identity`, `updateIdentity`, `updateCountry`, `batchRegisterIdentity`, `identityStorage`, `issuersRegistry` and `topicsRegistry` are **not** implemented. None are called by `Token.sol`, so the registry is a complete drop-in for a token, but it is **not** a complete `IIdentityRegistry`: third-party tooling that expects the full interface will revert. To update a country, call `registerIdentity` again (see Limitation 2).

## Tests

| File | Covers |
| --- | --- |
| `test/IdentityRegistryWhitelist/IdentityRegistryWhitelistUnit.t.sol` | Registration, deletion, idempotency, zero-address rejection, access control, `keyHasPurpose` semantics and key derivation |
| `test/IdentityRegistryWhitelist/IdentityRegistryWhitelistERC3643.t.sol` | End-to-end against an ERC-3643 token: `mint`, `transfer`, `transferFrom`, `forcedTransfer`, `burn`, `recoveryAddress` |

The integration tests use `ERC3643TokenMock`, whose registry call sequences and revert strings are transcribed from the reference `Token.sol`. The real implementation is not used because it imports the ONCHAINID Solidity package (not vendored) and targets OpenZeppelin v4 upgradeable contracts, while this repository vendors OZ v5 — it does not compile in this build. The mock keeps the registry interaction faithful and omits what is orthogonal to it (compliance module, pausing, partial-freeze accounting).
