# Claude Code Analysis — Deployment Scripts

Report version: `v0.5.0`
Tool: **Claude Code** (Anthropic) — interactive review and implementation session, model Opus 5
Scope: the four Foundry deployment scripts in `script/` and their tests under `test/DeploymentScripts/`.
`src/` is covered separately by [`CLAUDE_ANALYSIS.md`](./CLAUDE_ANALYSIS.md); `lib/` is out of scope.

The review axes are the ones used for that companion report: correctness, duplication, configuration,
events and observability, documentation, test coverage, and behaviour that is technically correct but does
not serve the purpose of the code.

**Status: all 12 findings implemented.** Each is marked in the summary table below, and
[What was implemented](#what-was-implemented) records how the central fix was verified.

**None of these are on-chain vulnerabilities.** Scripts are off-chain tooling; they hold no funds and are
not deployed. Severities describe how badly each one damages the script's usefulness, not exploitability.

## Inventory

State when the review was written, and after the fixes:

| Script | Topology | Tests (before → after) | Runs under `forge script`? (before → after) |
| --- | --- | --- | --- |
| `DeployCMTATWithBlacklist` | B (rule bound directly) | 1 → 6 | ❌ reverts → ✅ |
| `DeployCMTATWithWhitelist` | B (rule bound directly) | 1 → 8 | ❌ reverts → ✅ |
| `DeployCMTATWithBlacklistAndSanctionsList` | A (RuleEngine) | 18 → 18 | ❌ reverts → ✅ |
| `DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply` | A (RuleEngine) | 19 → 19 | ✅ → ✅ |

All four now run. Suite total went from 745 to 756 tests.

## Summary

All twelve findings are implemented.

| ID | Severity | Finding | Files | Status |
| --- | --- | --- | --- | --- |
| [S-1](#s-1) | **Blocker** | Three of four scripts revert under `forge script`: `address(this)` inside a broadcast | 1, 2, 3 | ✅ Fixed |
| [S-2](#s-2) | **High** | The tests structurally cannot catch S-1, and `run()` is untestable from `forge test` at all | all | ✅ Fixed (CI step) |
| [S-3](#s-3) | Medium | `DeployCMTATWithWhitelist` produces a token that cannot be minted | 2 | ✅ Fixed |
| [S-4](#s-4) | Medium | The CMTAT constructor block is copy-pasted four times | all | ✅ Fixed |
| [S-5](#s-5) | Medium | Every parameter is hard-coded; no environment configuration | all | ✅ Fixed |
| [S-6](#s-6) | Low | `forwarder` reaches the token but is silently dropped for the rules | 1, 2, 3 | ✅ Fixed |
| [S-7](#s-7) | Low | `bytes32(0)` written out instead of `DEFAULT_ADMIN_ROLE` (12 sites) | 1, 2, 3, 4 | ✅ Fixed |
| [S-8](#s-8) | Low | Deployed addresses are never logged | all | ✅ Fixed |
| [S-9](#s-9) | Low | Scripts 1 and 2 carry no NatSpec at all | 1, 2 | ✅ Fixed |
| [S-10](#s-10) | Low | The one assertion in scripts 1 and 2 skips the admin hand-over | 1, 2 | ✅ Fixed |
| [S-11](#s-11) | Info | Only script 4 warns that an unset sanctions oracle fails open | 3 | ✅ Fixed |
| [S-12](#s-12) | Info | The set silently mixes both integration topologies | all | ✅ Fixed |

Two candidate findings were checked and **dismissed**; they are recorded in
[Checked and not a problem](#checked-and-not-a-problem) so the negative results are not lost.

---

## S-1

**Three of four scripts revert under `forge script`.** <a id="s-1"></a>

Severity: **Blocker**. These scripts cannot deploy anything. Verified by running each one:

```
$ forge script script/DeployCMTATWithBlacklist.s.sol:DeployCMTATWithBlacklist
└─ ← [Revert] Usage of `address(this)` detected in script contract.
   Script contracts are ephemeral and their addresses should not be relied upon.
Error: script failed
```

Same for `DeployCMTATWithWhitelist` and `DeployCMTATWithBlacklistAndSanctionsList`.
`DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply` reports `Script ran successfully.`

The cause is the same in all three: the script uses `address(this)` as the account that performs the
deployment and holds the temporary admin roles.

```solidity
token = new CMTATStandardStandalone(forwarder, address(this), /* ... */);
// ...
if (admin != address(this)) {
    token.grantRole(bytes32(0), admin);
    token.renounceRole(bytes32(0), address(this));
}
```

Under `forge script` the calls are made by the **broadcaster**, not by the script contract, so the two
identities disagree. Foundry rejects the read outright rather than let a script depend on an address that
changes between simulation and broadcast.

**Mitigating factor:** the revert happens during simulation, before anything is broadcast. There is no
partial deployment and no orphaned contract, so the failure mode is a wasted invocation, not a stuck token.

**Fix.** Take the deployer as an explicit parameter. Script 4 already does exactly this and is the reason it
passes; the pattern transfers unchanged:

```solidity
function deploy(address admin, address deployer, /* ... */) public returns (/* ... */) {
    token = new CMTATStandardStandalone(forwarder, deployer, /* ... */);
    // ...
    if (admin != deployer) {
        token.grantRole(DEFAULT_ADMIN_ROLE, admin);
        token.renounceRole(DEFAULT_ADMIN_ROLE, deployer);
    }
}

function run() external returns (/* ... */) {
    vm.startBroadcast();
    // msg.sender is the broadcaster, which is also the account making every call below
    deploy(msg.sender, msg.sender, /* ... */);
    vm.stopBroadcast();
}
```

Existing tests keep working: they call `deploy()` directly and can pass `address(this)` themselves.

---

## S-2

**The tests cannot catch S-1, and `run()` cannot be tested from `forge test` at all.** <a id="s-2"></a>

Severity: **High**, because this is what let a blocker sit in three scripts while the suite stayed green.

Every script test exercises `deploy()` directly:

```solidity
(token, rule) = script.deploy(address(1), address(0));
```

`deploy()` is a plain function call with no broadcast context, so `address(this)` resolves to the script
contract and behaves sensibly. The guard that fires under `forge script` is never reached. The tests are not
weak here so much as aimed at a different execution model than the one the script is used in.

The obvious repair is to call `run()` from a test instead. **It does not work**, and it is worth recording why,
because the failure is not obvious and someone will otherwise try it again:

| Attempt | Result |
| --- | --- |
| `script.run()` from a test | Fails, but with `AccessControlUnauthorizedAccount` rather than the real error. `msg.sender` inside `run()` is the test contract, while broadcast attributes calls to `DEFAULT_SENDER`; the mismatch produces a role failure that is an artefact of the harness. |
| `vm.prank(DEFAULT_SENDER); script.run()` | Prank is consumed by the preceding `new Script()` (a CREATE), so nothing changes. |
| Construct the script first, then prank, then `run()` | `vm.startBroadcast: you have an active prank; broadcasting and pranks are not compatible` |

Foundry refuses to combine a prank with a broadcast, so a test can never present itself to `run()` as the
broadcaster. Confirming the point: script 4, which **does** work under `forge script`, fails all three of
these attempts too. A test built this way would report the working script as broken.

**Fix.** The only faithful harness is `forge script` itself, in CI. It needs no network and no key:

```yaml
- name: Deployment scripts (dry run)
  run: |
    for s in script/*.s.sol; do
      name=$(basename "$s" .s.sol)
      forge script "$s:$name"
    done
```

This is currently absent. `.github/workflows/test.yml` runs `forge build --sizes` and `forge test` on both
profiles; `forge build` compiles the scripts but never executes them, which is why a runtime-only guard slipped
through. Keep the existing unit tests for wiring and role assertions, and add this step for the execution model.

---

## S-3

**`DeployCMTATWithWhitelist` deploys a token that cannot be minted.** <a id="s-3"></a>

Severity: Medium. Recoverable, but the script's output does not do the first thing an issuer needs.

```solidity
rule = new RuleWhitelist(admin, address(0), checkSpender, false);
//                                                        ^^^^^ allowMintBurn
```

With `allowMintBurn = false`, mint is rejected regardless of the whitelist. Measured on a token deployed by
this script, minting to an investor who **is** whitelisted:

```
MINT REVERTED
detectTransferRestriction(address(0) -> investor): 24   // CODE_MINT_NOT_ALLOWED
```

This is the rule behaving exactly as designed (invariant I-12: mint permission is an explicit flag, and
`address(0)` never enters the list). The problem is the script choosing the restrictive value silently, with
no comment, no parameter, and no test covering issuance. An operator following the script gets a
whitelist-gated token that cannot be issued, and the restriction code points at the rule rather than at the
deployment choice.

The state is recoverable: `setAllowMint(true)` and `setAllowBurn(true)` exist on `RuleWhitelistShared`,
guarded by `onlyMintBurnManager`. So this is friction and a support burden, not a bricked deployment.

**Fix.** Take `allowMintBurn` as a `deploy()` parameter, default it to `true` in `run()`, and add a test that
mints to a whitelisted address after deployment. Whichever default is chosen, state it in a comment: the value
determines whether the token can be issued at all.

---

## S-4

**The CMTAT constructor block is copy-pasted four times.** <a id="s-4"></a>

Severity: Medium (maintenance).

All four scripts open with the same twelve lines, identical down to the document hash:

```solidity
ICMTATConstructor.ERC20Attributes memory erc20Attributes =
    ICMTATConstructor.ERC20Attributes("CMTA Token", "CMTAT", 0);
ICMTATConstructor.ExtraInformationAttributes memory extraInformationAttributes =
    ICMTATConstructor.ExtraInformationAttributes(
        "CMTAT_ISIN",
        IERC1643CMTAT.DocumentInfo(
            "Terms", "https://cmta.ch", 0x9ff867f6592aa9d6d039e7aad6bd71f1659720cbc4dd9eae1554f6eab490098b
        ),
        "CMTAT_info"
    );
ICMTATConstructor.Engine memory engines = ICMTATConstructor.Engine(IRuleEngine(address(0)));
```

Each of `"CMTA Token"`, `"CMTAT"`, `"CMTAT_ISIN"`, the URL and the hash appears in four places. A CMTAT
constructor change means four edits, and the failure mode of missing one is a script that still compiles.
The pattern also spread as the newest script was written from the previous one, so it grows with the
directory.

**Fix.** A shared base contract, which also gives the metadata a single place to be configured (S-5):

```solidity
// script/base/CMTATDeploymentBase.sol
abstract contract CMTATDeploymentBase is Script {
    function _defaultTokenAttributes()
        internal
        pure
        virtual
        returns (ICMTATConstructor.ERC20Attributes memory, ICMTATConstructor.ExtraInformationAttributes memory)
    { /* the block above */ }
}
```

Scripts then inherit and call it, and a script needing different metadata overrides one function.

---

## S-5

**Every parameter is hard-coded; there is no environment configuration.** <a id="s-5"></a>

Severity: Medium (usability).

No script reads `vm.envAddress`, `vm.envUint` or `vm.envString`; there are zero occurrences across the
directory. `run()` bakes in every value it does not take from `msg.sender`:

| Value | Hard-coded as | Consequence |
| --- | --- | --- |
| Token name / symbol | `"CMTA Token"` / `"CMTAT"` | Every deployment is named after the example |
| Decimals | `0` | Correct for CMTA equity, wrong for most other instruments |
| ISIN, document URL, document hash | example constants | Ships placeholder legal metadata on-chain |
| Forwarder | `address(0)` | Meta-transactions cannot be enabled without editing source |
| Sanctions oracle | `address(0)` | Screening disabled, see S-11 |
| Max total supply (script 4) | `1_000_000` | Cap unrelated to the actual issuance |

Any real deployment means editing the script, which puts a local modification in the way of every use and
makes the committed version a template rather than a tool.

**Fix.** Read from the environment with documented fallbacks, so the scripts stay runnable out of the box:

```solidity
string memory name = vm.envOr("CMTAT_NAME", string("CMTA Token"));
uint256 cap = vm.envOr("CMTAT_MAX_SUPPLY", uint256(1_000_000));
address oracle = vm.envOr("SANCTIONS_ORACLE", address(0));
```

`vm.envOr` keeps the current behaviour when nothing is set, so this is additive. Pair it with a short table in
the README listing the variables.

---

## S-6

**`forwarder` reaches the token but is silently dropped for the rules.** <a id="s-6"></a>

Severity: Low (inconsistency).

Scripts 1 to 3 accept a `forwarder` argument, pass it to the token and to the `RuleEngine`, then hard-code
`address(0)` for every rule:

```solidity
// script 3: forwarder honoured here...
ruleEngine = new RuleEngine(address(this), forwarder, address(token));
// ...and discarded here
ruleBlacklist = new RuleBlacklist(admin, address(0));
ruleSanctionsList = new RuleSanctionsList(admin, address(0), sanctionsOracle);
```

Script 4 passes `forwarder` through to the rules instead. So the four scripts disagree, and neither behaviour
is documented.

The effect is narrow but real. A rule's forwarder governs meta-transactions on its **admin** surface, which is
list management (`addAddress`, `removeAddress`, `setSanctionListOracle`). With `address(0)`, an operator who
set up ERC-2771 for the token finds that whitelist and blacklist maintenance still requires a funded key,
which is usually the opposite of the intent.

**Fix.** Pass `forwarder` through consistently, as script 4 does. If some rule should deliberately not accept
meta-transactions, say so in a comment at that call site rather than leaving a bare `address(0)`.

---

## S-7

**`bytes32(0)` instead of `DEFAULT_ADMIN_ROLE`.** <a id="s-7"></a>

Severity: Low (readability). Twelve sites across all four scripts:

```solidity
token.grantRole(bytes32(0), admin);
token.renounceRole(bytes32(0), address(this));
```

`AccessControl.DEFAULT_ADMIN_ROLE` is a public constant equal to `0x00`, so the two compile identically. The
literal makes the most security-relevant lines in each script the least readable, and a reviewer scanning for
role hand-over has nothing to grep for. Same value, named:

```solidity
token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
```

---

## S-8

**Deployed addresses are never logged.** <a id="s-8"></a>

Severity: Low (observability). No script imports `console`.

`forge script` prints the return values, so the addresses are recoverable from the run output, and the
broadcast JSON under `broadcast/` records them. But the output is positional: script 4 returns five contracts
as an unlabelled tuple, and matching each address to its role means reading the signature. A few lines make
the run self-describing and the terminal output copy-pasteable into a deployment record:

```solidity
console.log("CMTAT token       ", address(token));
console.log("RuleEngine        ", address(ruleEngine));
console.log("RuleBlacklist     ", address(ruleBlacklist));
```

---

## S-9

**Scripts 1 and 2 carry no NatSpec.** <a id="s-9"></a>

Severity: Low (documentation). Measured comment tags per script:

| Script | NatSpec tags |
| --- | --- |
| `DeployCMTATWithBlacklist` | 0 |
| `DeployCMTATWithWhitelist` | 0 |
| `DeployCMTATWithBlacklistAndSanctionsList` | 2 (a title block, no `@param`) |
| `DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply` | 19 |

Scripts 1 and 2 document neither the parameters, nor the deployment order, nor the fact that they bind the
rule directly rather than through a RuleEngine (S-12). `checkSpender` and `allowMintBurn` in the whitelist
script are two bare booleans at a call site, one of which decides whether the token can be issued (S-3).

Per the project convention, use `/** */` blocks rather than `///`.

---

## S-10

**The single assertion in scripts 1 and 2 skips the admin hand-over.** <a id="s-10"></a>

Severity: Low (test coverage). The whole test is:

```solidity
(CMTATStandardStandalone token, RuleBlacklist rule) = _deploy(script);
assertEq(address(token.ruleEngine()), address(rule));
```

Coverage across the directory is lopsided:

| Test file | Tests | Assertions |
| --- | --- | --- |
| `DeployCMTATWithBlacklist.t.sol` | 1 | 1 |
| `DeployCMTATWithWhitelist.t.sol` | 1 | 1 |
| `DeployCMTATWithBlacklistAndSanctionsList.t.sol` | 18 | 13 |
| `DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply.t.sol` | 19 | 35 |

The assertion checks the wiring, which is the easy half. It does not check the part that matters most: that
`admin` ended up with `DEFAULT_ADMIN_ROLE` and that the deployer no longer holds it. That branch does execute
in the test, since `admin` is `address(1)` and the script contract is not, so a hand-over that silently failed
would leave the deployer as a permanent admin and the test would still pass.

**Fix.** Two assertions per script, matching what scripts 3 and 4 already do:

```solidity
assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(script)));
```

Add the mint path from S-3 to the whitelist test while there.

---

## S-11

**Only script 4 warns that an unset sanctions oracle fails open.** <a id="s-11"></a>

Severity: Info. Script 3 says what the parameter does, not what it costs:

```solidity
// Pass address(0) for sanctionsOracle to deploy without an oracle configured.
// The oracle can be set post-deployment via RuleSanctionsList.setSanctionListOracle().
```

Accurate, and it omits that until that call happens `RuleSanctionsList` passes **every** transfer. The
deployment looks complete, the rule is registered in the engine and reports no error, and screening is off.
Script 4 states this in both `@param` and `@dev`. Worth carrying over verbatim, since the default value is the
unsafe one and the script is what an operator reads.

---

## S-12

**The set silently mixes both integration topologies.** <a id="s-12"></a>

Severity: Info. Scripts 1 and 2 bind the rule straight to the token:

```solidity
token.setRuleEngine(IRuleEngine(address(rule)));   // Topology B
```

Scripts 3 and 4 go through a `RuleEngine`. Both are supported and documented in `CLAUDE.md`, and the choice
changes what `msg.sender` is inside a rule, which matters as soon as an operation rule is added. Neither
script mentions which one it uses or why.

For the validation rules deployed here the distinction is harmless. It stops being harmless the moment someone
copies script 1 as the starting point for a deployment involving `RuleConditionalTransferLightMultiToken`,
which is direct-binding-only, or `RuleMintAllowance`, which is not. One line of NatSpec per script naming the
topology would make the scripts self-documenting on the point most likely to be got wrong.

---

## Checked and not a problem

Recorded so the negative results are not re-investigated.

**`admin == address(0)` does not brick a deployment.** The hand-over grants to `admin` then renounces, so a
zero admin would in principle leave a contract with no administrator. It cannot happen: the rule constructor
rejects it first.

```
deploy(address(0), address(0))
  → revert AccessControlModuleStandalone_AddressZeroNotAllowed()
```

No guard needs to be added to the scripts.

**Script 4's two remaining `address(this)` occurrences are prose.** Both sit inside the `@dev` block that
explains why the deployer is passed explicitly, not in executable code. Confirmed by the successful
`forge script` run.

## What was implemented

`script/base/CMTATDeploymentBase.sol` is new: it holds the shared token metadata (S-4), the environment
configuration (S-5), and the `_logDeployment` helper (S-8). All four scripts inherit it.

**The regression guard was verified rather than assumed.** With `address(this)` reintroduced into
`DeployCMTATWithBlacklist.run()`:

| Check | Result |
| --- | --- |
| `forge test` on that script's suite | 6 passed, 0 failed — the bug is invisible |
| The new `forge script` dry-run step | **fails** |

That is the split the CI step exists for, and it confirms S-2's central claim: no unit test covers this,
because Foundry will not let one run `run()` in a broadcast context.

Environment configuration was checked against a live deploy: with nothing set the token is still
`CMTA Token` / `CMTAT`, and with `CMTAT_NAME` / `CMTAT_SYMBOL` set it picks them up.

## Suggested order of work

*(Kept for the record; all of it is now done.)*

1. **S-1** — three scripts do not work. Everything else is cosmetic next to it.
2. **S-2** — add the CI dry-run step in the same change, so S-1 cannot recur silently.
3. **S-3** — a whitelist token that cannot be minted will be reported as a bug in the rule.
4. **S-10 and S-9** — cheap, and they make the remaining work safer to do.
5. **S-4 and S-5** — the shared base and environment configuration land naturally together.
6. **S-6, S-7, S-8, S-11, S-12** — consistency and documentation.

Items 1 to 3 are the ones that change whether the scripts work. The rest change how pleasant they are to
maintain.
