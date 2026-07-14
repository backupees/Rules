// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";

/**
 * @title General functions of the RuleWhitelist
 */
contract RuleWhitelistTest is Test, HelperContract {
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
    }

    function testReturnFalseIfAddressNotWhitelisted() public {
        // Act
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        // Assert
        assertFalse(resBool);
        // Act
        resBool = ruleWhitelist.isAddressListed(ADDRESS2);
        // Assert
        assertFalse(resBool);
        // Act
        resBool = ruleWhitelist.isAddressListed(ADDRESS3);
        // Assert
        assertFalse(resBool);
        // Act
        resBool = ruleWhitelist.isAddressListed(address(0x0));
        // Assert
        assertFalse(resBool);
    }

    function testAddressIsIndicatedAsWhitelisted() public {
        // Arrange - Assert
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertFalse(resBool);

        // Act
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);

        // Assert
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        assertEq(resBool, true);
    }

    /// @notice `allowMintBurn` sets the explicit flags and NEVER lists the zero address, so the
    ///         standardized identity getters stay truthful (ERC-3643: `isVerified` means
    ///         "valid investor holding the required claims"; the zero address is neither).
    function testAllowMintBurnConstructorSetsFlagsAndDoesNotListZeroAddress() public {
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        RuleWhitelist mintBurnEnabled = new RuleWhitelist(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, true, true);

        assertTrue(mintBurnEnabled.allowMint());
        assertTrue(mintBurnEnabled.allowBurn());

        // The sentinel is NOT a list member, and the getters say so.
        assertFalse(mintBurnEnabled.isAddressListed(ZERO_ADDRESS));
        assertFalse(mintBurnEnabled.isVerified(ZERO_ADDRESS));
        assertFalse(mintBurnEnabled.contains(ZERO_ADDRESS));
        assertEq(mintBurnEnabled.listedAddressCount(), 0);
    }

    /// @notice With `allowMintBurn = false` the operations are refused with dedicated codes.
    function testMintBurnDisabledReturnsDedicatedCodes() public {
        vm.startPrank(WHITELIST_OPERATOR_ADDRESS);
        RuleWhitelist noMintBurn = new RuleWhitelist(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, false, false);
        noMintBurn.addAddress(ADDRESS1);
        vm.stopPrank();

        assertFalse(noMintBurn.allowMint());
        assertFalse(noMintBurn.allowBurn());
        assertEq(noMintBurn.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 10), CODE_MINT_NOT_ALLOWED);
        assertEq(noMintBurn.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 10), CODE_BURN_NOT_ALLOWED);
    }

    /// @notice The flags are independently settable at runtime (e.g. close issuance, keep redemptions).
    function testAllowMintAndAllowBurnAreIndependentlySettable() public {
        vm.startPrank(WHITELIST_OPERATOR_ADDRESS);
        RuleWhitelist rule = new RuleWhitelist(WHITELIST_OPERATOR_ADDRESS, ZERO_ADDRESS, false, true);
        rule.addAddress(ADDRESS1);

        // Permanently close issuance, still allow redemption.
        rule.setAllowMint(false);
        vm.stopPrank();

        assertFalse(rule.allowMint());
        assertTrue(rule.allowBurn());
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 10), CODE_MINT_NOT_ALLOWED);
        assertEq(rule.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 10), TRANSFER_OK);
    }

    function testContainsReflectsListingStatus() public {
        // Act - Assert
        assertFalse(ruleWhitelist.contains(ADDRESS1));

        // Arrange
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);

        // Act - Assert
        assertTrue(ruleWhitelist.contains(ADDRESS1));
    }

    function testIsVerifiedReflectsListingStatus() public {
        assertFalse(ruleWhitelist.isVerified(ADDRESS1));

        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);

        assertTrue(ruleWhitelist.isVerified(ADDRESS1));
    }

    function testAddressesIsIndicatedAsWhitelisted() public {
        // Arrange
        _addAddresses();
        // Act
        resBool = ruleWhitelist.isAddressListed(ADDRESS1);
        // Assert
        assertEq(resBool, true);
        // Act
        resBool = ruleWhitelist.isAddressListed(ADDRESS2);
        // Assert
        assertEq(resBool, true);
        // Act
        resBool = ruleWhitelist.isAddressListed(ADDRESS3);
        // Assert
        assertFalse(resBool);
    }

    function testCanReturnTransferRestrictionCode() public {
        // Act
        resBool = ruleWhitelist.canReturnTransferRestrictionCode(CODE_ADDRESS_FROM_NOT_WHITELISTED);
        // Assert
        assertEq(resBool, true);
        // Act
        resBool = ruleWhitelist.canReturnTransferRestrictionCode(CODE_ADDRESS_TO_NOT_WHITELISTED);
        // Assert
        assertEq(resBool, true);
        // Act
        resBool = ruleWhitelist.canReturnTransferRestrictionCode(CODE_NONEXISTENT);
        // Assert
        assertFalse(resBool);
    }

    function testReturnTheRightMessageForAGivenCode() public {
        // Assert
        resString = ruleWhitelist.messageForTransferRestriction(CODE_ADDRESS_FROM_NOT_WHITELISTED);
        // Assert
        assertEq(resString, TEXT_ADDRESS_FROM_NOT_WHITELISTED);
        // Act
        resString = ruleWhitelist.messageForTransferRestriction(CODE_ADDRESS_TO_NOT_WHITELISTED);
        // Assert
        assertEq(resString, TEXT_ADDRESS_TO_NOT_WHITELISTED);

        // Act
        resString = ruleWhitelist.messageForTransferRestriction(CODE_ADDRESS_SPENDER_NOT_WHITELISTED);
        // Assert
        assertEq(resString, TEXT_ADDRESS_SPENDER_NOT_WHITELISTED);

        // Act
        resString = ruleWhitelist.messageForTransferRestriction(CODE_NONEXISTENT);
        // Assert
        assertEq(resString, TEXT_CODE_NOT_FOUND);
    }

    function testcanTransfer() public {
        // Arrange
        _addAddresses();
        // Act
        // ADDRESS1 -> ADDRESS2
        resBool = ruleWhitelist.canTransfer(ADDRESS1, ADDRESS2, 20);
        assertEq(resBool, true);
        resBool = ruleWhitelist.canTransfer(ADDRESS1, ADDRESS2, 0, 20);
        assertEq(resBool, true);
        // ADDRESS2 -> ADDRESS1
        resBool = ruleWhitelist.canTransfer(ADDRESS2, ADDRESS1, 20);
        assertEq(resBool, true);

        resBool = ruleWhitelist.canTransfer(ADDRESS2, ADDRESS1, 0, 20);
        assertEq(resBool, true);
    }

    function testTransferDetectedAsInvalid() public {
        // Act
        resBool = ruleWhitelist.canTransfer(ADDRESS1, ADDRESS2, 20);
        // Assert
        assertFalse(resBool);

        // Act
        resBool = ruleWhitelist.canTransfer(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertFalse(resBool);
    }

    function testlistedAddressCount() public {
        // Act
        resUint256 = ruleWhitelist.listedAddressCount();
        // Assert
        assertEq(resUint256, 0);

        // Arrange
        address[] memory whitelist = new address[](2);
        whitelist[0] = ADDRESS1;
        whitelist[1] = ADDRESS2;
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        (resCallBool,) = address(ruleWhitelist).call(abi.encodeWithSignature("addAddresses(address[])", whitelist));
        assertEq(resCallBool, true);
        // Act
        resUint256 = ruleWhitelist.listedAddressCount();
        // Assert
        assertEq(resUint256, 2);
        // Arrange
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        (resCallBool,) = address(ruleWhitelist).call(abi.encodeWithSignature("removeAddresses(address[])", whitelist));
        // Arrange - Assert
        assertEq(resCallBool, true);
        // Act
        resUint256 = ruleWhitelist.listedAddressCount();
        // Assert
        assertEq(resUint256, 0);
    }

    function testDetectTransferRestrictionFrom() public {
        // Act
        resUint8 = ruleWhitelist.detectTransferRestriction(ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resUint8, CODE_ADDRESS_FROM_NOT_WHITELISTED);

        // Act
        resBool = ruleWhitelist.canTransfer(ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resBool, false);

        // Act
        resBool = ruleWhitelist.canTransfer(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resBool, false);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleWhitelist_InvalidTransfer.selector,
                address(ruleWhitelist),
                ADDRESS1,
                ADDRESS2,
                20,
                CODE_ADDRESS_FROM_NOT_WHITELISTED
            )
        );
        // Act
        ruleWhitelist.transferred(ADDRESS1, ADDRESS2, 20);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleWhitelist_InvalidTransfer.selector,
                address(ruleWhitelist),
                ADDRESS1,
                ADDRESS2,
                20,
                CODE_ADDRESS_FROM_NOT_WHITELISTED
            )
        );
        ruleWhitelist.transferred(ADDRESS1, ADDRESS2, 0, 20);
    }

    function testDetectTransferRestrictionTo() public {
        // Arrange
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        // Act
        resUint8 = ruleWhitelist.detectTransferRestriction(ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resUint8, CODE_ADDRESS_TO_NOT_WHITELISTED);

        // With tokenId
        resUint8 = ruleWhitelist.detectTransferRestriction(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resUint8, CODE_ADDRESS_TO_NOT_WHITELISTED);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleWhitelist_InvalidTransfer.selector,
                address(ruleWhitelist),
                ADDRESS1,
                ADDRESS2,
                20,
                CODE_ADDRESS_TO_NOT_WHITELISTED
            )
        );
        // Act
        ruleWhitelist.transferred(ADDRESS1, ADDRESS2, 20);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleWhitelist_InvalidTransfer.selector,
                address(ruleWhitelist),
                ADDRESS1,
                ADDRESS2,
                20,
                CODE_ADDRESS_TO_NOT_WHITELISTED
            )
        );
        ruleWhitelist.transferred(ADDRESS1, ADDRESS2, 0, 20);
    }

    function testDetectTransferRestrictionWithSpender() public {
        // Arrange
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);

        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS2);
        // Act
        resUint8 = ruleWhitelist.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resUint8, CODE_ADDRESS_SPENDER_NOT_WHITELISTED);

        // Act
        resBool = ruleWhitelist.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resBool, false);

        // With tokenId
        resUint8 = ruleWhitelist.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resUint8, CODE_ADDRESS_SPENDER_NOT_WHITELISTED);

        // Act
        resBool = ruleWhitelist.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resBool, false);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleWhitelist_InvalidTransferFrom.selector,
                address(ruleWhitelist),
                ADDRESS3,
                ADDRESS1,
                ADDRESS2,
                20,
                CODE_ADDRESS_SPENDER_NOT_WHITELISTED
            )
        );
        // Act
        ruleWhitelist.transferred(ADDRESS3, ADDRESS1, ADDRESS2, 20);

        vm.prank(ADDRESS1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleWhitelist_InvalidTransferFrom.selector,
                address(ruleWhitelist),
                ADDRESS3,
                ADDRESS1,
                ADDRESS2,
                20,
                CODE_ADDRESS_SPENDER_NOT_WHITELISTED
            )
        );
        ruleWhitelist.transferred(ADDRESS3, ADDRESS1, ADDRESS2, 0, 20);
    }

    function testDetectTransferRestrictionOk() public {
        // Arrange
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS2);
        // Act
        resUint8 = ruleWhitelist.detectTransferRestriction(ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resUint8, NO_ERROR);

        // With tokenId
        resUint8 = ruleWhitelist.detectTransferRestriction(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resUint8, NO_ERROR);

        // With tokenId
        resUint8 = ruleWhitelist.detectTransferRestriction(ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resUint8, NO_ERROR);
    }

    function testDetectTransferRestrictionWithSpenderOk() public {
        // Arrange
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS1);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS2);
        vm.prank(WHITELIST_OPERATOR_ADDRESS);
        ruleWhitelist.addAddress(ADDRESS3);
        // Act
        resUint8 = ruleWhitelist.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resUint8, NO_ERROR);

        // Act
        resBool = ruleWhitelist.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        // Assert
        assertEq(resBool, true);

        // Act
        resBool = ruleWhitelist.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resBool, true);

        // With tokenId
        resUint8 = ruleWhitelist.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 0, 20);
        // Assert
        assertEq(resUint8, NO_ERROR);

        // No revert
        // Act
        ruleWhitelist.transferred(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        ruleWhitelist.transferred(ADDRESS3, ADDRESS1, ADDRESS2, 0, 20);
    }
}
