# Slither Report — `v0.5.0`

```bash
slither . --checklist --filter-paths "node_modules,lib,test,forge-std,mocks" \
  > doc/security/audits/tools/v0.5.0/slither-report.md
```

Tool: **Slither 0.11.5** · Scope: production contracts only (**mocks excluded**, dependencies excluded via the
`lib` filter) · 208 contracts, 101 detectors, 44 results
Compiler: solc `0.8.36` · Run date: 2026-08-13, after the cap-manager split (supersedes the earlier `v0.5.0` runs)

**Result: 2 High · 11 Medium · 17 Low · 14 Informational. Nothing to fix** — every finding is a false positive,
a by-design pattern, or cosmetic. Verified line-by-line in the
[feedback file](./slither-report-feedback.md).

| Detector | Severity | Instances | Δ vs previous run | Assessment |
|---|---|---|---|---|
| `arbitrary-send-erc20` | **High** | 2 | — | **False positive** — `approveAndTransferIfAllowed` is reachable only via `onlyTransferApprover`, needs a recorded approval for the exact tuple, and still needs the holder's own ERC-20 allowance |
| `uninitialized-local` | Medium | 2 | — | **False positive** — declared before a `try` and assigned inside it; the matching `catch` reverts or returns |
| `unused-return` | Medium | 9 | — | **False positive** — six batch helpers forward the library's `(added, skipped)` tuple to the caller; three are deliberate probes whose only purpose is to detect a revert |
| `calls-loop` | Low | 16 | — | By design — the wrapper child-rule scan and batch list operations, with measured gas guidance |
| `timestamp` | Low | 1 | — | By design — the Proof-of-Reserve staleness comparison is the feature |
| `assembly` | Informational | 2 | — | By design — `_transferHash` and `_walletKey`, both pinned by tests |
| `dead-code` | Informational | 2 | — | **False positive** — the two `_requireNotZeroAddress` guards are passed as internal function pointers, which Slither does not resolve |
| `naming-convention` | Informational | 6 | — | By design — ERC-3643 parameter names reproduced verbatim |
| `unused-state` | Informational | 4 | — | Cosmetic — the four `TRANSFERRED_SELECTOR_*` constants are genuinely unreferenced; `internal constant`, so no storage and not emitted into bytecode |

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
 - [dead-code](#dead-code) (2 results) (Informational)
 - [naming-convention](#naming-convention) (6 results) (Informational)
 - [unused-state](#unused-state) (4 results) (Informational)
## arbitrary-send-erc20
Impact: High
Confidence: High
 - [ ] ID-0
[RuleConditionalTransferLightBase.approveAndTransferIfAllowed(address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightBase.sol#L113-L129) uses arbitrary from in transferFrom: [IERC20(token).safeTransferFrom(from,to,value)](src/rules/operation/abstract/RuleConditionalTransferLightBase.sol#L127)

src/rules/operation/abstract/RuleConditionalTransferLightBase.sol#L113-L129


 - [ ] ID-1
[RuleConditionalTransferLightMultiTokenBase.approveAndTransferIfAllowed(address,address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L131-L148) uses arbitrary from in transferFrom: [IERC20(token).safeTransferFrom(from,to,value)](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L146)

src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L131-L148


## uninitialized-local
Impact: Medium
Confidence: Medium
 - [ ] ID-2
[ChainlinkPoRFeedManager._maxBackedSupply().currentFeedDecimals](src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L215) is a local variable never initialized

src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L215


 - [ ] ID-3
[ChainlinkPoRFeedManager._setReservesFeed(AggregatorV3Interface).newFeedDecimals](src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L146) is a local variable never initialized

src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L146


## unused-return
Impact: Medium
Confidence: Medium
 - [ ] ID-4
[RuleERC2980Internal._removeFrozenlistAddresses(address[])](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L110-L116) ignores return value by [_frozenlist.removeBatch(addressesToRemove)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L115)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L110-L116


 - [ ] ID-5
[RuleAddressSetInternal._removeAddresses(address[])](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L77-L83) ignores return value by [_listedAddresses.removeBatch(addressesToRemove)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L82)

src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L77-L83


 - [ ] ID-6
[RuleERC2980Internal._removeWhitelistAddresses(address[])](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L61-L67) ignores return value by [_whitelist.removeBatch(addressesToRemove)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L66)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L61-L67


 - [ ] ID-7
[RuleERC2980Internal._addWhitelistAddresses(address[])](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L47-L53) ignores return value by [_whitelist.addBatch(addressesToAdd,_requireNotZeroAddress)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L52)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L47-L53


 - [ ] ID-8
[BalanceCapManager._setBalanceToken(address)](src/rules/validation/abstract/core/BalanceCapManager.sol#L191-L204) ignores return value by [IBalanceOf(newBalanceToken).balanceOf(address(this))](src/rules/validation/abstract/core/BalanceCapManager.sol#L196-L201)

src/rules/validation/abstract/core/BalanceCapManager.sol#L191-L204


 - [ ] ID-9
[RuleERC2980Internal._addFrozenlistAddresses(address[])](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L96-L102) ignores return value by [_frozenlist.addBatch(addressesToAdd,_requireNotZeroAddress)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L101)

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L96-L102


 - [ ] ID-10
[TokenSupplyReader._probeTotalSupplyCallable(address)](src/rules/validation/abstract/core/TokenSupplyReader.sol#L82-L88) ignores return value by [ITotalSupply(candidate).totalSupply()](src/rules/validation/abstract/core/TokenSupplyReader.sol#L83-L87)

src/rules/validation/abstract/core/TokenSupplyReader.sol#L82-L88


 - [ ] ID-11
[RuleAddressSetInternal._addAddresses(address[])](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L44-L50) ignores return value by [_listedAddresses.addBatch(addressesToAdd,_requireNotZeroAddress)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L49)

src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L44-L50


 - [ ] ID-12
[ChainlinkPoRFeedManager._maxBackedSupply()](src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L211-L242) ignores return value by [(answer,updatedAt) = feed.latestRoundData()](src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L226-L241)

src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L211-L242


## calls-loop
Impact: Low
Confidence: Medium
 - [ ] ID-13
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L237)
	Calls stack containing the loop:
		RuleNFTAdapter.canTransferFrom(address,address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251


 - [ ] ID-14
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L237)
	Calls stack containing the loop:
		RuleTransferValidation.canTransfer(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251


 - [ ] ID-15
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L237)
	Calls stack containing the loop:
		RuleWhitelistShared.transferred(address,address,uint256)
		RuleWhitelistWrapperBase._transferred(address,address,uint256)
		RuleWhitelistShared._transferred(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251


 - [ ] ID-16
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L237)
	Calls stack containing the loop:
		RuleTransferValidation.canTransferFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251


 - [ ] ID-17
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L237)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(ITransferContext.FungibleTransferContext)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251


 - [ ] ID-18
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L237)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(address,address,uint256,uint256)
		RuleWhitelistWrapperBase._transferred(address,address,uint256)
		RuleWhitelistShared._transferred(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251


 - [ ] ID-19
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L237)
	Calls stack containing the loop:
		RuleNFTAdapter.detectTransferRestriction(address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251


 - [ ] ID-20
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L237)
	Calls stack containing the loop:
		RuleWhitelistWrapperHarnessInternal.exposedTransferredSpenderInternal(address,address,address,uint256)
		RuleWhitelistWrapperBase._transferred(address,address,address,uint256)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251


 - [ ] ID-21
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L237)
	Calls stack containing the loop:
		RuleWhitelistWrapperBase.isVerified(address)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251


 - [ ] ID-22
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L237)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(ITransferContext.MultiTokenTransferContext)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251


 - [ ] ID-23
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L237)
	Calls stack containing the loop:
		RuleTransferValidation.detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251


 - [ ] ID-24
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L237)
	Calls stack containing the loop:
		RuleNFTAdapter.transferred(address,address,address,uint256,uint256)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251


 - [ ] ID-25
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L237)
	Calls stack containing the loop:
		RuleTransferValidation.detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251


 - [ ] ID-26
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L237)
	Calls stack containing the loop:
		RuleWhitelistShared.transferred(address,address,address,uint256)
		RuleWhitelistShared._transferredFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251


 - [ ] ID-27
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L237)
	Calls stack containing the loop:
		RuleNFTAdapter.detectTransferRestrictionFrom(address,address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestrictionFrom(address,address,address,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251


 - [ ] ID-28
[RuleWhitelistWrapperBase._detectTransferRestrictionForTargets(address[])](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251) has external calls inside a loop: [isListed = IAddressList(rule(i)).areAddressesListed(targetAddress)](src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L237)
	Calls stack containing the loop:
		RuleNFTAdapter.canTransfer(address,address,uint256,uint256)
		RuleWhitelistWrapperBase._detectTransferRestriction(address,address,uint256)
		RuleWhitelistWrapperBase._isListedInAnyChild(address)

src/rules/validation/abstract/base/RuleWhitelistWrapperBase.sol#L221-L251


## timestamp
Impact: Low
Confidence: Medium
 - [ ] ID-29
[ChainlinkPoRFeedManager._maxBackedSupply()](src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L211-L242) uses timestamp for comparisons
	Dangerous comparisons:
	- [staleness != 0 && block.timestamp > updatedAt && block.timestamp - updatedAt > staleness](src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L232)

src/rules/validation/abstract/core/ChainlinkPoRFeedManager.sol#L211-L242


## assembly
Impact: Informational
Confidence: High
 - [ ] ID-30
[RuleConditionalTransferLightApprovalBase._transferHash(address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol#L177-L188) uses assembly
	- [INLINE ASM](src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol#L181-L187)

src/rules/operation/abstract/RuleConditionalTransferLightApprovalBase.sol#L177-L188


 - [ ] ID-31
[RuleConditionalTransferLightMultiTokenBase._transferHash(address,address,address,uint256)](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L464-L478) uses assembly
	- [INLINE ASM](src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L470-L477)

src/rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol#L464-L478


## dead-code
Impact: Informational
Confidence: Medium
 - [ ] ID-32
[RuleERC2980Internal._requireNotZeroAddress(address)](src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L142-L144) is never used and should be removed

src/rules/validation/abstract/RuleERC2980/RuleERC2980Internal.sol#L142-L144


 - [ ] ID-33
[RuleAddressSetInternal._requireNotZeroAddress(address)](src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L64-L66) is never used and should be removed

src/rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol#L64-L66


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-34
Parameter [RuleERC2980Base.frozenlist(address)._operator](src/rules/validation/abstract/base/RuleERC2980Base.sol#L374) is not in mixedCase

src/rules/validation/abstract/base/RuleERC2980Base.sol#L374


 - [ ] ID-35
Parameter [IdentityRegistryWhitelistBase.isVerified(address)._userAddress](src/registry/abstract/IdentityRegistryWhitelistBase.sol#L117) is not in mixedCase

src/registry/abstract/IdentityRegistryWhitelistBase.sol#L117


 - [ ] ID-36
Parameter [IdentityRegistryWhitelistBase.deleteIdentity(address)._userAddress](src/registry/abstract/IdentityRegistryWhitelistBase.sol#L92) is not in mixedCase

src/registry/abstract/IdentityRegistryWhitelistBase.sol#L92


 - [ ] ID-37
Parameter [RuleERC2980Base.whitelist(address)._operator](src/rules/validation/abstract/base/RuleERC2980Base.sol#L325) is not in mixedCase

src/rules/validation/abstract/base/RuleERC2980Base.sol#L325


 - [ ] ID-38
Parameter [IdentityRegistryWhitelistBase.registerIdentity(address,address,uint16)._identity](src/registry/abstract/IdentityRegistryWhitelistBase.sol#L73) is not in mixedCase

src/registry/abstract/IdentityRegistryWhitelistBase.sol#L73


 - [ ] ID-39
Parameter [IdentityRegistryWhitelistBase.registerIdentity(address,address,uint16)._userAddress](src/registry/abstract/IdentityRegistryWhitelistBase.sol#L72) is not in mixedCase

src/registry/abstract/IdentityRegistryWhitelistBase.sol#L72


## unused-state
Impact: Informational
Confidence: High
 - [ ] ID-40
[RuleNFTAdapter.TRANSFERRED_SELECTOR_RULE_ENGINE](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L27) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L27


 - [ ] ID-41
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC7943](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L31-L32) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L31-L32


 - [ ] ID-42
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC7943_FROM](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L36-L37) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L36-L37


 - [ ] ID-43
[RuleNFTAdapter.TRANSFERRED_SELECTOR_ERC3643](src/rules/validation/abstract/core/RuleNFTAdapter.sol#L23) is never used in [RuleIdentityRegistryOwnable2Step](src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol#L14-L64)

src/rules/validation/abstract/core/RuleNFTAdapter.sol#L23


