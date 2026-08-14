// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../../HelperContract.sol";
import {Ownable2StepTestBase, IOwnable2StepLike} from "../../utils/Ownable2StepTestBase.sol";
import {SanctionListOracle} from "src/mocks/SanctionListOracle.sol";
import {ISanctionsList} from "src/rules/interfaces/ISanctionsList.sol";
import {RuleSanctionsListOwnable2Step} from "src/rules/validation/deployment/RuleSanctionsListOwnable2Step.sol";
import {RuleSanctionsListOwnable2StepHarness} from "src/mocks/harness/RuleSanctionsListOwnable2StepHarness.sol";

contract RuleSanctionsListOwnable2StepTest is Ownable2StepTestBase {
    function _deployOwnable2Step() internal override returns (IOwnable2StepLike, address) {
        address ownerAddr = SANCTIONLIST_OPERATOR_ADDRESS;
        RuleSanctionsListOwnable2Step rule =
            new RuleSanctionsListOwnable2Step(ownerAddr, ZERO_ADDRESS, ISanctionsList(ZERO_ADDRESS));
        return (IOwnable2StepLike(address(rule)), ownerAddr);
    }
}

contract RuleSanctionsListOwnable2StepAccessControl is Test, HelperContract {
    error OwnableUnauthorizedAccount(address account);

    RuleSanctionsListOwnable2StepHarness private rule;
    SanctionListOracle private oracle;

    function setUp() public {
        oracle = new SanctionListOracle();
        rule = new RuleSanctionsListOwnable2StepHarness(
            SANCTIONLIST_OPERATOR_ADDRESS, ZERO_ADDRESS, ISanctionsList(ZERO_ADDRESS)
        );
    }

    function testOwnerCanSetAndClearOracle() public {
        vm.prank(SANCTIONLIST_OPERATOR_ADDRESS);
        rule.setSanctionListOracle(oracle);
        assertEq(address(rule.sanctionsList()), address(oracle));

        vm.prank(SANCTIONLIST_OPERATOR_ADDRESS);
        rule.clearSanctionListOracle();
        assertEq(address(rule.sanctionsList()), ZERO_ADDRESS);
    }

    function testNonOwnerCannotSetOracle() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, ATTACKER));
        vm.prank(ATTACKER);
        rule.setSanctionListOracle(oracle);
    }

    function testMetaTxOverridesAreReachable() public view {
        assertEq(rule.exposedMsgSender(), address(this));
        assertEq(rule.exposedContextSuffixLength(), 20);
        assertGe(rule.exposedMsgData().length, 4);
    }
}
