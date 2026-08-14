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
     * @notice Duplicate registration reverts, matching ERC-3643's reference registry.
     */
    function testRegisterIdentity_RejectsDuplicates() public {
        vm.prank(REGISTRAR);
        registry.registerIdentity(ADDRESS1, ADDRESS3, COUNTRY_CH);

        vm.expectRevert(RuleAddressSet_AddressAlreadyListed.selector);
        vm.prank(REGISTRAR);
        registry.registerIdentity(ADDRESS1, ADDRESS2, 250);

        assertEq(registry.registeredIdentityCount(), 1);
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
                        NO INERT ROLES ON THE ABI
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The registry reuses `RuleAddressSetInternal` for storage, but must NOT advertise the
     *         address-list roles that gate `RuleAddressSet`'s public `addAddress` / `removeAddress`.
     *         It never enforces them -- registration is gated on `IDENTITY_REGISTRAR_ROLE` -- so
     *         exposing them would invite an operator to grant a privilege that authorises nothing,
     *         with no on-chain signal that the grant had no effect.
     * @dev Static-called rather than asserted through the type system, because the whole point is
     *      that these selectors are absent: referencing them in Solidity would not compile.
     */
    function testDoesNotExposeInertAddressListRoles() public view {
        (bool addFound,) = address(registry).staticcall(abi.encodeWithSignature("ADDRESS_LIST_ADD_ROLE()"));
        (bool removeFound,) = address(registry).staticcall(abi.encodeWithSignature("ADDRESS_LIST_REMOVE_ROLE()"));
        assertFalse(addFound, "ADDRESS_LIST_ADD_ROLE must not be on the registry ABI");
        assertFalse(removeFound, "ADDRESS_LIST_REMOVE_ROLE must not be on the registry ABI");

        // The role it does enforce is present.
        (bool registrarFound,) = address(registry).staticcall(abi.encodeWithSignature("IDENTITY_REGISTRAR_ROLE()"));
        assertTrue(registrarFound, "IDENTITY_REGISTRAR_ROLE must be exposed");
    }
}
