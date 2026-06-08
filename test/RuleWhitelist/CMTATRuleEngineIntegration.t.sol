// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {CMTATDeployment} from "test/utils/CMTATDeployment.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {RuleEngine} from "RuleEngine/deployment/RuleEngine.sol";

/**
 * @title Integration test with CMTAT + RuleEngine + RuleWhitelist
 */
contract CMTATRuleEngineIntegration is Test, HelperContract {
    uint256 constant ADDRESS1_BALANCE_INIT = 100;

    function setUp() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, true, false);

        cmtatDeployment = new CMTATDeployment();
        cmtatContract = cmtatDeployment.cmtat();

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock = new RuleEngine(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, address(cmtatContract));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleEngineMock.addRule(ruleWhitelist);
        // Allow minting: whitelist ZERO_ADDRESS (mint source) and recipient.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddress(ZERO_ADDRESS);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.setRuleEngine(ruleEngineMock);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        cmtatContract.mint(ADDRESS1, ADDRESS1_BALANCE_INIT);
    }

    function testDetectRestrictionAndCanTransferViaCMTAT() public {
        uint256 amount = 10;

        // Sender already whitelisted in setUp; recipient not whitelisted: should block on TO.
        resUint8 = cmtatContract.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, CODE_ADDRESS_TO_NOT_WHITELISTED);
        resBool = cmtatContract.canTransfer(ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, false);

        // Add recipient: should allow.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS2);
        resUint8 = cmtatContract.detectTransferRestriction(ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, TRANSFER_OK);
        resBool = cmtatContract.canTransfer(ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, true);
    }

    function testDetectRestrictionFromAndCanTransferFromViaCMTAT() public {
        uint256 amount = 10;

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS2);

        // Spender not whitelisted.
        resUint8 = cmtatContract.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, CODE_ADDRESS_SPENDER_NOT_WHITELISTED);
        resBool = cmtatContract.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, false);

        // Whitelist spender: should allow.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS3);
        resUint8 = cmtatContract.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, amount);
        assertEq(resUint8, TRANSFER_OK);
        resBool = cmtatContract.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, amount);
        assertEq(resBool, true);
    }
}
