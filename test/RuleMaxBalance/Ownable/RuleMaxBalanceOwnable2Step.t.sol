// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {RuleMaxBalanceOwnable2Step} from "src/rules/validation/deployment/RuleMaxBalanceOwnable2Step.sol";
import {BalanceOfMock} from "src/mocks/BalanceOfMock.sol";

contract RuleMaxBalanceOwnable2StepTest is Test {
    address constant OWNER = address(0xA11CE);
    address constant ATTACKER = address(0xBAD);
    address constant ALICE = address(0x11);
    address constant CUSTODIAN = address(0x13);
    uint256 constant CAP = 100;

    BalanceOfMock private token;
    RuleMaxBalanceOwnable2Step private rule;

    function setUp() public {
        token = new BalanceOfMock();
        rule = new RuleMaxBalanceOwnable2Step(OWNER, address(token), CAP);
    }

    function testOwnerManagesTheCap() public {
        vm.prank(OWNER);
        rule.setMaxBalance(500);
        assertEq(rule.maxBalance(), 500);
    }

    function testNonOwnerCannotManageTheCap() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, ATTACKER));
        rule.setMaxBalance(500);
    }

    function testOwnerManagesExemptions() public {
        vm.prank(OWNER);
        rule.addExemptAddress(CUSTODIAN);
        assertTrue(rule.isExemptAddress(CUSTODIAN));

        vm.prank(OWNER);
        rule.removeExemptAddress(CUSTODIAN);
        assertFalse(rule.isExemptAddress(CUSTODIAN));
    }

    function testNonOwnerCannotManageExemptions() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, ATTACKER));
        rule.addExemptAddress(CUSTODIAN);
    }

    function testOwnerManagesBatchExemptions() public {
        address[] memory batch = new address[](1);
        batch[0] = CUSTODIAN;

        vm.prank(OWNER);
        rule.addExemptAddresses(batch);
        assertEq(rule.exemptAddressCount(), 1);

        vm.prank(OWNER);
        rule.removeExemptAddresses(batch);
        assertEq(rule.exemptAddressCount(), 0);
    }

    function testNonOwnerCannotChangeTheToken() public {
        BalanceOfMock other = new BalanceOfMock();
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, ATTACKER));
        rule.setBalanceToken(address(other));
    }

    function testOwnerChangesTheToken() public {
        BalanceOfMock other = new BalanceOfMock();
        vm.prank(OWNER);
        rule.setBalanceToken(address(other));
        assertEq(address(rule.balanceToken()), address(other));
    }

    function testTheCapStillApplies() public {
        token.setBalance(ALICE, CAP);
        assertEq(rule.detectTransferRestriction(address(0x99), ALICE, 1), rule.CODE_MAX_BALANCE_EXCEEDED());
    }

    function testRemainingCapacity() public {
        token.setBalance(ALICE, 40);
        (, uint256 headroom) = rule.remainingCapacity(ALICE);
        assertEq(headroom, 60);
    }

    function testSupportsInterface() public view {
        assertTrue(rule.supportsInterface(type(IERC165).interfaceId));
    }
}
