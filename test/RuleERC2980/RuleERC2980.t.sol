// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleERC2980} from "src/rules/validation/deployment/RuleERC2980.sol";
import {
    RuleERC2980InvariantStorage
} from "src/rules/validation/abstract/RuleERC2980/invariantStorage/RuleERC2980InvariantStorage.sol";

contract RuleERC2980Test is Test, HelperContract {
    RuleERC2980 public ruleERC2980;

    // Local aliases for ERC-2980 restriction codes (avoid inheriting conflicting invariant storage)
    uint8 constant CODE_FROM_FROZEN = 60;
    uint8 constant CODE_TO_FROZEN = 61;
    uint8 constant CODE_SPENDER_FROZEN = 62;
    uint8 constant CODE_TO_NOT_WHITELISTED = 63;
    uint8 constant CODE_ERC2980_MINT_NOT_ALLOWED = 64;
    uint8 constant CODE_ERC2980_BURN_NOT_ALLOWED = 65;

    function setUp() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980 = new RuleERC2980(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false);

        // Whitelist ADDRESS2 (recipient) so transfer tests can focus on the specific check
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.addWhitelistAddress(ADDRESS2);
    }

    /*//////////////////////////////////////////////////////////////
                    MESSAGE FOR RESTRICTION CODE
    //////////////////////////////////////////////////////////////*/

    function testReturnTheRightMessageForAGivenCode() public view {
        assertEq(ruleERC2980.messageForTransferRestriction(CODE_FROM_FROZEN), "The sender address is frozen");
        assertEq(ruleERC2980.messageForTransferRestriction(CODE_TO_FROZEN), "The recipient address is frozen");
        assertEq(ruleERC2980.messageForTransferRestriction(CODE_SPENDER_FROZEN), "The spender address is frozen");
        assertEq(
            ruleERC2980.messageForTransferRestriction(CODE_TO_NOT_WHITELISTED), "The recipient is not in the whitelist"
        );
        assertEq(ruleERC2980.messageForTransferRestriction(CODE_NONEXISTENT), TEXT_CODE_NOT_FOUND);
    }

    function testCanReturnTransferRestrictionCode() public view {
        assertTrue(ruleERC2980.canReturnTransferRestrictionCode(CODE_FROM_FROZEN));
        assertTrue(ruleERC2980.canReturnTransferRestrictionCode(CODE_TO_FROZEN));
        assertTrue(ruleERC2980.canReturnTransferRestrictionCode(CODE_SPENDER_FROZEN));
        assertTrue(ruleERC2980.canReturnTransferRestrictionCode(CODE_TO_NOT_WHITELISTED));
        assertFalse(ruleERC2980.canReturnTransferRestrictionCode(CODE_NONEXISTENT));
    }

    /*//////////////////////////////////////////////////////////////
                         TRANSFER OK
    //////////////////////////////////////////////////////////////*/

    function testDetectTransferRestrictionOk() public {
        // ADDRESS1 (from) not whitelisted but can still send; ADDRESS2 (to) is whitelisted
        resUint8 = ruleERC2980.detectTransferRestriction(ADDRESS1, ADDRESS2, 20);
        assertEq(resUint8, NO_ERROR);

        // With tokenId
        resUint8 = ruleERC2980.detectTransferRestriction(ADDRESS1, ADDRESS2, 0, 20);
        assertEq(resUint8, NO_ERROR);

        resBool = ruleERC2980.canTransfer(ADDRESS1, ADDRESS2, 20);
        assertTrue(resBool);

        // No revert
        ruleERC2980.transferred(ADDRESS1, ADDRESS2, 20);
        ruleERC2980.transferred(ADDRESS1, ADDRESS2, 0, 20);
    }

    /*//////////////////////////////////////////////////////////////
                    WHITELIST — RECIPIENT NOT WHITELISTED
    //////////////////////////////////////////////////////////////*/

    function testDetectTransferRestrictionToNotWhitelisted() public {
        // ADDRESS3 is not whitelisted
        resUint8 = ruleERC2980.detectTransferRestriction(ADDRESS1, ADDRESS3, 20);
        assertEq(resUint8, CODE_TO_NOT_WHITELISTED);

        resUint8 = ruleERC2980.detectTransferRestriction(ADDRESS1, ADDRESS3, 0, 20);
        assertEq(resUint8, CODE_TO_NOT_WHITELISTED);

        resBool = ruleERC2980.canTransfer(ADDRESS1, ADDRESS3, 20);
        assertFalse(resBool);

        vm.expectRevert(
            abi.encodeWithSelector(
                RuleERC2980InvariantStorage.RuleERC2980_InvalidTransfer.selector,
                address(ruleERC2980),
                ADDRESS1,
                ADDRESS3,
                20,
                CODE_TO_NOT_WHITELISTED
            )
        );
        ruleERC2980.transferred(ADDRESS1, ADDRESS3, 20);
    }

    function testSenderDoesNotNeedToBeWhitelisted() public {
        // ADDRESS1 is not whitelisted but can still send to whitelisted ADDRESS2
        assertFalse(ruleERC2980.whitelist(ADDRESS1));
        resUint8 = ruleERC2980.detectTransferRestriction(ADDRESS1, ADDRESS2, 50);
        assertEq(resUint8, NO_ERROR);
    }

    /// @notice With `allowMintBurn = false`, a burn is refused with the DEDICATED code, not with
    ///         "recipient not whitelisted" — the zero address is a sentinel, not a recipient.
    function testBurnRefusedWithDedicatedCodeByDefault() public {
        assertFalse(ruleERC2980.allowBurn());
        assertFalse(ruleERC2980.whitelist(ZERO_ADDRESS));
        resUint8 = ruleERC2980.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 20);
        assertEq(resUint8, CODE_ERC2980_BURN_NOT_ALLOWED);
    }

    /// @notice `allowMintBurn` permits burning WITHOUT whitelisting the zero address, so the
    ///         MANDATORY ERC-2980 getter `whitelist(address(0))` stays truthful (`false`).
    function testAllowMintBurnConstructorPermitsBurnWithoutWhitelistingZeroAddress() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleERC2980 burnEnabledRule = new RuleERC2980(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, true);

        assertTrue(burnEnabledRule.allowMint());
        assertTrue(burnEnabledRule.allowBurn());

        // The ERC-2980 mandatory getter no longer lies about the sentinel.
        assertFalse(burnEnabledRule.whitelist(ZERO_ADDRESS));
        assertFalse(burnEnabledRule.isWhitelisted(ZERO_ADDRESS));
        assertFalse(burnEnabledRule.frozenlist(ZERO_ADDRESS));
        assertFalse(burnEnabledRule.isVerified(ZERO_ADDRESS));

        resUint8 = burnEnabledRule.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 20);
        assertEq(resUint8, NO_ERROR);
    }

    /// @notice The zero address can never enter either ERC-2980 list.
    function testCannotListZeroAddress() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(RuleERC2980InvariantStorage.RuleERC2980_ZeroAddressNotAllowed.selector);
        ruleERC2980.addWhitelistAddress(ZERO_ADDRESS);

        vm.expectRevert(RuleERC2980InvariantStorage.RuleERC2980_ZeroAddressNotAllowed.selector);
        ruleERC2980.addFrozenlistAddress(ZERO_ADDRESS);
        vm.stopPrank();

        assertFalse(ruleERC2980.whitelist(ZERO_ADDRESS));
        assertFalse(ruleERC2980.frozenlist(ZERO_ADDRESS));
    }

    /*//////////////////////////////////////////////////////////////
                      FROZENLIST — SENDER FROZEN
    //////////////////////////////////////////////////////////////*/

    function testDetectTransferRestrictionFromFrozen() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.addFrozenlistAddress(ADDRESS1);

        resUint8 = ruleERC2980.detectTransferRestriction(ADDRESS1, ADDRESS2, 20);
        assertEq(resUint8, CODE_FROM_FROZEN);

        resUint8 = ruleERC2980.detectTransferRestriction(ADDRESS1, ADDRESS2, 0, 20);
        assertEq(resUint8, CODE_FROM_FROZEN);

        resBool = ruleERC2980.canTransfer(ADDRESS1, ADDRESS2, 20);
        assertFalse(resBool);

        vm.expectRevert(
            abi.encodeWithSelector(
                RuleERC2980InvariantStorage.RuleERC2980_InvalidTransfer.selector,
                address(ruleERC2980),
                ADDRESS1,
                ADDRESS2,
                20,
                CODE_FROM_FROZEN
            )
        );
        ruleERC2980.transferred(ADDRESS1, ADDRESS2, 20);
    }

    /*//////////////////////////////////////////////////////////////
                      FROZENLIST — RECIPIENT FROZEN
    //////////////////////////////////////////////////////////////*/

    function testDetectTransferRestrictionToFrozen() public {
        // ADDRESS2 is whitelisted (setUp), freeze it — frozen takes priority
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.addFrozenlistAddress(ADDRESS2);

        resUint8 = ruleERC2980.detectTransferRestriction(ADDRESS1, ADDRESS2, 20);
        assertEq(resUint8, CODE_TO_FROZEN);

        resBool = ruleERC2980.canTransfer(ADDRESS1, ADDRESS2, 20);
        assertFalse(resBool);

        vm.expectRevert(
            abi.encodeWithSelector(
                RuleERC2980InvariantStorage.RuleERC2980_InvalidTransfer.selector,
                address(ruleERC2980),
                ADDRESS1,
                ADDRESS2,
                20,
                CODE_TO_FROZEN
            )
        );
        ruleERC2980.transferred(ADDRESS1, ADDRESS2, 20);
    }

    function testFrozenPriorityOverWhitelist() public {
        // ADDRESS2 is whitelisted (setUp), also freeze it
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.addFrozenlistAddress(ADDRESS2);

        assertTrue(ruleERC2980.whitelist(ADDRESS2));
        assertTrue(ruleERC2980.frozenlist(ADDRESS2));

        resUint8 = ruleERC2980.detectTransferRestriction(ADDRESS1, ADDRESS2, 10);
        assertEq(resUint8, CODE_TO_FROZEN);
    }

    /*//////////////////////////////////////////////////////////////
                      FROZENLIST — SPENDER FROZEN
    //////////////////////////////////////////////////////////////*/

    function testDetectTransferRestrictionFromSpenderFrozen() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.addFrozenlistAddress(ADDRESS3);

        resUint8 = ruleERC2980.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        assertEq(resUint8, CODE_SPENDER_FROZEN);

        resUint8 = ruleERC2980.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 0, 20);
        assertEq(resUint8, CODE_SPENDER_FROZEN);

        resBool = ruleERC2980.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        assertFalse(resBool);

        vm.expectRevert(
            abi.encodeWithSelector(
                RuleERC2980InvariantStorage.RuleERC2980_InvalidTransferFrom.selector,
                address(ruleERC2980),
                ADDRESS3,
                ADDRESS1,
                ADDRESS2,
                20,
                CODE_SPENDER_FROZEN
            )
        );
        ruleERC2980.transferred(ADDRESS3, ADDRESS1, ADDRESS2, 20);
    }

    function testDetectTransferRestrictionFromSpenderOk() public {
        resUint8 = ruleERC2980.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        assertEq(resUint8, NO_ERROR);

        resBool = ruleERC2980.canTransferFrom(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        assertTrue(resBool);

        // No revert
        ruleERC2980.transferred(ADDRESS3, ADDRESS1, ADDRESS2, 20);
        ruleERC2980.transferred(ADDRESS3, ADDRESS1, ADDRESS2, 0, 20);
    }

    /*//////////////////////////////////////////////////////////////
                          IS VERIFIED
    //////////////////////////////////////////////////////////////*/

    function testIsVerifiedWhitelisted() public view {
        // ADDRESS2 is whitelisted in setUp
        assertTrue(ruleERC2980.isVerified(ADDRESS2));
    }

    function testIsVerifiedNotWhitelisted() public view {
        assertFalse(ruleERC2980.isVerified(ADDRESS1));
    }

    function testIsVerifiedWhitelistedButFrozenStillVerified() public {
        // Frozen status must NOT affect isVerified — whitelist membership is the identity check
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.addFrozenlistAddress(ADDRESS2);

        assertTrue(ruleERC2980.whitelist(ADDRESS2));
        assertTrue(ruleERC2980.frozenlist(ADDRESS2));
        assertTrue(ruleERC2980.isVerified(ADDRESS2));
    }

    /*//////////////////////////////////////////////////////////////
                         ERC-2980 GETTERS
    //////////////////////////////////////////////////////////////*/

    function testWhitelistGetter() public view {
        assertTrue(ruleERC2980.whitelist(ADDRESS2));
        assertFalse(ruleERC2980.whitelist(ADDRESS1));
    }

    function testFrozenlistGetter() public {
        assertFalse(ruleERC2980.frozenlist(ADDRESS1));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.addFrozenlistAddress(ADDRESS1);
        assertTrue(ruleERC2980.frozenlist(ADDRESS1));
    }

    /*//////////////////////////////////////////////////////////////
                     WHITELIST MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function testAddWhitelistAddress() public {
        assertFalse(ruleERC2980.isWhitelisted(ADDRESS1));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.addWhitelistAddress(ADDRESS1);
        assertTrue(ruleERC2980.isWhitelisted(ADDRESS1));
        assertEq(ruleERC2980.whitelistAddressCount(), 2);
    }

    function testAddWhitelistAddressAlreadyListedReverts() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(RuleERC2980InvariantStorage.RuleERC2980_AddressAlreadyWhitelisted.selector);
        ruleERC2980.addWhitelistAddress(ADDRESS2);
    }

    function testRemoveWhitelistAddress() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.removeWhitelistAddress(ADDRESS2);
        assertFalse(ruleERC2980.isWhitelisted(ADDRESS2));
        assertEq(ruleERC2980.whitelistAddressCount(), 0);
    }

    function testRemoveWhitelistAddressNotFoundReverts() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(RuleERC2980InvariantStorage.RuleERC2980_AddressNotWhitelisted.selector);
        ruleERC2980.removeWhitelistAddress(ADDRESS1);
    }

    function testAddWhitelistAddresses() public {
        address[] memory toAdd = new address[](2);
        toAdd[0] = ADDRESS1;
        toAdd[1] = ADDRESS3;

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.addWhitelistAddresses(toAdd);

        assertTrue(ruleERC2980.isWhitelisted(ADDRESS1));
        assertTrue(ruleERC2980.isWhitelisted(ADDRESS3));
        assertEq(ruleERC2980.whitelistAddressCount(), 3);
    }

    function testRemoveWhitelistAddresses() public {
        address[] memory toRemove = new address[](1);
        toRemove[0] = ADDRESS2;

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.removeWhitelistAddresses(toRemove);

        assertFalse(ruleERC2980.isWhitelisted(ADDRESS2));
    }

    function testAreWhitelisted() public view {
        address[] memory addrs = new address[](2);
        addrs[0] = ADDRESS1;
        addrs[1] = ADDRESS2;
        bool[] memory results = ruleERC2980.areWhitelisted(addrs);
        assertFalse(results[0]);
        assertTrue(results[1]);
    }

    /*//////////////////////////////////////////////////////////////
                    FROZENLIST MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function testAddFrozenlistAddress() public {
        assertFalse(ruleERC2980.isFrozen(ADDRESS1));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.addFrozenlistAddress(ADDRESS1);
        assertTrue(ruleERC2980.isFrozen(ADDRESS1));
        assertEq(ruleERC2980.frozenlistAddressCount(), 1);
    }

    function testAddFrozenlistAddressAlreadyListedReverts() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.addFrozenlistAddress(ADDRESS1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(RuleERC2980InvariantStorage.RuleERC2980_AddressAlreadyFrozen.selector);
        ruleERC2980.addFrozenlistAddress(ADDRESS1);
    }

    function testRemoveFrozenlistAddress() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.addFrozenlistAddress(ADDRESS1);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.removeFrozenlistAddress(ADDRESS1);
        assertFalse(ruleERC2980.isFrozen(ADDRESS1));
    }

    function testRemoveFrozenlistAddressNotFoundReverts() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        vm.expectRevert(RuleERC2980InvariantStorage.RuleERC2980_AddressNotFrozen.selector);
        ruleERC2980.removeFrozenlistAddress(ADDRESS1);
    }

    function testAddFrozenlistAddresses() public {
        address[] memory toFreeze = new address[](2);
        toFreeze[0] = ADDRESS1;
        toFreeze[1] = ADDRESS3;

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.addFrozenlistAddresses(toFreeze);

        assertTrue(ruleERC2980.isFrozen(ADDRESS1));
        assertTrue(ruleERC2980.isFrozen(ADDRESS3));
        assertEq(ruleERC2980.frozenlistAddressCount(), 2);
    }

    function testRemoveFrozenlistAddresses() public {
        address[] memory toFreeze = new address[](1);
        toFreeze[0] = ADDRESS1;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.addFrozenlistAddresses(toFreeze);

        address[] memory toUnfreeze = new address[](1);
        toUnfreeze[0] = ADDRESS1;
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.removeFrozenlistAddresses(toUnfreeze);

        assertFalse(ruleERC2980.isFrozen(ADDRESS1));
    }

    function testAreFrozen() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.addFrozenlistAddress(ADDRESS1);

        address[] memory addrs = new address[](2);
        addrs[0] = ADDRESS1;
        addrs[1] = ADDRESS2;
        bool[] memory results = ruleERC2980.areFrozen(addrs);
        assertTrue(results[0]);
        assertFalse(results[1]);
    }

    function testBatchOperationsSkipDuplicatesAndMissingEntries() public {
        // Whitelist: duplicate entry should be skipped in batch add path.
        address[] memory whitelistToAdd = new address[](1);
        whitelistToAdd[0] = ADDRESS2; // already whitelisted in setUp
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.addWhitelistAddresses(whitelistToAdd);
        assertEq(ruleERC2980.whitelistAddressCount(), 1);

        // Whitelist: removing a missing address should be skipped in batch remove path.
        address[] memory whitelistToRemove = new address[](1);
        whitelistToRemove[0] = ADDRESS3; // not whitelisted
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.removeWhitelistAddresses(whitelistToRemove);
        assertEq(ruleERC2980.whitelistAddressCount(), 1);

        // Frozenlist: duplicate entry should be skipped in batch add path.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.addFrozenlistAddress(ADDRESS1);
        address[] memory frozenToAdd = new address[](1);
        frozenToAdd[0] = ADDRESS1; // already frozen
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.addFrozenlistAddresses(frozenToAdd);
        assertEq(ruleERC2980.frozenlistAddressCount(), 1);

        // Frozenlist: removing a missing address should be skipped in batch remove path.
        address[] memory frozenToRemove = new address[](1);
        frozenToRemove[0] = ADDRESS3; // not frozen
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        ruleERC2980.removeFrozenlistAddresses(frozenToRemove);
        assertEq(ruleERC2980.frozenlistAddressCount(), 1);
    }
}
