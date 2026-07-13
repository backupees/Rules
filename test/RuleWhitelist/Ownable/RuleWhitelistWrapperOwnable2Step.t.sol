// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Ownable2StepTestBase, IOwnable2StepLike} from "../../utils/Ownable2StepTestBase.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {RuleWhitelistWrapperOwnable2Step} from "src/rules/validation/deployment/RuleWhitelistWrapperOwnable2Step.sol";

contract RuleWhitelistWrapperOwnable2StepTest is Ownable2StepTestBase {
    RuleWhitelistWrapperOwnable2Step internal wrapper;
    RuleWhitelist internal rule;

    function _deployOwnable2Step() internal override returns (IOwnable2StepLike, address) {
        address ownerAddr = WHITELIST_OPERATOR_ADDRESS;
        wrapper = new RuleWhitelistWrapperOwnable2Step(ownerAddr, ZERO_ADDRESS, true, true);
        rule = new RuleWhitelist(ownerAddr, ZERO_ADDRESS, true, false);
        return (IOwnable2StepLike(address(wrapper)), ownerAddr);
    }

    function testOnlyOwnerCanAddRule() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, ATTACKER));
        vm.prank(ATTACKER);
        wrapper.addRule(rule);

        vm.prank(owner);
        wrapper.addRule(rule);
        assertEq(wrapper.rulesCount(), 1);
    }

    function testOnlyOwnerCanSetCheckSpender() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, ATTACKER));
        vm.prank(ATTACKER);
        wrapper.setCheckSpender(false);

        vm.prank(owner);
        wrapper.setCheckSpender(false);
        assertEq(wrapper.checkSpender(), false);
    }
}
