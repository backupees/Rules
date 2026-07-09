# Slither Static Analysis — v0.4.0

**Tool:** Slither 0.11.5 · **Date:** 2026-07-08 · **Scope:** production contracts only — **mocks EXCLUDED**
**Command:**

```bash
slither . --checklist --filter-paths "node_modules,lib,test,forge-std,mocks" \
  > doc/security/audits/tools/v0.4.0/slither-report.md
```

**Severity tally:** `2 High · 6 Medium · 16 Low · 12 Info`

| Detector | Severity | Instances | Assessment |
|---|---|---|---|
| arbitrary-send-erc20 | High | 2 | **False positive** — `approveAndTransferIfAllowed` in both `RuleConditionalTransferLightBase` and `RuleConditionalTransferLightMultiTokenBase` is gated by `onlyTransferApprover`, a recorded approval, an allowance check, and a bound token. |
| unused-return | Medium | 6 | **False positive** — `EnumerableSet.add/remove` booleans in internal single-item helpers; the public entrypoints pre-check presence. |
| calls-loop | Low | 16 | **By design** — `RuleWhitelistWrapperBase` must query each child rule to implement OR aggregation (children are read-only). |
| assembly | Info | 2 | **By design** — memory-safe hash assembly in `_transferHash` (light + multi-token variants). |
| naming-convention | Info | 2 | **By design** — `_operator` argument names mirror the ERC-2980 interface. |
| unused-state | Info | 8 | **False positive** — `RuleNFTAdapter` selector constants used via inherited dispatch (per-contract analysis limitation). |

**Bottom line: nothing to fix.** Every finding is a false positive or accepted by design; identical dispositions to `v0.3.0`, with a 2nd instance each of `arbitrary-send-erc20` and `assembly` from the new `RuleConditionalTransferLightMultiToken` contract (same guarded/design patterns).

**See:** [feedback](./slither-report-feedback.md) · [audit overview](../../AUDIT_OVERVIEW.md)

---

**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [arbitrary-send-erc20](#arbitrary-send-erc20) (2 results) (High)
 - [unused-return](#unused-return) (6 results) (Medium)
 - [calls-loop](#calls-loop) (16 results) (Low)
 - [assembly](#assembly) (2 results) (Informational)
 - [naming-convention](#naming-convention) (2 results) (Informational)
 - [unused-state](#unused-state) (8 results) (Informational)
## arbitrary-send-erc20
Impact: High
Confidence: High
 - [ ] ID-0
[RuleConditionalTransferLightBase.approveAndTransferIfAllowed(address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightBase.sol#L86-L101) uses arbitrary from in transferFrom: [IERC20(token).safeTransferFrom(from,to,value)](src/rules/operation/abstract/RuleConditionalTransferLightBase.sol#L99)

src/rules/operation/abstract/RuleConditionalTransferLightBase.sol#L86-L101


 - [ ] ID-1
[RuleConditionalTransferLightMultiTokenBase.approveAndTransferIfAllowed(address,address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L121-L138) uses arbitrary from in transferFrom: [IERC20(token).safeTransferFrom(from,to,value)](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L136)

src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L121-L138


## unused-return
Impact: Medium
Confidence: Medium
 - [ ] ID-2
[RuleAddressSetInternal._removeAddress(address)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L84-L86) ignores return value by [_listedAddresses.remove(targetAddress)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L85)

src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L84-L86


 - [ ] ID-3
[RuleAddressSetInternal._addAddress(address)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L76-L78) ignores return value by [_listedAddresses.add(targetAddress)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L77)

src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L76-L78


 - [ ] ID-4
[RuleERC2980Internal._removeFrozenlistAddress(address)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L145-L147) ignores return value by [_frozenlist.remove(targetAddress)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L146)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L145-L147


 - [ ] ID-5
[RuleERC2980Internal._addFrozenlistAddress(address)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L137-L139) ignores return value by [_frozenlist.add(targetAddress)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L138)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L137-L139


 - [ ] ID-6
[RuleERC2980Internal._removeWhitelistAddress(address)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L87-L89) ignores return value by [_whitelist.remove(targetAddress)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L88)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L87-L89


 - [ ] ID-7
[RuleERC2980Internal._addWhitelistAddress(address)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L79-L81) ignores return value by [_whitelist.add(targetAddress)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L80)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L79-L81


## calls-loop
Impact: Low
Confidence: Medium
 - [ ] ID-8
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L227)
	Calls stack containing the loop:
		RuleNFTAdapter.canTransfer(address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247


 - [ ] ID-9
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L227)
	Calls stack containing the loop:
		RuleWhitelistWrapperBase.isVerified(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247


 - [ ] ID-10
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L227)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(address,address,uint256,uint256)
		RuleWhitelistWrapperBase._transferred(address,address,uint256)
		RuleWhitelistShared._transferred(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247


 - [ ] ID-11
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L227)
	Calls stack containing the loop:
		RuleWhitelistShared.transferred(address,address,address,uint256)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247


 - [ ] ID-12
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L227)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(ITransferContext.MultiTokenTransferContext)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247


 - [ ] ID-13
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L227)
	Calls stack containing the loop:
		RuleNFTAdapter.canTransferFrom(address,address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247


 - [ ] ID-14
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L227)
	Calls stack containing the loop:
		RuleWhitelistShared.transferred(address,address,uint256)
		RuleWhitelistWrapperBase._transferred(address,address,uint256)
		RuleWhitelistShared._transferred(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247


 - [ ] ID-15
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L227)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(ITransferContext.FungibleTransferContext)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247


 - [ ] ID-16
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L227)
	Calls stack containing the loop:
		RuleTransferValidation.canTransfer(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247


 - [ ] ID-17
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L227)
	Calls stack containing the loop:
		RuleNFTAdapter.detectTransferRestrictionFrom(address,address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247


 - [ ] ID-18
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L227)
	Calls stack containing the loop:
		RuleTransferValidation.canTransferFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247


 - [ ] ID-19
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L227)
	Calls stack containing the loop:
		RuleWhitelistWrapperHarnessInternal.exposedTransferredSpenderInternal(address,address,address,uint256)
		RuleWhitelistWrapperBase._transferred(address,address,address,uint256)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247


 - [ ] ID-20
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L227)
	Calls stack containing the loop:
		RuleNFTAdapter.detectTransferRestriction(address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247


 - [ ] ID-21
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L227)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(address,address,address,uint256,uint256)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247


 - [ ] ID-22
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L227)
	Calls stack containing the loop:
		RuleTransferValidation.detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247


 - [ ] ID-23
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L227)
	Calls stack containing the loop:
		RuleTransferValidation.detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L216-L247


## assembly
Impact: Informational
Confidence: High
 - [ ] ID-24
[RuleConditionalTransferLightApprovalBase._transferHash(address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol#L125-L134) uses assembly
	- [INLINE ASM](src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol#L127-L133)

src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol#L125-L134


 - [ ] ID-25
[RuleConditionalTransferLightMultiTokenBase._transferHash(address,address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L334-L348) uses assembly
	- [INLINE ASM](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L340-L347)

src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L334-L348


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-26
Parameter [RuleERC2980Base.frozenlist(address)._operator](src/rules/validation/abstract/base/RuleERC2980Base.sol#L328) is not in mixedCase

src/rules/validation/abstract/base/RuleERC2980Base.sol#L328


 - [ ] ID-27
Parameter [RuleERC2980Base.whitelist(address)._operator](src/rules/validation/abstract/base/RuleERC2980Base.sol#L279) is not in mixedCase

src/rules/validation/abstract/base/RuleERC2980Base.sol#L279


## unused-state
Impact: Informational
Confidence: High
 - [ ] ID-28
[RuleNFTAdapter.TRANSFERRED_SELECTOR_RULE_ENGINE](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L27) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L54)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L27


 - [ ] ID-29
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC7943](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L31-L32) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L54)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L31-L32


 - [ ] ID-30
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC7943_FROM](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L36-L37) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L54)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L36-L37


 - [ ] ID-31
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC3643](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L23) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L54)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L23


 - [ ] ID-32
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC7943](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L31-L32) is never used in [RuleIdentityRegistry](src/rules/validation/deployment/RuleIdentityRegistry.sol#L14-L57)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L31-L32


 - [ ] ID-33
[RuleNFTAdapter.TRANSFERRED_SELECTOR_RULE_ENGINE](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L27) is never used in [RuleIdentityRegistry](src/rules/validation/deployment/RuleIdentityRegistry.sol#L14-L57)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L27


 - [ ] ID-34
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC7943_FROM](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L36-L37) is never used in [RuleIdentityRegistry](src/rules/validation/deployment/RuleIdentityRegistry.sol#L14-L57)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L36-L37


 - [ ] ID-35
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC3643](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L23) is never used in [RuleIdentityRegistry](src/rules/validation/deployment/RuleIdentityRegistry.sol#L14-L57)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L23


