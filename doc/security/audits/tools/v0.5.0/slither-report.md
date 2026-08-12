# Slither Report — `v0.5.0`

```bash
slither . --checklist --filter-paths "node_modules,lib,test,forge-std,mocks" \
  > doc/security/audits/tools/v0.5.0/slither-report.md
```

Tool: **Slither 0.11.5** · Scope: production contracts only (**mocks excluded**, dependencies excluded via the
`lib` filter) · 191 contracts, 101 detectors, 46 results
Run date: 2026-08-11

**Result: 2 High · 11 Medium · 17 Low · 16 Informational. Nothing to fix** — every finding is a false positive,
a by-design pattern, or cosmetic. Verified line-by-line in the
[feedback file](./slither-report-feedback.md).

| Detector | Severity | Instances | Δ vs v0.4.0 | Assessment |
|---|---|---|---|---|
| `arbitrary-send-erc20` | **High** | 2 | — | **False positive** — `approveAndTransferIfAllowed` is gated by `onlyTransferApprover`, a recorded approval, an allowance check and a bound token |
| `uninitialized-local` | Medium | 2 | **new** | **False positive** — `newFeedDecimals` / `currentFeedDecimals` are assigned in the `try` branch; the matching `catch` reverts or returns, so neither can be read unset |
| `unused-return` | Medium | 9 | +3 | False positive / by design — `EnumerableSet` returns are guaranteed by outer pre-checks; the new instances are `try …totalSupply() returns (uint256) {}` probes that deliberately test only for revert |
| `calls-loop` | Low | 16 | — | By design — the wrapper's child-rule scan and batch list ops; cost model documented in `RuleWhitelistWrapper.md` |
| `timestamp` | Low | 1 | **new** | By design — `block.timestamp` is the Proof-of-Reserve staleness check itself; the comparison is underflow-guarded and the threshold is measured in hours, far outside miner drift |
| `assembly` | Informational | 2 | — | By design — `_transferHash` and `_walletKey`, both deliberate per the repo's `asm-keccak256` convention |
| `naming-convention` | Informational | 6 | +4 | By design — `_userAddress` / `_identity` reproduce the ERC-3643 interface parameter names verbatim for signature fidelity |
| `unused-state` | Informational | 8 | — | False positive — ERC-7943 selector constants are read through `RuleNFTAdapter`'s dispatch, not by name |

Feedback and per-finding triage: [`slither-report-feedback.md`](./slither-report-feedback.md) ·
Overview: [`AUDIT_OVERVIEW.md`](../../AUDIT_OVERVIEW.md)

---

**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [arbitrary-send-erc20](#arbitrary-send-erc20) (2 results) (High)
 - [uninitialized-local](#uninitialized-local) (2 results) (Medium)
 - [unused-return](#unused-return) (9 results) (Medium)
 - [calls-loop](#calls-loop) (16 results) (Low)
 - [timestamp](#timestamp) (1 results) (Low)
 - [assembly](#assembly) (2 results) (Informational)
 - [naming-convention](#naming-convention) (6 results) (Informational)
 - [unused-state](#unused-state) (8 results) (Informational)
## arbitrary-send-erc20
Impact: High
Confidence: High
 - [ ] ID-0
[RuleConditionalTransferLightMultiTokenBase.approveAndTransferIfAllowed(address,address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L126-L142) uses arbitrary from in transferFrom: [IERC20(token).safeTransferFrom(from,to,value)](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L140)

src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L126-L142


 - [ ] ID-1
[RuleConditionalTransferLightBase.approveAndTransferIfAllowed(address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightBase.sol#L113-L128) uses arbitrary from in transferFrom: [IERC20(token).safeTransferFrom(from,to,value)](src/rules/operation/abstract/RuleConditionalTransferLightBase.sol#L126)

src/rules/operation/abstract/RuleConditionalTransferLightBase.sol#L113-L128


## uninitialized-local
Impact: Medium
Confidence: Medium
 - [ ] ID-2
[RuleChainlinkPoRBase._setReservesFeed(AggregatorV3Interface).newFeedDecimals](src/rules/validation/abstract/base/RuleChainlinkPoRBase.sol#L216) is a local variable never initialized

src/rules/validation/abstract/base/RuleChainlinkPoRBase.sol#L216


 - [ ] ID-3
[RuleChainlinkPoRBase._maxBackedSupply().currentFeedDecimals](src/rules/validation/abstract/base/RuleChainlinkPoRBase.sol#L286) is a local variable never initialized

src/rules/validation/abstract/base/RuleChainlinkPoRBase.sol#L286


## unused-return
Impact: Medium
Confidence: Medium
 - [ ] ID-4
[RuleERC2980Internal._removeWhitelistAddress(address)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L91-L93) ignores return value by [_whitelist.remove(targetAddress)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L92)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L91-L93


 - [ ] ID-5
[RuleAddressSetInternal._addAddress(address)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L84-L86) ignores return value by [_listedAddresses.add(targetAddress)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L85)

src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L84-L86


 - [ ] ID-6
[RuleMaxTotalSupplyBase._validateTokenContract(address)](src/rules/validation/abstract/base/RuleMaxTotalSupplyBase.sol#L135-L142) ignores return value by [ITotalSupply(candidate).totalSupply()](src/rules/validation/abstract/base/RuleMaxTotalSupplyBase.sol#L138-L141)

src/rules/validation/abstract/base/RuleMaxTotalSupplyBase.sol#L135-L142


 - [ ] ID-7
[RuleERC2980Internal._removeFrozenlistAddress(address)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L152-L154) ignores return value by [_frozenlist.remove(targetAddress)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L153)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L152-L154


 - [ ] ID-8
[RuleAddressSetInternal._removeAddress(address)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L92-L94) ignores return value by [_listedAddresses.remove(targetAddress)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L93)

src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L92-L94


 - [ ] ID-9
[RuleChainlinkPoRBase._setTokenMetadata(address,uint8)](src/rules/validation/abstract/base/RuleChainlinkPoRBase.sol#L235-L259) ignores return value by [ITotalSupply(newTokenContract).totalSupply()](src/rules/validation/abstract/base/RuleChainlinkPoRBase.sol#L252-L255)

src/rules/validation/abstract/base/RuleChainlinkPoRBase.sol#L235-L259


 - [ ] ID-10
[RuleERC2980Internal._addFrozenlistAddress(address)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L144-L146) ignores return value by [_frozenlist.add(targetAddress)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L145)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L144-L146


 - [ ] ID-11
[RuleERC2980Internal._addWhitelistAddress(address)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L83-L85) ignores return value by [_whitelist.add(targetAddress)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L84)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L83-L85


 - [ ] ID-12
[RuleChainlinkPoRBase._maxBackedSupply()](src/rules/validation/abstract/base/RuleChainlinkPoRBase.sol#L282-L313) ignores return value by [(answer,updatedAt) = feed.latestRoundData()](src/rules/validation/abstract/base/RuleChainlinkPoRBase.sol#L297-L312)

src/rules/validation/abstract/base/RuleChainlinkPoRBase.sol#L282-L313


## calls-loop
Impact: Low
Confidence: Medium
 - [ ] ID-13
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleWhitelistShared.transferred(address,address,address,uint256)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-14
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(ITransferContext.MultiTokenTransferContext)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-15
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleNFTAdapter.detectTransferRestriction(address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-16
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleTransferValidation.detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-17
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleNFTAdapter.canTransferFrom(address,address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-18
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleWhitelistWrapperHarnessInternal.exposedTransferredSpenderInternal(address,address,address,uint256)
		RuleWhitelistWrapperBase._transferred(address,address,address,uint256)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-19
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(ITransferContext.FungibleTransferContext)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-20
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleTransferValidation.detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-21
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleTransferValidation.canTransferFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-22
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleNFTAdapter.canTransfer(address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-23
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(address,address,address,uint256,uint256)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-24
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleWhitelistWrapperBase.isVerified(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-25
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleTransferValidation.canTransfer(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-26
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleWhitelistShared.transferred(address,address,uint256)
		RuleWhitelistWrapperBase._transferred(address,address,uint256)
		RuleWhitelistShared._transferred(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-27
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(address,address,uint256,uint256)
		RuleWhitelistWrapperBase._transferred(address,address,uint256)
		RuleWhitelistShared._transferred(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-28
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleNFTAdapter.detectTransferRestrictionFrom(address,address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


## timestamp
Impact: Low
Confidence: Medium
 - [ ] ID-29
[RuleChainlinkPoRBase._maxBackedSupply()](src/rules/validation/abstract/base/RuleChainlinkPoRBase.sol#L282-L313) uses timestamp for comparisons
	Dangerous comparisons:
	- [staleness != 0 && block.timestamp > updatedAt && block.timestamp - updatedAt > staleness](src/rules/validation/abstract/base/RuleChainlinkPoRBase.sol#L303)

src/rules/validation/abstract/base/RuleChainlinkPoRBase.sol#L282-L313


## assembly
Impact: Informational
Confidence: High
 - [ ] ID-30
[RuleConditionalTransferLightApprovalBase._transferHash(address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol#L150-L159) uses assembly
	- [INLINE ASM](src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol#L152-L158)

src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol#L150-L159


 - [ ] ID-31
[RuleConditionalTransferLightMultiTokenBase._transferHash(address,address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L441-L455) uses assembly
	- [INLINE ASM](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L447-L454)

src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L441-L455


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-32
Parameter [RuleERC2980Base.frozenlist(address)._operator](src/rules/validation/abstract/base/RuleERC2980Base.sol#L376) is not in mixedCase

src/rules/validation/abstract/base/RuleERC2980Base.sol#L376


 - [ ] ID-33
Parameter [IdentityRegistryWhitelistBase.isVerified(address)._userAddress](src/registry/abstract/IdentityRegistryWhitelistBase.sol#L119) is not in mixedCase

src/registry/abstract/IdentityRegistryWhitelistBase.sol#L119


 - [ ] ID-34
Parameter [IdentityRegistryWhitelistBase.deleteIdentity(address)._userAddress](src/registry/abstract/IdentityRegistryWhitelistBase.sol#L93) is not in mixedCase

src/registry/abstract/IdentityRegistryWhitelistBase.sol#L93


 - [ ] ID-35
Parameter [RuleERC2980Base.whitelist(address)._operator](src/rules/validation/abstract/base/RuleERC2980Base.sol#L327) is not in mixedCase

src/rules/validation/abstract/base/RuleERC2980Base.sol#L327


 - [ ] ID-36
Parameter [IdentityRegistryWhitelistBase.registerIdentity(address,address,uint16)._identity](src/registry/abstract/IdentityRegistryWhitelistBase.sol#L73) is not in mixedCase

src/registry/abstract/IdentityRegistryWhitelistBase.sol#L73


 - [ ] ID-37
Parameter [IdentityRegistryWhitelistBase.registerIdentity(address,address,uint16)._userAddress](src/registry/abstract/IdentityRegistryWhitelistBase.sol#L72) is not in mixedCase

src/registry/abstract/IdentityRegistryWhitelistBase.sol#L72


## unused-state
Impact: Informational
Confidence: High
 - [ ] ID-38
[RuleNFTAdapter.TRANSFERRED_SELECTOR_RULE_ENGINE](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L27) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L27


 - [ ] ID-39
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC7943](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L31-L32) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L31-L32


 - [ ] ID-40
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC7943_FROM](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L36-L37) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L36-L37


 - [ ] ID-41
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC3643](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L23) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L23


 - [ ] ID-42
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC7943](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L31-L32) is never used in [RuleIdentityRegistry](src/rules/validation/deployment/RuleIdentityRegistry.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L31-L32


 - [ ] ID-43
[RuleNFTAdapter.TRANSFERRED_SELECTOR_RULE_ENGINE](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L27) is never used in [RuleIdentityRegistry](src/rules/validation/deployment/RuleIdentityRegistry.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L27


 - [ ] ID-44
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC7943_FROM](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L36-L37) is never used in [RuleIdentityRegistry](src/rules/validation/deployment/RuleIdentityRegistry.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L36-L37


 - [ ] ID-45
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC3643](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L23) is never used in [RuleIdentityRegistry](src/rules/validation/deployment/RuleIdentityRegistry.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L23


