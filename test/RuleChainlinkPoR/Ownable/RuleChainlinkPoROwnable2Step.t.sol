// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC1404ExtendInterfaceId} from "CMTAT/library/ERC1404ExtendInterfaceId.sol";
import {RuleEngineInterfaceId} from "CMTAT/library/RuleEngineInterfaceId.sol";
import {RuleInterfaceId} from "RuleEngine/modules/library/RuleInterfaceId.sol";
import {HelperContract} from "../../HelperContract.sol";
import {Ownable2StepTestBase, IOwnable2StepLike} from "../../utils/Ownable2StepTestBase.sol";
import {AggregatorV3Mock} from "src/mocks/AggregatorV3Mock.sol";
import {AggregatorV3Interface} from "src/rules/interfaces/AggregatorV3Interface.sol";
import {RuleChainlinkPoROwnable2Step} from "src/rules/validation/deployment/RuleChainlinkPoROwnable2Step.sol";
import {TotalSupplyDecimalsMock} from "src/mocks/TotalSupplyDecimalsMock.sol";

contract RuleChainlinkPoROwnable2StepTest is Ownable2StepTestBase {
    function _deployOwnable2Step() internal override returns (IOwnable2StepLike, address) {
        address ownerAddr = WHITELIST_OPERATOR_ADDRESS;
        TotalSupplyDecimalsMock token = new TotalSupplyDecimalsMock(18);
        AggregatorV3Mock feed = new AggregatorV3Mock(8, 1000 * 1e8);
        RuleChainlinkPoROwnable2Step rule = new RuleChainlinkPoROwnable2Step(
            ownerAddr, address(token), 18, AggregatorV3Interface(address(feed)), 1 days
        );
        return (IOwnable2StepLike(address(rule)), ownerAddr);
    }
}

contract RuleChainlinkPoROwnable2StepAccessControl is Test, HelperContract {
    error OwnableUnauthorizedAccount(address account);

    RuleChainlinkPoROwnable2Step private rule;
    TotalSupplyDecimalsMock private token;
    AggregatorV3Mock private feed;

    function setUp() public {
        vm.warp(1_000_000);
        token = new TotalSupplyDecimalsMock(18);
        feed = new AggregatorV3Mock(8, 1000 * 1e8);
        rule = new RuleChainlinkPoROwnable2Step(
            WHITELIST_OPERATOR_ADDRESS, address(token), 18, AggregatorV3Interface(address(feed)), 1 days
        );
    }

    function testOwnerCanManageConfiguration() public {
        AggregatorV3Mock newFeed = new AggregatorV3Mock(18, 500 * 1e18);
        TotalSupplyDecimalsMock newToken = new TotalSupplyDecimalsMock(6);

        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        rule.setReservesFeed(AggregatorV3Interface(address(newFeed)));
        assertEq(address(rule.reservesFeed()), address(newFeed));

        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        rule.setTokenMetadata(address(newToken), 6);
        assertEq(address(rule.tokenContract()), address(newToken));

        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        rule.setMaxStalenessSeconds(3600);
        assertEq(rule.maxStalenessSeconds(), 3600);
    }

    function testNonOwnerCannotManageConfiguration() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, ATTACKER));
        vm.prank(ATTACKER);
        rule.setReservesFeed(AggregatorV3Interface(address(feed)));

        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, ATTACKER));
        vm.prank(ATTACKER);
        rule.setTokenMetadata(address(token), 18);

        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, ATTACKER));
        vm.prank(ATTACKER);
        rule.setMaxStalenessSeconds(1);
    }

    function testSupportsInterface() public view {
        assertTrue(rule.supportsInterface(type(IERC165).interfaceId), "IERC165");
        assertTrue(rule.supportsInterface(RuleInterfaceId.IRULE_INTERFACE_ID), "IRule");
        assertTrue(rule.supportsInterface(RuleEngineInterfaceId.RULE_ENGINE_INTERFACE_ID), "IRuleEngine");
        assertTrue(rule.supportsInterface(ERC1404ExtendInterfaceId.ERC1404EXTEND_INTERFACE_ID), "IERC1404Extend");
        assertFalse(rule.supportsInterface(bytes4(0xdeadbeef)), "unknown interface");
    }

    function testRestrictionLogicMatchesTheAccessControlVariant() public {
        token.setTotalSupply(900 * 1e18);
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 100 * 1e18), TRANSFER_OK);
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 100 * 1e18 + 1), CODE_RESERVES_EXCEEDED);
    }
}
