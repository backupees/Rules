// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {ERC3643TokenMock} from "src/mocks/ERC3643TokenMock.sol";
import {OnchainIdMock} from "src/mocks/OnchainIdMock.sol";
import {IdentityRegistryWhitelist} from "src/registry/IdentityRegistryWhitelist.sol";
import {
    IdentityRegistryWhitelistInvariantStorage
} from "src/registry/abstract/IdentityRegistryWhitelistInvariantStorage.sol";
import {IIdentityRegistryERC3643} from "src/registry/interfaces/IIdentityRegistryERC3643.sol";

/**
 * @title Integration tests: ERC-3643 token + IdentityRegistryWhitelist
 * @notice Exercises every ERC-3643 entrypoint that touches the identity registry -- `transfer`,
 *         `transferFrom`, `forcedTransfer`, `mint`, `burn` and `recoveryAddress` -- against the
 *         whitelist-backed registry, using a token whose registry call sequences are transcribed
 *         from the reference `Token.sol`.
 */
contract IdentityRegistryWhitelistERC3643 is Test, HelperContract, IdentityRegistryWhitelistInvariantStorage {
    address constant AGENT = address(10);
    address constant INVESTOR = address(11);
    address constant INVESTOR2 = address(12);
    address constant NEW_WALLET = address(13);
    address constant OUTSIDER = address(14);
    uint16 constant COUNTRY_CH = 756;

    IdentityRegistryWhitelist private registry;
    ERC3643TokenMock private token;
    OnchainIdMock private investorOnchainId;
    bytes32 private registrarRole;

    function setUp() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        registry = new IdentityRegistryWhitelist(DEFAULT_ADMIN_ADDRESS);

        token = new ERC3643TokenMock(IIdentityRegistryERC3643(address(registry)), AGENT);
        // The registry no longer answers `keyHasPurpose`; recovery uses a real ERC-734 identity.
        investorOnchainId = new OnchainIdMock();
        // Hoisted: an external call in an argument position would consume the vm.prank below.
        registrarRole = registry.IDENTITY_REGISTRAR_ROLE();

        // The operator maintains the whitelist...
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        registry.grantRole(registrarRole, AGENT);
        // ...and the TOKEN itself must hold the role, because `recoveryAddress` makes the token
        // call registerIdentity/deleteIdentity.
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        registry.grantRole(registrarRole, address(token));

        vm.prank(AGENT);
        registry.registerIdentity(INVESTOR, address(0), COUNTRY_CH);
        vm.prank(AGENT);
        registry.registerIdentity(INVESTOR2, address(0), COUNTRY_CH);
    }

    /*//////////////////////////////////////////////////////////////
                                MINT
    //////////////////////////////////////////////////////////////*/

    function testMint_ToVerifiedInvestor() public {
        vm.prank(AGENT);
        token.mint(INVESTOR, 100);
        assertEq(token.balanceOf(INVESTOR), 100);
    }

    function testMint_ToUnverifiedRecipientReverts() public {
        vm.prank(AGENT);
        vm.expectRevert("Identity is not verified.");
        token.mint(OUTSIDER, 100);
    }

    /**
     * @notice `address(0)` must never be verified, so the registry can never be tricked into
     *         authorising a mint to the zero address.
     */
    function testMint_ToZeroAddressReverts() public {
        assertFalse(registry.isVerified(ZERO_ADDRESS));
        vm.prank(AGENT);
        vm.expectRevert("Identity is not verified.");
        token.mint(ZERO_ADDRESS, 100);
    }

    /*//////////////////////////////////////////////////////////////
                              TRANSFER
    //////////////////////////////////////////////////////////////*/

    function testTransfer_BetweenVerifiedInvestors() public {
        vm.prank(AGENT);
        token.mint(INVESTOR, 100);

        vm.prank(INVESTOR);
        assertTrue(token.transfer(INVESTOR2, 40));
        assertEq(token.balanceOf(INVESTOR2), 40);
    }

    function testTransfer_ToUnverifiedRecipientReverts() public {
        vm.prank(AGENT);
        token.mint(INVESTOR, 100);

        vm.prank(INVESTOR);
        vm.expectRevert("Transfer not possible");
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transfer(OUTSIDER, 40);
    }

    /**
     * @notice ERC-3643 screens only the RECEIVER. A de-listed holder can still send, which is what
     *         lets a lapsed investor exit their position.
     */
    function testTransfer_DeListedSenderCanStillExit() public {
        vm.prank(AGENT);
        token.mint(INVESTOR, 100);

        vm.prank(AGENT);
        registry.deleteIdentity(INVESTOR);
        assertFalse(registry.isVerified(INVESTOR));

        vm.prank(INVESTOR);
        assertTrue(token.transfer(INVESTOR2, 100));
        assertEq(token.balanceOf(INVESTOR2), 100);
    }

    function testTransferFrom_ChecksTheRecipientOnly() public {
        vm.prank(AGENT);
        token.mint(INVESTOR, 100);

        vm.prank(OUTSIDER);
        assertTrue(token.transferFrom(INVESTOR, INVESTOR2, 30));

        vm.prank(OUTSIDER);
        vm.expectRevert("Transfer not possible");
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        token.transferFrom(INVESTOR, OUTSIDER, 30);
    }

    /*//////////////////////////////////////////////////////////////
                           FORCED TRANSFER
    //////////////////////////////////////////////////////////////*/

    function testForcedTransfer_ToVerifiedRecipient() public {
        vm.prank(AGENT);
        token.mint(INVESTOR, 100);

        vm.prank(AGENT);
        assertTrue(token.forcedTransfer(INVESTOR, INVESTOR2, 60));
        assertEq(token.balanceOf(INVESTOR2), 60);
    }

    /**
     * @notice `forcedTransfer` bypasses freezes but NOT the registry: the recipient must be
     *         verified even when an agent forces the move.
     */
    function testForcedTransfer_ToUnverifiedRecipientReverts() public {
        vm.prank(AGENT);
        token.mint(INVESTOR, 100);

        vm.prank(AGENT);
        vm.expectRevert("Transfer not possible");
        token.forcedTransfer(INVESTOR, OUTSIDER, 60);
    }

    /*//////////////////////////////////////////////////////////////
                                BURN
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice `burn` makes no registry call at all, so a de-listed holder can still be burned out.
     */
    function testBurn_WorksEvenForADeListedHolder() public {
        vm.prank(AGENT);
        token.mint(INVESTOR, 100);

        vm.prank(AGENT);
        registry.deleteIdentity(INVESTOR);

        vm.prank(AGENT);
        token.burn(INVESTOR, 100);
        assertEq(token.balanceOf(INVESTOR), 0);
        assertEq(token.totalSupply(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                           RECOVERY ADDRESS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The replacement wallet is whitelisted BY THE TOKEN during recovery, exactly as in
     *         stock ERC-3643 — it must not be pre-registered, or step 3 would hit the duplicate
     *         guard. The ONCHAINID vouching for the wallet is supplied by the agent.
     */
    function testRecoveryAddress_MovesThePositionToTheNewWallet() public {
        vm.prank(AGENT);
        token.mint(INVESTOR, 100);

        investorOnchainId.addWalletKey(NEW_WALLET, 1);
        assertFalse(registry.isVerified(NEW_WALLET), "not pre-registered");

        vm.prank(AGENT);
        assertTrue(token.recoveryAddress(INVESTOR, NEW_WALLET, address(investorOnchainId)));

        assertEq(token.balanceOf(NEW_WALLET), 100, "position moved");
        assertEq(token.balanceOf(INVESTOR), 0);
        assertFalse(registry.isVerified(INVESTOR), "lost wallet de-registered by the token");
        assertTrue(registry.isVerified(NEW_WALLET), "new wallet registered by the token");
    }

    /**
     * @notice Recovery is gated on the ONCHAINID vouching for the replacement wallet.
     */
    function testRecoveryAddress_RevertsWhenIdentityDoesNotVouchForTheWallet() public {
        vm.prank(AGENT);
        token.mint(INVESTOR, 100);

        vm.prank(AGENT);
        vm.expectRevert("Recovery not possible");
        token.recoveryAddress(INVESTOR, NEW_WALLET, address(investorOnchainId));
    }

    /**
     * @notice Without the registrar role the token cannot complete recovery: `registerIdentity` is
     *         called BY THE TOKEN.
     */
    function testRecoveryAddress_RevertsWhenTokenLacksTheRegistrarRole() public {
        vm.prank(AGENT);
        token.mint(INVESTOR, 100);
        investorOnchainId.addWalletKey(NEW_WALLET, 1);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        registry.revokeRole(registrarRole, address(token));

        vm.prank(AGENT);
        vm.expectRevert();
        token.recoveryAddress(INVESTOR, NEW_WALLET, address(investorOnchainId));
    }

    /**
     * @notice `recoveryAddress` reads `investorCountry(lostWallet)` and feeds it to
     *         `registerIdentity`. This registry keeps no country, so that round trip carries a
     *         constant 0 -- harmless, because the value is discarded on the way back in. The test
     *         pins that recovery still succeeds despite the registry having no identity data.
     */
    function testRecoveryAddress_SucceedsWithNoIdentityDataTracked() public {
        vm.prank(AGENT);
        token.mint(INVESTOR, 100);
        investorOnchainId.addWalletKey(NEW_WALLET, 1);

        assertEq(registry.investorCountry(INVESTOR), 0, "no country tracked");

        vm.prank(AGENT);
        assertTrue(token.recoveryAddress(INVESTOR, NEW_WALLET, address(investorOnchainId)));

        assertEq(token.balanceOf(NEW_WALLET), 100);
        assertEq(registry.investorCountry(NEW_WALLET), 0, "still none after recovery");
    }
}
