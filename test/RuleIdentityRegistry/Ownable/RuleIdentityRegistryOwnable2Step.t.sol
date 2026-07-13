// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../../HelperContract.sol";
import {Ownable2StepTestBase, IOwnable2StepLike} from "../../utils/Ownable2StepTestBase.sol";
import {IdentityRegistryMock} from "src/mocks/IdentityRegistryMock.sol";
import {RuleIdentityRegistryOwnable2Step} from "src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol";

contract RuleIdentityRegistryOwnable2StepTest is Ownable2StepTestBase {
    function _deployOwnable2Step() internal override returns (IOwnable2StepLike, address) {
        address ownerAddr = WHITELIST_OPERATOR_ADDRESS;
        IdentityRegistryMock registry = new IdentityRegistryMock();
        RuleIdentityRegistryOwnable2Step rule =
            new RuleIdentityRegistryOwnable2Step(ownerAddr, address(registry), false, false);
        return (IOwnable2StepLike(address(rule)), ownerAddr);
    }
}

contract RuleIdentityRegistryOwnable2StepAccessControl is Test, HelperContract {
    error OwnableUnauthorizedAccount(address account);

    RuleIdentityRegistryOwnable2Step private rule;
    IdentityRegistryMock private registry;

    function setUp() public {
        registry = new IdentityRegistryMock();
        rule = new RuleIdentityRegistryOwnable2Step(WHITELIST_OPERATOR_ADDRESS, address(registry), false, false);
    }

    function testOwnerCanSetAndClearIdentityRegistry() public {
        IdentityRegistryMock newRegistry = new IdentityRegistryMock();

        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        rule.setIdentityRegistry(address(newRegistry));
        assertEq(address(rule.identityRegistry()), address(newRegistry));

        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        rule.clearIdentityRegistry();
        assertEq(address(rule.identityRegistry()), ZERO_ADDRESS);
    }

    function testNonOwnerCannotManageIdentityRegistry() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, ATTACKER));
        vm.prank(ATTACKER);
        rule.setIdentityRegistry(address(registry));

        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, ATTACKER));
        vm.prank(ATTACKER);
        rule.clearIdentityRegistry();
    }
}
