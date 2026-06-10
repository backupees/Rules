// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleMintAllowanceOwnable2Step} from "src/rules/operation/RuleMintAllowanceOwnable2Step.sol";
import {RuleInterfaceId} from "RuleEngine/modules/library/RuleInterfaceId.sol";
import {ERC1404ExtendInterfaceId} from "CMTAT/library/ERC1404ExtendInterfaceId.sol";
import {RuleEngineInterfaceId} from "CMTAT/library/RuleEngineInterfaceId.sol";
import {OwnableInterfaceId} from "RuleEngine/modules/library/OwnableInterfaceId.sol";
import {Ownable2StepInterfaceId} from "RuleEngine/modules/library/Ownable2StepInterfaceId.sol";

contract RuleMintAllowanceOwnable2StepTest is Test, HelperContract {
    address constant OWNER = address(1);
    address constant MINTER = address(11);
    address constant BOUND_ENGINE = address(12);

    RuleMintAllowanceOwnable2Step private rule;

    function setUp() public {
        vm.prank(OWNER);
        rule = new RuleMintAllowanceOwnable2Step(OWNER);
        vm.prank(OWNER);
        rule.bindToken(BOUND_ENGINE);
    }

    function testOwnerCanSetAllowance() public {
        vm.prank(OWNER);
        rule.setMintAllowance(MINTER, 500);
        assertEq(rule.mintAllowance(MINTER), 500);
    }

    function testNonOwnerCannotSetAllowance() public {
        vm.expectRevert();
        vm.prank(ADDRESS1);
        rule.setMintAllowance(MINTER, 500);
    }

    function testOwnerCanIncreaseAndDecrease() public {
        vm.prank(OWNER);
        rule.setMintAllowance(MINTER, 1000);
        vm.prank(OWNER);
        rule.increaseMintAllowance(MINTER, 200);
        assertEq(rule.mintAllowance(MINTER), 1200);
        vm.prank(OWNER);
        rule.decreaseMintAllowance(MINTER, 300);
        assertEq(rule.mintAllowance(MINTER), 900);
    }

    function testOwnerCanBindUnbind() public {
        vm.expectRevert(RuleMintAllowance_TokenAlreadyBound.selector);
        vm.prank(OWNER);
        rule.bindToken(ADDRESS2);

        vm.prank(OWNER);
        rule.unbindToken(BOUND_ENGINE);

        vm.prank(OWNER);
        rule.bindToken(ADDRESS2);
        assertTrue(rule.isTokenBound(ADDRESS2));
        vm.prank(OWNER);
        rule.unbindToken(ADDRESS2);
        assertFalse(rule.isTokenBound(ADDRESS2));
    }

    function testNonOwnerCannotBind() public {
        vm.expectRevert();
        vm.prank(ADDRESS1);
        rule.bindToken(ADDRESS2);
    }

    function testTransferredConsumesAllowance() public {
        vm.prank(OWNER);
        rule.setMintAllowance(MINTER, 1000);
        vm.prank(BOUND_ENGINE);
        rule.transferred(MINTER, ZERO_ADDRESS, ADDRESS1, 300);
        assertEq(rule.mintAllowance(MINTER), 700);
    }

    function testOwnershipTransferTwoStep() public {
        vm.prank(OWNER);
        rule.transferOwnership(ADDRESS1);
        assertEq(rule.pendingOwner(), ADDRESS1);
        assertEq(rule.owner(), OWNER);

        vm.prank(ADDRESS1);
        rule.acceptOwnership();
        assertEq(rule.owner(), ADDRESS1);
    }

    function testSupportsInterface() public view {
        assertTrue(rule.supportsInterface(OwnableInterfaceId.IERC173_INTERFACE_ID));
        assertTrue(rule.supportsInterface(Ownable2StepInterfaceId.IOWNABLE2STEP_INTERFACE_ID));
        assertTrue(rule.supportsInterface(RuleInterfaceId.IRULE_INTERFACE_ID));
        assertTrue(rule.supportsInterface(ERC1404ExtendInterfaceId.ERC1404EXTEND_INTERFACE_ID));
        assertTrue(rule.supportsInterface(RuleEngineInterfaceId.RULE_ENGINE_INTERFACE_ID));
        assertFalse(rule.supportsInterface(bytes4(0xdeadbeef)));
    }
}
