// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC1404ExtendInterfaceId} from "CMTAT/library/ERC1404ExtendInterfaceId.sol";
import {RuleEngineInterfaceId} from "CMTAT/library/RuleEngineInterfaceId.sol";
import {RuleInterfaceId} from "RuleEngine/modules/library/RuleInterfaceId.sol";
import {AddressListInterfaceId} from "src/rules/interfaces/library/AddressListInterfaceId.sol";
import {RuleReceiverWhitelistHarness} from "src/mocks/harness/RuleReceiverWhitelistHarnesses.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleReceiverWhitelist} from "src/rules/validation/deployment/RuleReceiverWhitelist.sol";
import {
    RuleReceiverWhitelistInvariantStorage
} from "src/rules/validation/abstract/invariant/RuleReceiverWhitelistInvariantStorage.sol";

/**
 * @title Unit tests for RuleReceiverWhitelist
 * @notice The rule reproduces ERC-3643's eligibility semantics: only the receiver is screened.
 *         These tests pin each half of that — what IS checked, and just as importantly what is
 *         deliberately NOT.
 */
contract RuleReceiverWhitelistUnit is Test, HelperContract, RuleReceiverWhitelistInvariantStorage {
    RuleReceiverWhitelist private rule;
    RuleReceiverWhitelistHarness private harness;

    function setUp() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleReceiverWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        harness = new RuleReceiverWhitelistHarness(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(ADDRESS1);
    }

    /*//////////////////////////////////////////////////////////////
                        THE RECEIVER IS SCREENED
    //////////////////////////////////////////////////////////////*/

    function testTransfer_ToWhitelistedReceiverIsAllowed() public view {
        assertEq(rule.detectTransferRestriction(ADDRESS2, ADDRESS1, 10), TRANSFER_OK);
        assertTrue(rule.canTransfer(ADDRESS2, ADDRESS1, 10));
    }

    function testTransfer_ToUnlistedReceiverIsRejected() public view {
        assertEq(rule.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), CODE_ADDRESS_RECEIVER_NOT_WHITELISTED);
        assertFalse(rule.canTransfer(ADDRESS1, ADDRESS2, 10));
    }

    /*//////////////////////////////////////////////////////////////
                      THE SENDER IS NOT SCREENED
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The defining behaviour: an unlisted sender may still send to a listed receiver. This
     *         is what lets a de-listed investor exit their position instead of being trapped.
     */
    function testTransfer_UnlistedSenderCanStillSendToAListedReceiver() public view {
        assertFalse(rule.isAddressListed(ADDRESS2), "sender is not listed");
        assertEq(rule.detectTransferRestriction(ADDRESS2, ADDRESS1, 10), TRANSFER_OK);
    }

    /**
     * @notice Removing a holder from the list must not strand their balance.
     */
    function testTransfer_DeListedHolderCanStillExit() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(ADDRESS2);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.removeAddress(ADDRESS1);
        assertFalse(rule.isAddressListed(ADDRESS1));

        // ADDRESS1 is de-listed but can still send to the still-listed ADDRESS2.
        assertEq(rule.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), TRANSFER_OK);
        rule.transferred(ADDRESS1, ADDRESS2, 10);
    }

    /*//////////////////////////////////////////////////////////////
                     THE SPENDER IS NOT SCREENED
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice ERC-3643: `transferFrom` "works the same way" — the spender is never checked.
     */
    function testTransferFrom_SpenderIsIgnored() public view {
        assertFalse(rule.isAddressListed(ADDRESS3), "spender is not listed");
        assertEq(rule.detectTransferRestrictionFrom(ADDRESS3, ADDRESS2, ADDRESS1, 10), TRANSFER_OK);
        assertTrue(rule.canTransferFrom(ADDRESS3, ADDRESS2, ADDRESS1, 10));

        // ...and it still rejects on the receiver, spender notwithstanding.
        assertEq(
            rule.detectTransferRestrictionFrom(ADDRESS1, ADDRESS1, ADDRESS2, 10), CODE_ADDRESS_RECEIVER_NOT_WHITELISTED
        );
    }

    /*//////////////////////////////////////////////////////////////
                             MINT / BURN
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice ERC-3643: `mint` "only require[s] the receiver", so a mint is screened exactly like
     *         any other transfer — no `allowMint` flag.
     */
    function testMint_ScreensTheReceiverLikeAnyTransfer() public view {
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 10), TRANSFER_OK, "listed receiver");
        assertEq(
            rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS2, 10),
            CODE_ADDRESS_RECEIVER_NOT_WHITELISTED,
            "unlisted receiver"
        );
        // Same on the spender-aware mint path, where the minter arrives as `spender`.
        assertEq(rule.detectTransferRestrictionFrom(ADDRESS3, ZERO_ADDRESS, ADDRESS1, 10), TRANSFER_OK);
    }

    /**
     * @notice ERC-3643: `burn` "bypasses all checks on eligibility". The exemption must be explicit,
     *         because `address(0)` can never be listed and would otherwise always be rejected.
     */
    function testBurn_IsAlwaysAllowed() public {
        assertFalse(rule.isAddressListed(ZERO_ADDRESS), "zero address is never listed");

        assertEq(rule.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 10), TRANSFER_OK, "listed sender");
        assertEq(rule.detectTransferRestriction(ADDRESS2, ZERO_ADDRESS, 10), TRANSFER_OK, "unlisted sender");
        assertEq(rule.detectTransferRestrictionFrom(ADDRESS3, ADDRESS2, ZERO_ADDRESS, 10), TRANSFER_OK);
        rule.transferred(ADDRESS2, ZERO_ADDRESS, 10);
    }

    /**
     * @notice The zero address can never enter the list, so `isAddressListed(address(0))` stays
     *         false and burn permission is never expressible as list membership.
     */
    function testZeroAddressCannotBeListed() public {
        vm.expectRevert(RuleAddressSet_ZeroAddressNotAllowed.selector);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(ZERO_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////
                             WRITE PATH
    //////////////////////////////////////////////////////////////*/

    function testTransferred_RevertsOnUnlistedReceiver() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleReceiverWhitelist_InvalidTransfer.selector,
                address(rule),
                ADDRESS1,
                ADDRESS2,
                10,
                CODE_ADDRESS_RECEIVER_NOT_WHITELISTED
            )
        );
        rule.transferred(ADDRESS1, ADDRESS2, 10);
    }

    function testTransferredFrom_RevertsOnUnlistedReceiver() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleReceiverWhitelist_InvalidTransferFrom.selector,
                address(rule),
                ADDRESS3,
                ADDRESS1,
                ADDRESS2,
                10,
                CODE_ADDRESS_RECEIVER_NOT_WHITELISTED
            )
        );
        rule.transferred(ADDRESS3, ADDRESS1, ADDRESS2, 10);
    }

    function testTransferred_DoesNotRevertWhenAllowed() public {
        rule.transferred(ADDRESS2, ADDRESS1, 10);
        rule.transferred(ADDRESS3, ADDRESS2, ADDRESS1, 10);
    }

    /*//////////////////////////////////////////////////////////////
                          ERC-1404 SURFACE
    //////////////////////////////////////////////////////////////*/

    function testCanReturnTransferRestrictionCode() public view {
        assertTrue(rule.canReturnTransferRestrictionCode(CODE_ADDRESS_RECEIVER_NOT_WHITELISTED));
        assertFalse(rule.canReturnTransferRestrictionCode(CODE_NONEXISTENT));
    }

    function testMessageForTransferRestriction() public view {
        assertEq(
            rule.messageForTransferRestriction(CODE_ADDRESS_RECEIVER_NOT_WHITELISTED),
            TEXT_ADDRESS_RECEIVER_NOT_WHITELISTED
        );
        assertEq(rule.messageForTransferRestriction(CODE_NONEXISTENT), TEXT_CODE_NOT_FOUND);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function testAddAddress_OnlyAddRole() public {
        vm.expectRevert();
        vm.prank(ATTACKER);
        rule.addAddress(ADDRESS2);
    }

    function testRemoveAddress_OnlyRemoveRole() public {
        vm.expectRevert();
        vm.prank(ATTACKER);
        rule.removeAddress(ADDRESS1);
    }

    /*//////////////////////////////////////////////////////////////
                        ERC-165 AND BATCH OPS
    //////////////////////////////////////////////////////////////*/

    function testSupportsInterface() public view {
        assertTrue(rule.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(rule.supportsInterface(RuleInterfaceId.IRULE_INTERFACE_ID));
        assertTrue(rule.supportsInterface(ERC1404ExtendInterfaceId.ERC1404EXTEND_INTERFACE_ID));
        assertTrue(rule.supportsInterface(RuleEngineInterfaceId.RULE_ENGINE_INTERFACE_ID));
        assertTrue(rule.supportsInterface(AddressListInterfaceId.IADDRESS_LIST_INTERFACE_ID), "advertises IAddressList");
        assertFalse(rule.supportsInterface(bytes4(0xdeadbeef)));
    }

    /**
     * @notice Batch operations come from `RuleAddressSet`: they skip duplicates instead of
     *         reverting, unlike the single-address variants.
     */
    function testBatchAddAndRemove() public {
        address[] memory batch = new address[](2);
        batch[0] = ADDRESS2;
        batch[1] = ADDRESS3;

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddresses(batch);
        bool[] memory listed = rule.areAddressesListed(batch);
        assertTrue(listed[0] && listed[1], "both listed");
        assertEq(rule.listedAddressCount(), 3);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.removeAddresses(batch);
        listed = rule.areAddressesListed(batch);
        assertFalse(listed[0] || listed[1], "neither listed");
        assertEq(rule.listedAddressCount(), 1);
    }

    function testMetaTxOverridesAreReachable() public view {
        assertEq(harness.exposedMsgSender(), address(this));
        assertEq(harness.exposedContextSuffixLength(), 20);
        assertGe(harness.exposedMsgData().length, 4);
    }
}
