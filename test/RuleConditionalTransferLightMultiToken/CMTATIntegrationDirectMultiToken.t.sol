// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {CMTATDeployment} from "RuleEngine/../test/utils/CMTATDeployment.sol";
import {CMTATStandalone} from "CMTAT/deployment/CMTATStandalone.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleConditionalTransferLightMultiToken} from "src/rules/operation/RuleConditionalTransferLightMultiToken.sol";

contract CMTATIntegrationDirectMultiToken is Test, HelperContract {
    CMTATStandalone private tokenA;
    CMTATStandalone private tokenB;
    RuleConditionalTransferLightMultiToken private rule;

    function setUp() public {
        CMTATDeployment deploymentA = new CMTATDeployment();
        CMTATDeployment deploymentB = new CMTATDeployment();

        tokenA = deploymentA.cmtat();
        tokenB = deploymentB.cmtat();

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleConditionalTransferLightMultiToken(DEFAULT_ADMIN_ADDRESS);

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(address(tokenA));
        rule.bindToken(address(tokenB));
        tokenA.setRuleEngine(IRuleEngine(address(rule)));
        tokenB.setRuleEngine(IRuleEngine(address(rule)));

        tokenA.mint(ADDRESS1, 100);
        tokenB.mint(ADDRESS1, 100);
        vm.stopPrank();
    }

    function testDetectRestriction_IsTokenScoped() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(address(tokenA), ADDRESS1, ADDRESS2, 10);

        resUint8 = tokenA.detectTransferRestriction(ADDRESS1, ADDRESS2, 10);
        assertEq(resUint8, TRANSFER_OK);

        resUint8 = tokenB.detectTransferRestriction(ADDRESS1, ADDRESS2, 10);
        assertEq(resUint8, CODE_TRANSFER_REQUEST_NOT_APPROVED);
    }

    function testTransferConsumption_IsTokenScoped() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.approveTransfer(address(tokenA), ADDRESS1, ADDRESS2, 10);

        vm.prank(ADDRESS1);
        tokenA.transfer(ADDRESS2, 10);

        assertEq(rule.approvedCount(address(tokenA), ADDRESS1, ADDRESS2, 10), 0);
        assertEq(rule.approvedCount(address(tokenB), ADDRESS1, ADDRESS2, 10), 0);

        vm.prank(ADDRESS1);
        vm.expectRevert();
        tokenB.transfer(ADDRESS2, 10);
    }
}
