# Slither Report — `v0.4.0`

```bash
slither . --checklist --filter-paths "node_modules,submodules,test,forge-std,mocks,lib"
```

Tool: **Slither 0.11.5** · Scope: production contracts only (**mocks excluded**) · 168 contracts, 101 detectors, 36 results
Run date: 2026-07-14 (re-run after the v0.4.0 security remediation)

**Result: 2 High · 6 Medium · 16 Low · 12 Informational.**

| Detector | Severity | Instances | Assessment |
|---|---|---|---|
| `arbitrary-send-erc20` | **High** | 2 | **False positive** — `approveAndTransferIfAllowed` is gated by `onlyTransferApprover`, a recorded approval, an allowance check, and a bound token |
| `unused-return` | Medium | 6 | False positive — `EnumerableSet` add/remove returns are guaranteed by outer pre-checks |
| `calls-loop` | Low | 16 | By design — the wrapper's child-rule scan and batch list ops; cost model documented |
| `assembly` | Info | 2 | By design — the reviewed, `memory-safe` `_transferHash` keccak preimage |
| `naming-convention` | Info | 2 | By design — names are fixed by the ERC-2980 / ERC-3643 specs |
| `unused-state` | Info | 8 | False positive — per-contract analysis misses selectors consumed by inherited dispatch |

**Nothing to fix.** The two High hits are false positives; every other finding is by-design or a tool limitation — triaged individually in the feedback file.

Full triage: [slither-report-feedback.md](./slither-report-feedback.md) · Overview: [AUDIT_OVERVIEW.md](../../AUDIT_OVERVIEW.md) · Manual audit: [CLAUDE_AUDIT.md](./claude-audit/CLAUDE_AUDIT.md)

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
[RuleConditionalTransferLightMultiTokenBase.approveAndTransferIfAllowed(address,address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L126-L142) uses arbitrary from in transferFrom: [IERC20(token).safeTransferFrom(from,to,value)](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L140)

src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L126-L142


 - [ ] ID-1
[RuleConditionalTransferLightBase.approveAndTransferIfAllowed(address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightBase.sol#L113-L128) uses arbitrary from in transferFrom: [IERC20(token).safeTransferFrom(from,to,value)](src/rules/operation/abstract/RuleConditionalTransferLightBase.sol#L126)

src/rules/operation/abstract/RuleConditionalTransferLightBase.sol#L113-L128


## unused-return
Impact: Medium
Confidence: Medium
 - [ ] ID-2
[RuleERC2980Internal._removeWhitelistAddress(address)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L91-L93) ignores return value by [_whitelist.remove(targetAddress)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L92)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L91-L93


 - [ ] ID-3
[RuleAddressSetInternal._addAddress(address)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L84-L86) ignores return value by [_listedAddresses.add(targetAddress)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L85)

src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L84-L86


 - [ ] ID-4
[RuleERC2980Internal._removeFrozenlistAddress(address)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L152-L154) ignores return value by [_frozenlist.remove(targetAddress)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L153)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L152-L154


 - [ ] ID-5
[RuleAddressSetInternal._removeAddress(address)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L92-L94) ignores return value by [_listedAddresses.remove(targetAddress)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L93)

src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L92-L94


 - [ ] ID-6
[RuleERC2980Internal._addFrozenlistAddress(address)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L144-L146) ignores return value by [_frozenlist.add(targetAddress)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L145)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L144-L146


 - [ ] ID-7
[RuleERC2980Internal._addWhitelistAddress(address)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L83-L85) ignores return value by [_whitelist.add(targetAddress)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L84)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L83-L85


## calls-loop
Impact: Low
Confidence: Medium
 - [ ] ID-8
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleWhitelistShared.transferred(address,address,address,uint256)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-9
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(ITransferContext.MultiTokenTransferContext)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-10
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleNFTAdapter.detectTransferRestriction(address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-11
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleTransferValidation.detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-12
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleNFTAdapter.canTransferFrom(address,address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-13
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleWhitelistWrapperHarnessInternal.exposedTransferredSpenderInternal(address,address,address,uint256)
		RuleWhitelistWrapperBase._transferred(address,address,address,uint256)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-14
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(ITransferContext.FungibleTransferContext)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-15
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleTransferValidation.detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-16
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleTransferValidation.canTransferFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-17
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleNFTAdapter.canTransfer(address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-18
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(address,address,address,uint256,uint256)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-19
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleWhitelistWrapperBase.isVerified(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-20
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleTransferValidation.canTransfer(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-21
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleWhitelistShared.transferred(address,address,uint256)
		RuleWhitelistWrapperBase._transferred(address,address,uint256)
		RuleWhitelistShared._transferred(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-22
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(address,address,uint256,uint256)
		RuleWhitelistWrapperBase._transferred(address,address,uint256)
		RuleWhitelistShared._transferred(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


 - [ ] ID-23
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L271)
	Calls stack containing the loop:
		RuleNFTAdapter.detectTransferRestrictionFrom(address,address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L260-L291


## assembly
Impact: Informational
Confidence: High
 - [ ] ID-24
[RuleConditionalTransferLightApprovalBase._transferHash(address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol#L150-L159) uses assembly
	- [INLINE ASM](src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol#L152-L158)

src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol#L150-L159


 - [ ] ID-25
[RuleConditionalTransferLightMultiTokenBase._transferHash(address,address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L441-L455) uses assembly
	- [INLINE ASM](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L447-L454)

src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L441-L455


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-26
Parameter [RuleERC2980Base.frozenlist(address)._operator](src/rules/validation/abstract/base/RuleERC2980Base.sol#L376) is not in mixedCase

src/rules/validation/abstract/base/RuleERC2980Base.sol#L376


 - [ ] ID-27
Parameter [RuleERC2980Base.whitelist(address)._operator](src/rules/validation/abstract/base/RuleERC2980Base.sol#L327) is not in mixedCase

src/rules/validation/abstract/base/RuleERC2980Base.sol#L327


## unused-state
Impact: Informational
Confidence: High
 - [ ] ID-28
[RuleNFTAdapter.TRANSFERRED_SELECTOR_RULE_ENGINE](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L27) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L57)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L27


 - [ ] ID-29
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC7943](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L31-L32) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L57)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L31-L32


 - [ ] ID-30
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC7943_FROM](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L36-L37) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L57)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L36-L37


 - [ ] ID-31
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC3643](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L23) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L57)

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


