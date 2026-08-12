// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {IAddressList} from "src/rules/interfaces/IAddressList.sol";

/**
 * @title Tests the functions to remove addresses from the whitelist
 */
contract RuleWhitelistRemoveTest is Test, HelperContract {
    // Arrange
    function setUp() public {
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist = new RuleWhitelist(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, true, false);
    }

    function _addAddresses() internal {
        address[] memory whitelist = new address[](2);
        whitelist[0] = ADDRESS1;
        whitelist[1] = ADDRESS2;
        vm.expectEmit(true, true, true, true);
        emit IAddressList.AddAddresses(whitelist, 2, 0); // both new
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        (resCallBool,) = address(ruleWhitelist).call(abi.encodeWithSignature("addAddresses(address[])", whitelist));
        // Assert
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 2);
        assertEq(resCallBool, true);
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);
        resBool = ruleWhitelist.isAddressListed(ADDRESS2);
        assertEq(resBool, true);
    }

    function testRemoveAddress() public {
        // Arrange
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);

        // Arrange - Assert
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);

        // Act
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        emit IAddressList.RemoveAddress(ADDRESS1);
        ruleWhitelist.removeAddress(ADDRESS1);

        // Assert
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertFalse(resBool);
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 0);
    }

    function testRemoveAddressWhenArrayContainSeveralAddresses() public {
        // Arrange
        address[] memory whitelist = new address[](2);
        whitelist[0] = ADDRESS1;
        whitelist[1] = ADDRESS2;
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        (resCallBool,) = address(ruleWhitelist).call(abi.encodeWithSignature("addAddresses(address[])", whitelist));
        assertEq(resCallBool, true);
        // Arrange - Assert
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);
        resBool = ruleWhitelist.isAddressListed(ADDRESS2);
        assertEq(resBool, true);

        // Act
        vm.expectEmit(true, true, true, true);
        emit IAddressList.RemoveAddresses(whitelist, 2, 0); // both present
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        (resCallBool,) = address(ruleWhitelist).call(abi.encodeWithSignature("removeAddresses(address[])", whitelist));
        // Assert
        assertEq(resCallBool, true);
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertFalse(resBool);
        resBool = ruleWhitelist.isAddressListed(ADDRESS2);
        assertFalse(resBool);
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 0);
    }

    function testRemoveAddressNotPresentFromTheWhitelist() public {
        // Arrange
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertFalse(resBool);
        vm.expectRevert(RuleAddressSet_AddressNotFound.selector);

        // Act
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        emit IAddressList.RemoveAddress(ADDRESS1);
        ruleWhitelist.removeAddress(ADDRESS1);

        // Assert
        // no change
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertFalse(resBool);
    }

    function testRemoveAddressesNotPresentFromTheWhitelist() public {
        // Arrange
        _addAddresses();
        // Arrange
        address[] memory whitelistRemove = new address[](3);
        whitelistRemove[0] = ADDRESS1;
        whitelistRemove[1] = ADDRESS2;
        // Target Address - Not Present in the whitelist
        whitelistRemove[2] = ADDRESS3;

        // Act
        // The point of carrying the effect in the event: 3 submitted, only 2 were present.
        vm.expectEmit(true, true, true, true);
        emit IAddressList.RemoveAddresses(whitelistRemove, 2, 1);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        (resCallBool,) =
            address(ruleWhitelist).call(abi.encodeWithSignature("removeAddresses(address[])", whitelistRemove));
        // Assert
        assertEq(resCallBool, true);
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertFalse(resBool);
        resBool = ruleWhitelist.isAddressListed(ADDRESS2);
        assertFalse(resBool);
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 0);
    }
}
