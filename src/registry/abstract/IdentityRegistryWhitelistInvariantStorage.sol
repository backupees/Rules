// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

/**
 * @title IdentityRegistryWhitelistInvariantStorage — constants, events and errors for the
 * whitelist-backed ERC-3643 identity registry.
 */
abstract contract IdentityRegistryWhitelistInvariantStorage {
    /* ============ Constants ============ */

    /**
     * @notice Role allowed to register and delete identities.
     * @dev The ERC-3643 token itself must hold this role, because `recoveryAddress` makes the token
     * call `registerIdentity` and `deleteIdentity` on the registry. See the technical doc.
     */
    bytes32 public constant IDENTITY_REGISTRAR_ROLE = keccak256("IDENTITY_REGISTRAR_ROLE");

    /**
     * @notice The ERC-734 purpose ERC-3643 checks in `recoveryAddress` (MANAGEMENT).
     */
    uint256 public constant ERC734_PURPOSE_MANAGEMENT = 1;

    /* ============ Events ============ */

    /**
     * @notice Emitted when a wallet is registered as a verified investor.
     * @param userAddress The registered wallet.
     * @param identity The ONCHAINID passed by the caller. Recorded in the event only; see
     * {IdentityRegistryWhitelistBase} for why it is not stored.
     * @param country The recorded country code.
     */
    event IdentityRegistered(address indexed userAddress, address indexed identity, uint16 country);
    /**
     * @notice Emitted when a wallet is removed from the registry.
     * @param userAddress The removed wallet.
     */
    event IdentityRemoved(address indexed userAddress);

    /* ============ Errors ============ */

    error IdentityRegistryWhitelist_AddressZeroNotAllowed();
    error IdentityRegistryWhitelist_AddressNotRegistered(address userAddress);
}
