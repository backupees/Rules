// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../../HelperContract.sol";
import {RuleERC2980Ownable2Step} from "src/rules/validation/deployment/RuleERC2980Ownable2Step.sol";

contract RuleERC2980OwnableAccessControl is Test, HelperContract {
    error OwnableUnauthorizedAccount(address account);

    RuleERC2980Ownable2Step public rule;
    address constant OWNER = WHITELIST_OPERATOR_ADDRESS;

    function setUp() public {
        rule = new RuleERC2980Ownable2Step(OWNER, ZERO_ADDRESS, false);
    }

    /*//////////////////////////////////////////////////////////////
                    WHITELIST — OWNER CAN MANAGE
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanAddToWhitelist() public {
        vm.prank(OWNER);
        rule.addWhitelistAddress(ADDRESS1);
        assertTrue(rule.isWhitelisted(ADDRESS1));
    }

    function testOwnerCanRemoveFromWhitelist() public {
        vm.prank(OWNER);
        rule.addWhitelistAddress(ADDRESS1);
        vm.prank(OWNER);
        rule.removeWhitelistAddress(ADDRESS1);
        assertFalse(rule.isWhitelisted(ADDRESS1));
    }

    function testOwnerCanBatchAddToWhitelist() public {
        address[] memory addrs = new address[](2);
        addrs[0] = ADDRESS1;
        addrs[1] = ADDRESS2;
        vm.prank(OWNER);
        rule.addWhitelistAddresses(addrs);
        assertTrue(rule.isWhitelisted(ADDRESS1));
        assertTrue(rule.isWhitelisted(ADDRESS2));
    }

    function testOwnerCanBatchRemoveFromWhitelist() public {
        address[] memory addrs = new address[](1);
        addrs[0] = ADDRESS1;
        vm.prank(OWNER);
        rule.addWhitelistAddresses(addrs);
        vm.prank(OWNER);
        rule.removeWhitelistAddresses(addrs);
        assertFalse(rule.isWhitelisted(ADDRESS1));
    }

    /*//////////////////////////////////////////////////////////////
                    FROZENLIST — OWNER CAN MANAGE
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanAddToFrozenlist() public {
        vm.prank(OWNER);
        rule.addFrozenlistAddress(ADDRESS1);
        assertTrue(rule.isFrozen(ADDRESS1));
    }

    function testOwnerCanRemoveFromFrozenlist() public {
        vm.prank(OWNER);
        rule.addFrozenlistAddress(ADDRESS1);
        vm.prank(OWNER);
        rule.removeFrozenlistAddress(ADDRESS1);
        assertFalse(rule.isFrozen(ADDRESS1));
    }

    function testOwnerCanBatchAddToFrozenlist() public {
        address[] memory addrs = new address[](2);
        addrs[0] = ADDRESS1;
        addrs[1] = ADDRESS2;
        vm.prank(OWNER);
        rule.addFrozenlistAddresses(addrs);
        assertTrue(rule.isFrozen(ADDRESS1));
        assertTrue(rule.isFrozen(ADDRESS2));
    }

    /*//////////////////////////////////////////////////////////////
                    WHITELIST — NON-OWNER CANNOT MANAGE
    //////////////////////////////////////////////////////////////*/

    function testNonOwnerCannotAddToWhitelist() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, ATTACKER));
        rule.addWhitelistAddress(ADDRESS1);
    }

    function testNonOwnerCannotRemoveFromWhitelist() public {
        vm.prank(OWNER);
        rule.addWhitelistAddress(ADDRESS1);
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, ATTACKER));
        rule.removeWhitelistAddress(ADDRESS1);
    }

    function testNonOwnerCannotBatchAddToWhitelist() public {
        address[] memory addrs = new address[](1);
        addrs[0] = ADDRESS1;
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, ATTACKER));
        rule.addWhitelistAddresses(addrs);
    }

    /*//////////////////////////////////////////////////////////////
                    FROZENLIST — NON-OWNER CANNOT MANAGE
    //////////////////////////////////////////////////////////////*/

    function testNonOwnerCannotAddToFrozenlist() public {
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, ATTACKER));
        rule.addFrozenlistAddress(ADDRESS1);
    }

    function testNonOwnerCannotRemoveFromFrozenlist() public {
        vm.prank(OWNER);
        rule.addFrozenlistAddress(ADDRESS1);
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, ATTACKER));
        rule.removeFrozenlistAddress(ADDRESS1);
    }

    function testNonOwnerCannotBatchAddToFrozenlist() public {
        address[] memory addrs = new address[](1);
        addrs[0] = ADDRESS1;
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, ATTACKER));
        rule.addFrozenlistAddresses(addrs);
    }

    /// @notice `allowMintBurn` permits burning via the explicit flag, without listing the sentinel.
    function testAllowMintBurnConstructorSetsFlagsAndDoesNotListZeroAddress() public {
        RuleERC2980Ownable2Step burnEnabled = new RuleERC2980Ownable2Step(OWNER, ZERO_ADDRESS, true);
        assertTrue(burnEnabled.allowMint());
        assertTrue(burnEnabled.allowBurn());
        assertFalse(burnEnabled.isWhitelisted(ZERO_ADDRESS));
        assertFalse(burnEnabled.whitelist(ZERO_ADDRESS));
    }
}
