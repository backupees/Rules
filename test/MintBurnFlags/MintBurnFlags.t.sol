// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";

import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {RuleWhitelistOwnable2Step} from "src/rules/validation/deployment/RuleWhitelistOwnable2Step.sol";
import {RuleWhitelistWrapper} from "src/rules/validation/deployment/RuleWhitelistWrapper.sol";
import {RuleWhitelistWrapperOwnable2Step} from "src/rules/validation/deployment/RuleWhitelistWrapperOwnable2Step.sol";
import {RuleERC2980} from "src/rules/validation/deployment/RuleERC2980.sol";
import {RuleERC2980Ownable2Step} from "src/rules/validation/deployment/RuleERC2980Ownable2Step.sol";

/**
 * @title MintBurnFlags
 * @notice Covers the explicit `allowMint` / `allowBurn` flags (improvement I-12) across ALL SIX
 *         deployments that carry them, including the access-control hook on each variant.
 * @dev The flags replaced the old "whitelist `address(0)` to enable mint/burn" idiom, which made the
 *      standardized getters assert falsehoods (`isVerified(0)` per ERC-3643; `whitelist(0)` per
 *      ERC-2980, a MANDATORY getter). The invariant these tests defend is:
 *
 *          mint/burn can be enabled WITHOUT the zero address ever entering a list.
 */
contract MintBurnFlags is Test, HelperContract {
    address private constant FORWARDER = address(0);
    address private constant OWNER = address(11);

    // ERC-2980 codes (local aliases: the whitelist family's 24/25 are inherited via HelperContract).
    uint8 private constant CODE_ERC2980_MINT_NOT_ALLOWED = 64;
    uint8 private constant CODE_ERC2980_BURN_NOT_ALLOWED = 65;

    /*//////////////////////////////////////////////////////////////
                    THE INVARIANT THAT MATTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice With mint/burn ENABLED, every standardized identity getter must still be truthful.
    function test_MintBurnEnabled_StandardizedGettersStayTruthful() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleWhitelist w = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, true);
        RuleERC2980 e = new RuleERC2980(DEFAULT_ADMIN_ADDRESS, FORWARDER, true);
        vm.stopPrank();

        assertTrue(w.allowMint() && w.allowBurn());
        assertTrue(e.allowMint() && e.allowBurn());

        // ERC-3643: `isVerified` means "a valid investor holding the required claims".
        assertFalse(w.isVerified(ZERO_ADDRESS));
        assertFalse(w.contains(ZERO_ADDRESS));
        assertFalse(w.isAddressListed(ZERO_ADDRESS));
        assertEq(w.listedAddressCount(), 0);

        // ERC-2980: `whitelist` / `frozenlist` are MANDATORY getters.
        assertFalse(e.whitelist(ZERO_ADDRESS));
        assertFalse(e.frozenlist(ZERO_ADDRESS));
        assertFalse(e.isVerified(ZERO_ADDRESS));
    }

    /*//////////////////////////////////////////////////////////////
                    RuleWhitelist (both variants)
    //////////////////////////////////////////////////////////////*/

    function test_Whitelist_SettersToggleBothFlagsIndependently() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleWhitelist w = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, true);
        w.addAddress(ADDRESS1);

        // Close issuance, keep redemptions open.
        w.setAllowMint(false);
        assertFalse(w.allowMint());
        assertTrue(w.allowBurn());
        assertEq(w.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 10), CODE_MINT_NOT_ALLOWED);
        assertEq(w.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 10), TRANSFER_OK);

        // Now also close redemptions.
        w.setAllowBurn(false);
        assertFalse(w.allowBurn());
        assertEq(w.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 10), CODE_BURN_NOT_ALLOWED);

        // Re-open both.
        w.setAllowMint(true);
        w.setAllowBurn(true);
        vm.stopPrank();

        assertEq(w.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 10), TRANSFER_OK);
        assertEq(w.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 10), TRANSFER_OK);
    }

    function test_Whitelist_SettersAreAdminOnly() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleWhitelist w = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, true);

        vm.prank(ATTACKER);
        vm.expectRevert();
        w.setAllowMint(false);

        vm.prank(ATTACKER);
        vm.expectRevert();
        w.setAllowBurn(false);

        assertTrue(w.allowMint() && w.allowBurn());
    }

    function test_WhitelistOwnable2Step_SettersAreOwnerOnly() public {
        RuleWhitelistOwnable2Step w = new RuleWhitelistOwnable2Step(OWNER, FORWARDER, false, false);
        assertFalse(w.allowMint());
        assertFalse(w.allowBurn());

        vm.prank(ATTACKER);
        vm.expectRevert();
        w.setAllowMint(true);

        vm.startPrank(OWNER);
        w.setAllowMint(true);
        w.setAllowBurn(true);
        vm.stopPrank();

        assertTrue(w.allowMint() && w.allowBurn());
        assertFalse(w.isVerified(ZERO_ADDRESS));
    }

    /*//////////////////////////////////////////////////////////////
                RuleWhitelistWrapper (both variants)
    //////////////////////////////////////////////////////////////*/

    function test_Wrapper_MintRequiresRecipientListedInAChild() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleWhitelist child = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, true);
        child.addAddress(ADDRESS1);

        RuleWhitelistWrapper wrapper = new RuleWhitelistWrapper(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, true);
        wrapper.addRule(IRule(address(child)));
        vm.stopPrank();

        // Mint to a listed recipient: allowed. The flag permits the OPERATION; the recipient is
        // still screened.
        assertEq(wrapper.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 10), TRANSFER_OK);
        // Mint to an UNLISTED recipient: still rejected.
        assertEq(wrapper.detectTransferRestriction(ZERO_ADDRESS, ATTACKER, 10), CODE_ADDRESS_TO_NOT_WHITELISTED);
        // Burn from a listed sender: allowed; from an unlisted sender: rejected.
        assertEq(wrapper.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 10), TRANSFER_OK);
        assertEq(wrapper.detectTransferRestriction(ATTACKER, ZERO_ADDRESS, 10), CODE_ADDRESS_FROM_NOT_WHITELISTED);

        // Disabling the flags refuses the operation outright.
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        wrapper.setAllowMint(false);
        wrapper.setAllowBurn(false);
        vm.stopPrank();
        assertEq(wrapper.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 10), CODE_MINT_NOT_ALLOWED);
        assertEq(wrapper.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 10), CODE_BURN_NOT_ALLOWED);
    }

    function test_Wrapper_SettersAreAdminOnly() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleWhitelistWrapper wrapper = new RuleWhitelistWrapper(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, true);

        vm.prank(ATTACKER);
        vm.expectRevert();
        wrapper.setAllowMint(false);
        assertTrue(wrapper.allowMint());
    }

    function test_WrapperOwnable2Step_SettersAreOwnerOnly() public {
        RuleWhitelistWrapperOwnable2Step wrapper = new RuleWhitelistWrapperOwnable2Step(OWNER, FORWARDER, false, false);

        vm.prank(ATTACKER);
        vm.expectRevert();
        wrapper.setAllowBurn(true);

        vm.startPrank(OWNER);
        wrapper.setAllowMint(true);
        wrapper.setAllowBurn(true);
        wrapper.setMaxRules(3); // also covers the wrapper's rules-limit hook
        vm.stopPrank();

        assertTrue(wrapper.allowMint() && wrapper.allowBurn());
        assertEq(wrapper.maxRules(), 3);
    }

    function test_Wrapper_SetMaxRulesIsRulesManagerOnly() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleWhitelistWrapper wrapper = new RuleWhitelistWrapper(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, true);

        vm.prank(ATTACKER);
        vm.expectRevert();
        wrapper.setMaxRules(3);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        wrapper.setMaxRules(3);
        assertEq(wrapper.maxRules(), 3);
    }

    /*//////////////////////////////////////////////////////////////
                    RuleERC2980 (both variants)
    //////////////////////////////////////////////////////////////*/

    function test_ERC2980_SettersToggleBothFlagsIndependently() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleERC2980 e = new RuleERC2980(DEFAULT_ADMIN_ADDRESS, FORWARDER, true);
        e.addWhitelistAddress(ADDRESS2);

        assertEq(e.detectTransferRestriction(ZERO_ADDRESS, ADDRESS2, 10), TRANSFER_OK);
        assertEq(e.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 10), TRANSFER_OK);

        e.setAllowMint(false);
        assertFalse(e.allowMint());
        assertTrue(e.allowBurn());
        assertEq(e.detectTransferRestriction(ZERO_ADDRESS, ADDRESS2, 10), CODE_ERC2980_MINT_NOT_ALLOWED);
        assertEq(e.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 10), TRANSFER_OK);

        e.setAllowBurn(false);
        assertEq(e.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 10), CODE_ERC2980_BURN_NOT_ALLOWED);
        vm.stopPrank();

        // A permitted mint still screens the recipient.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        e.setAllowMint(true);
        assertEq(e.detectTransferRestriction(ZERO_ADDRESS, ADDRESS3, 10), 63); // TO_NOT_WHITELISTED
    }

    function test_ERC2980_SettersAreAdminOnly() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleERC2980 e = new RuleERC2980(DEFAULT_ADMIN_ADDRESS, FORWARDER, true);

        vm.prank(ATTACKER);
        vm.expectRevert();
        e.setAllowMint(false);

        vm.prank(ATTACKER);
        vm.expectRevert();
        e.setAllowBurn(false);

        assertTrue(e.allowMint() && e.allowBurn());
    }

    function test_ERC2980Ownable2Step_SettersAreOwnerOnly() public {
        RuleERC2980Ownable2Step e = new RuleERC2980Ownable2Step(OWNER, FORWARDER, false);
        assertFalse(e.allowMint());
        assertFalse(e.allowBurn());

        vm.prank(ATTACKER);
        vm.expectRevert();
        e.setAllowMint(true);

        vm.startPrank(OWNER);
        e.setAllowMint(true);
        e.setAllowBurn(true);
        vm.stopPrank();

        assertTrue(e.allowMint() && e.allowBurn());
        assertFalse(e.whitelist(ZERO_ADDRESS));
    }

    /*//////////////////////////////////////////////////////////////
                THE SENTINEL CAN NEVER ENTER A LIST
    //////////////////////////////////////////////////////////////*/

    /// @notice Across every address-set rule, the zero address is rejected on a single add and
    ///         skipped on a batch add — so the getters are clean by construction.
    function test_ZeroAddressCanNeverBeListed() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleWhitelist w = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, true);

        vm.expectRevert(RuleAddressSet_ZeroAddressNotAllowed.selector);
        w.addAddress(ZERO_ADDRESS);

        // A batch containing the sentinel REVERTS: silently skipping it would make the emitted
        // `AddAddresses` event report a member that is not in the set.
        address[] memory bad = new address[](2);
        bad[0] = ZERO_ADDRESS;
        bad[1] = ADDRESS1;
        vm.expectRevert(RuleAddressSet_ZeroAddressNotAllowed.selector);
        w.addAddresses(bad);

        // A clean batch works, and duplicates are still skipped (the event stays truthful).
        address[] memory good = new address[](3);
        good[0] = ADDRESS1;
        good[1] = ADDRESS2;
        good[2] = ADDRESS1; // duplicate
        w.addAddresses(good);
        vm.stopPrank();

        assertFalse(w.isAddressListed(ZERO_ADDRESS));
        assertTrue(w.isAddressListed(ADDRESS1));
        assertTrue(w.isAddressListed(ADDRESS2));
        assertEq(w.listedAddressCount(), 2);
    }
}
