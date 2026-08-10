// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {IdentityRegistryWhitelist} from "src/registry/IdentityRegistryWhitelist.sol";
import {
    IdentityRegistryWhitelistInvariantStorage
} from "src/registry/abstract/IdentityRegistryWhitelistInvariantStorage.sol";

/**
 * @title Unit tests for IdentityRegistryWhitelist
 */
contract IdentityRegistryWhitelistUnit is Test, HelperContract, IdentityRegistryWhitelistInvariantStorage {
    address constant REGISTRAR = address(10);
    uint16 constant COUNTRY_CH = 756;

    IdentityRegistryWhitelist private registry;
    bytes32 private registrarRole;

    function setUp() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        registry = new IdentityRegistryWhitelist(DEFAULT_ADMIN_ADDRESS);
        registrarRole = registry.IDENTITY_REGISTRAR_ROLE();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        registry.grantRole(registrarRole, REGISTRAR);
    }

    /*//////////////////////////////////////////////////////////////
                            REGISTRATION
    //////////////////////////////////////////////////////////////*/

    function testRegisterIdentity_VerifiesTheWallet() public {
        assertFalse(registry.isVerified(ADDRESS1));

        vm.expectEmit(true, true, false, false);
        emit IdentityRegistered(ADDRESS1, ADDRESS3);
        vm.prank(REGISTRAR);
        registry.registerIdentity(ADDRESS1, ADDRESS3, COUNTRY_CH);

        assertTrue(registry.isVerified(ADDRESS1));
        assertEq(registry.registeredIdentityCount(), 1);
    }

    /**
     * @notice Re-registration is a no-op, not an error. Required so `recoveryAddress` can register
     *         a wallet the whitelist already contains.
     */
    function testRegisterIdentity_IsIdempotent() public {
        vm.prank(REGISTRAR);
        registry.registerIdentity(ADDRESS1, ADDRESS3, COUNTRY_CH);
        vm.prank(REGISTRAR);
        registry.registerIdentity(ADDRESS1, ADDRESS2, 250);

        assertTrue(registry.isVerified(ADDRESS1));
        assertEq(registry.registeredIdentityCount(), 1, "no duplicate entry");
    }

    /**
     * @notice No identity data is kept: the ONCHAINID and country arguments are accepted so the
     *         ERC-3643 signature matches, then discarded. `investorCountry` is a constant 0.
     */
    function testNoIdentityDataIsStored() public {
        assertEq(registry.investorCountry(ADDRESS1), 0, "unregistered");

        vm.prank(REGISTRAR);
        registry.registerIdentity(ADDRESS1, ADDRESS3, COUNTRY_CH);

        assertTrue(registry.isVerified(ADDRESS1));
        assertEq(registry.investorCountry(ADDRESS1), 0, "country discarded, not stored");
    }

    /**
     * @notice ERC-3643 defines `isVerified` as "is this a valid investor wallet"; `address(0)` is
     *         not a wallet, so it can never enter the registry.
     */
    function testRegisterIdentity_RejectsZeroAddress() public {
        vm.expectRevert(RuleAddressSet_ZeroAddressNotAllowed.selector);
        vm.prank(REGISTRAR);
        registry.registerIdentity(ZERO_ADDRESS, ADDRESS3, COUNTRY_CH);

        assertFalse(registry.isVerified(ZERO_ADDRESS));
    }

    function testRegisterIdentity_OnlyRegistrar() public {
        vm.expectRevert();
        vm.prank(ATTACKER);
        registry.registerIdentity(ADDRESS1, ADDRESS3, COUNTRY_CH);
    }

    /*//////////////////////////////////////////////////////////////
                             DELETION
    //////////////////////////////////////////////////////////////*/

    function testDeleteIdentity_RemovesTheWallet() public {
        vm.prank(REGISTRAR);
        registry.registerIdentity(ADDRESS1, ADDRESS3, COUNTRY_CH);

        vm.expectEmit(true, false, false, false);
        emit IdentityRemoved(ADDRESS1);
        vm.prank(REGISTRAR);
        registry.deleteIdentity(ADDRESS1);

        assertFalse(registry.isVerified(ADDRESS1));
        assertEq(registry.registeredIdentityCount(), 0);
    }

    function testDeleteIdentity_RevertsWhenNotRegistered() public {
        vm.expectRevert(RuleAddressSet_AddressNotFound.selector);
        vm.prank(REGISTRAR);
        registry.deleteIdentity(ADDRESS1);
    }

    function testDeleteIdentity_OnlyRegistrar() public {
        vm.prank(REGISTRAR);
        registry.registerIdentity(ADDRESS1, ADDRESS3, COUNTRY_CH);

        vm.expectRevert();
        vm.prank(ATTACKER);
        registry.deleteIdentity(ADDRESS1);
    }

    /*//////////////////////////////////////////////////////////////
                            KEY HAS PURPOSE
    //////////////////////////////////////////////////////////////*/

    function testKeyHasPurpose_TracksRegistration() public {
        bytes32 key = keccak256(abi.encode(ADDRESS1));
        assertFalse(registry.keyHasPurpose(key, 1), "unregistered");

        vm.prank(REGISTRAR);
        registry.registerIdentity(ADDRESS1, ADDRESS3, COUNTRY_CH);
        assertTrue(registry.keyHasPurpose(key, 1), "registered");

        vm.prank(REGISTRAR);
        registry.deleteIdentity(ADDRESS1);
        assertFalse(registry.keyHasPurpose(key, 1), "reverse index cleared on delete");
    }

    /**
     * @notice An unresolvable key maps to `address(0)`, which is never registered — fail-closed.
     */
    function testKeyHasPurpose_UnknownKeyIsRejected() public view {
        assertFalse(registry.keyHasPurpose(keccak256("not a wallet key"), 1));
        assertFalse(registry.keyHasPurpose(bytes32(0), 1));
    }

    /**
     * @notice The purpose argument is ignored: this is not a real ERC-734 identity. Pinned so the
     *         limitation is visible in the test suite, not only in the docs.
     */
    function testKeyHasPurpose_IgnoresThePurposeArgument() public {
        vm.prank(REGISTRAR);
        registry.registerIdentity(ADDRESS1, ADDRESS3, COUNTRY_CH);

        bytes32 key = keccak256(abi.encode(ADDRESS1));
        assertTrue(registry.keyHasPurpose(key, 1), "MANAGEMENT");
        assertTrue(registry.keyHasPurpose(key, 2), "ACTION - same answer");
        assertTrue(registry.keyHasPurpose(key, type(uint256).max), "any purpose - same answer");
    }

    /**
     * @notice The key derivation must match `Token.recoveryAddress` exactly, or recovery silently
     *         fails for every wallet.
     */
    function testKeyHasPurpose_UsesTheErc3643KeyDerivation() public {
        vm.prank(REGISTRAR);
        registry.registerIdentity(ADDRESS1, ADDRESS3, COUNTRY_CH);

        // keccak256(abi.encode(addr)) — NOT abi.encodePacked.
        assertTrue(registry.keyHasPurpose(keccak256(abi.encode(ADDRESS1)), 1));
        assertFalse(registry.keyHasPurpose(keccak256(abi.encodePacked(ADDRESS1)), 1));
    }
}
