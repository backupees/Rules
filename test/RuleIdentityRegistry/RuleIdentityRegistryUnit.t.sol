// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleIdentityRegistry} from "src/rules/validation/deployment/RuleIdentityRegistry.sol";
import {IdentityRegistryMock} from "src/mocks/IdentityRegistryMock.sol";

contract RuleIdentityRegistryUnit is Test, HelperContract {
    IdentityRegistryMock private registry;
    RuleIdentityRegistry private rule;

    function setUp() public {
        registry = new IdentityRegistryMock();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleIdentityRegistry(DEFAULT_ADMIN_ADDRESS, address(registry), false, false);
    }

    function testDetectRestriction_NoRegistry_ReturnsOk() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleIdentityRegistry(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false, false);

        resUint8 = rule.detectTransferRestriction(ADDRESS1, ADDRESS2, 1);
        assertEq(resUint8, TRANSFER_OK);
    }

    /// @notice ERC-3643 mandates that ONLY the receiver be verified. An unverified SENDER is allowed
    ///         by default — the spec checks only the receiver precisely so a de-listed holder can
    ///         still exit their position.
    function testDetectRestriction_UnverifiedSenderIsAllowedByDefault() public {
        registry.setVerified(ADDRESS2, true);
        assertFalse(rule.checkSender());

        resUint8 = rule.detectTransferRestriction(ADDRESS1, ADDRESS2, 1);
        assertEq(resUint8, TRANSFER_OK);
    }

    /// @notice The stricter sender check is available as an explicit opt-in.
    function testDetectRestriction_FromNotVerifiedWhenCheckSenderEnabled() public {
        registry.setVerified(ADDRESS2, true);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setCheckSender(true);
        assertTrue(rule.checkSender());

        resUint8 = rule.detectTransferRestriction(ADDRESS1, ADDRESS2, 1);
        assertEq(resUint8, CODE_ADDRESS_FROM_NOT_VERIFIED);
    }

    function testDetectRestriction_ToNotVerified() public {
        registry.setVerified(ADDRESS1, true);

        resUint8 = rule.detectTransferRestriction(ADDRESS1, ADDRESS2, 1);
        assertEq(resUint8, CODE_ADDRESS_TO_NOT_VERIFIED);
    }

    function testDetectRestriction_BurnAllowed() public {
        resUint8 = rule.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 1);
        assertEq(resUint8, TRANSFER_OK);
    }

    /// @notice ERC-3643: "`transferFrom` works the same way" — receiver only. An unverified SPENDER
    ///         is allowed by default.
    function testDetectRestrictionFrom_UnverifiedSpenderIsAllowedByDefault() public {
        registry.setVerified(ADDRESS1, true);
        registry.setVerified(ADDRESS2, true);
        assertFalse(rule.checkSpender());

        resUint8 = rule.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 1);
        assertEq(resUint8, TRANSFER_OK);
    }

    /// @notice The stricter spender check is available as an explicit opt-in.
    function testDetectRestrictionFrom_SpenderNotVerifiedWhenCheckSpenderEnabled() public {
        registry.setVerified(ADDRESS1, true);
        registry.setVerified(ADDRESS2, true);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setCheckSpender(true);

        resUint8 = rule.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 1);
        assertEq(resUint8, CODE_ADDRESS_SPENDER_NOT_VERIFIED);
    }

    /// @notice Even with `checkSpender` ON, a MINT exempts the spender: ERC-3643 says `mint` "only
    ///         requires the receiver to be whitelisted and verified". An unverified minter may mint
    ///         to a verified recipient.
    function testMintExemptsTheMinterEvenWhenCheckSpenderEnabled() public {
        registry.setVerified(ADDRESS2, true); // recipient verified; MINTER (ADDRESS3) is not

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setCheckSpender(true);

        resUint8 = rule.detectTransferRestrictionFrom(ADDRESS3, ZERO_ADDRESS, ADDRESS2, 1);
        assertEq(resUint8, TRANSFER_OK);
    }

    /// @notice ERC-3643: "The `burn` function bypasses all checks on eligibility."
    function testBurnBypassesAllChecks() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.setCheckSender(true);
        rule.setCheckSpender(true);
        vm.stopPrank();

        // Nobody is verified, yet the burn passes.
        assertEq(rule.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 1), TRANSFER_OK);
        assertEq(rule.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ZERO_ADDRESS, 1), TRANSFER_OK);
    }

    function testDetectRestrictionFrom_NoRegistry_ReturnsOk() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.clearIdentityRegistry();

        resUint8 = rule.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 1);
        assertEq(resUint8, TRANSFER_OK);
    }

    function testSetIdentityRegistry_RevertsOnZeroAddress() public {
        vm.expectRevert(RuleIdentityRegistry_RegistryAddressZeroNotAllowed.selector);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setIdentityRegistry(ZERO_ADDRESS);
    }

    function testSetIdentityRegistry_OnlyAdmin() public {
        vm.expectRevert();
        vm.prank(ADDRESS1);
        rule.setIdentityRegistry(address(registry));
    }

    function testClearIdentityRegistry_OnlyAdmin() public {
        vm.expectRevert();
        vm.prank(ADDRESS1);
        rule.clearIdentityRegistry();
    }

    /// @notice Enforcement reverts when the RECEIVER is unverified — the only ERC-3643-mandated check.
    function testTransferred_RevertsWhenReceiverNotVerified() public {
        registry.setVerified(ADDRESS1, true); // sender verified, receiver NOT

        vm.expectRevert(
            abi.encodeWithSelector(
                RuleIdentityRegistry_InvalidTransfer.selector,
                address(rule),
                ADDRESS1,
                ADDRESS2,
                10,
                CODE_ADDRESS_TO_NOT_VERIFIED
            )
        );
        rule.transferred(ADDRESS1, ADDRESS2, 10);
    }

    /// @notice Enforcement does NOT revert on an unverified sender by default (ERC-3643).
    function testTransferred_DoesNotRevertOnUnverifiedSenderByDefault() public {
        registry.setVerified(ADDRESS2, true); // receiver verified, sender NOT
        rule.transferred(ADDRESS1, ADDRESS2, 10); // no revert
    }

    /// @notice With `checkSpender` opted in, enforcement reverts on an unverified spender.
    function testTransferredFrom_RevertsOnUnverifiedSpenderWhenOptedIn() public {
        registry.setVerified(ADDRESS1, true);
        registry.setVerified(ADDRESS2, true);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setCheckSpender(true);

        vm.expectRevert(
            abi.encodeWithSelector(
                RuleIdentityRegistry_InvalidTransferFrom.selector,
                address(rule),
                ADDRESS3,
                ADDRESS1,
                ADDRESS2,
                10,
                CODE_ADDRESS_SPENDER_NOT_VERIFIED
            )
        );
        rule.transferred(ADDRESS3, ADDRESS1, ADDRESS2, 10);
    }

    /// @notice By default an unverified spender is accepted (ERC-3643).
    function testTransferredFrom_DoesNotRevertOnUnverifiedSpenderByDefault() public {
        registry.setVerified(ADDRESS1, true);
        registry.setVerified(ADDRESS2, true);

        rule.transferred(ADDRESS3, ADDRESS1, ADDRESS2, 10); // no revert
    }

    function testTransferred_DoesNotRevertWhenValid() public {
        registry.setVerified(ADDRESS1, true);
        registry.setVerified(ADDRESS2, true);

        rule.transferred(ADDRESS1, ADDRESS2, 10);
    }

    function testTransferredFrom_DoesNotRevertWhenValid() public {
        registry.setVerified(ADDRESS1, true);
        registry.setVerified(ADDRESS2, true);
        registry.setVerified(ADDRESS3, true);

        rule.transferred(ADDRESS3, ADDRESS1, ADDRESS2, 10);
    }

    function testCanReturnTransferRestrictionCode() public view {
        assertTrue(rule.canReturnTransferRestrictionCode(CODE_ADDRESS_FROM_NOT_VERIFIED));
        assertTrue(rule.canReturnTransferRestrictionCode(CODE_ADDRESS_TO_NOT_VERIFIED));
        assertTrue(rule.canReturnTransferRestrictionCode(CODE_ADDRESS_SPENDER_NOT_VERIFIED));
        assertFalse(rule.canReturnTransferRestrictionCode(CODE_NONEXISTENT));
    }

    function testMessageForTransferRestriction() public view {
        assertEq(rule.messageForTransferRestriction(CODE_ADDRESS_FROM_NOT_VERIFIED), TEXT_ADDRESS_FROM_NOT_VERIFIED);
        assertEq(rule.messageForTransferRestriction(CODE_ADDRESS_TO_NOT_VERIFIED), TEXT_ADDRESS_TO_NOT_VERIFIED);
        assertEq(
            rule.messageForTransferRestriction(CODE_ADDRESS_SPENDER_NOT_VERIFIED), TEXT_ADDRESS_SPENDER_NOT_VERIFIED
        );
        assertEq(rule.messageForTransferRestriction(CODE_NONEXISTENT), TEXT_CODE_NOT_FOUND);
    }
}
