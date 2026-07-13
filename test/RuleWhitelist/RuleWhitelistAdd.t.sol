// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {IAddressList} from "src/rules/interfaces/IAddressList.sol";

/**
 * @title Tests the functions to add addresses to the whitelist
 */
contract RuleWhitelistAddTest is Test, HelperContract {
    // Arrange
    function setUp() public {
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist = new RuleWhitelist(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, true, false);
    }

    function _addAddresses() internal {
        address[] memory whitelist = new address[](2);
        whitelist[0] = ADDRESS1;
        whitelist[1] = ADDRESS2;
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
        address[] memory addressesListInput = new address[](2);
        addressesListInput[0] = ADDRESS1;
        addressesListInput[1] = ADDRESS2;
        bool[] memory resBools = ruleWhitelist.areAddressesListed(addressesListInput);
        assertEq(resBools[0], true);
        assertEq(resBools[1], true);
        assertEq(resBools.length, 2);
    }

    function testaddAddress() public {
        // Act
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        emit IAddressList.AddAddress(ADDRESS1);
        ruleWhitelist.addAddress(ADDRESS1);

        // Assert
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);
        address[] memory addressesListInput = new address[](1);
        addressesListInput[0] = ADDRESS1;
        bool[] memory resBools = ruleWhitelist.areAddressesListed(addressesListInput);
        assertEq(resBools[0], true);
        assertEq(resBools.length, 1);
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 1);
    }

    function testaddAddresses() public {
        // Arrange
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 0);
        // Act
        _addAddresses();
        // Assert
        resBool = ruleWhitelist.isAddressListed(ADDRESS3);
        assertFalse(resBool);
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 2);
    }

    /// @notice The zero address is the mint/burn sentinel, not a participant: it can never be listed.
    ///         Mint/burn permission is governed by the explicit `allowMint` / `allowBurn` flags.
    function testCannotAddAddressZeroToTheWhitelist() public {
        assertFalse(ruleWhitelist.isAddressListed(address(0x0)));

        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        vm.expectRevert(RuleAddressSet_ZeroAddressNotAllowed.selector);
        ruleWhitelist.addAddress(address(0x0));

        assertFalse(ruleWhitelist.isAddressListed(address(0x0)));
        assertEq(ruleWhitelist.listedAddressCount(), 0);
    }

    /// @notice Batch add SKIPS the zero address silently (non-reverting batch convention) while
    ///         still adding the real addresses. The sentinel never enters the list.
    function testAddAddressesSkipsZeroAddress() public {
        assertEq(ruleWhitelist.listedAddressCount(), 0);
        address[] memory whitelist = new address[](3);
        whitelist[0] = ADDRESS1;
        whitelist[1] = ADDRESS2;
        whitelist[2] = address(0x0);

        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddresses(whitelist);

        // The sentinel was skipped...
        assertFalse(ruleWhitelist.isAddressListed(address(0x0)));
        // ...but the real addresses were added.
        assertTrue(ruleWhitelist.isAddressListed(ADDRESS1));
        assertTrue(ruleWhitelist.isAddressListed(ADDRESS2));
        assertEq(ruleWhitelist.listedAddressCount(), 2);
    }

    function testAddAddressTwiceToTheWhitelist() public {
        // Arrange
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        // Arrange - Assert
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);
        /// Arrange
        vm.expectRevert(RuleAddressSet_AddressAlreadyListed.selector);
        // Act
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        // no change
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 1);
    }

    function testAddAddressesTwiceToTheWhitelist() public {
        // Arrange
        // Arrange - first addition
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 0);
        _addAddresses();
        // Arrange - second addition
        address[] memory whitelistDuplicate = new address[](3);
        // Duplicate address
        whitelistDuplicate[0] = ADDRESS1;
        whitelistDuplicate[1] = ADDRESS2;
        // new address in the whitelist
        whitelistDuplicate[2] = ADDRESS3;
        // Act
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        (resCallBool,) =
            address(ruleWhitelist).call(abi.encodeWithSignature("addAddresses(address[])", whitelistDuplicate));
        // Assert
        // no change
        assertEq(resCallBool, true);
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);
        resBool = ruleWhitelist.isAddressListed(ADDRESS2);
        assertEq(resBool, true);
        // ADDRESS3 is whitelisted
        resBool = ruleWhitelist.isAddressListed(ADDRESS3);
        assertEq(resBool, true);
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 3);
    }

    function testFuzz_AddRemoveIdempotent(address addressA, address addressB) public {
        // The zero address is the mint/burn sentinel and can never be listed.
        vm.assume(addressA != address(0) && addressB != address(0));
        address[] memory targets = new address[](3);
        targets[0] = addressA;
        targets[1] = addressB;
        targets[2] = addressA;

        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddresses(targets);

        uint256 expectedCount = addressA == addressB ? 1 : 2;
        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, expectedCount);

        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.removeAddresses(targets);

        resUint256 = ruleWhitelist.listedAddressCount();
        assertEq(resUint256, 0);
    }
}
