// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleAddressSetInternal} from "../../rules/validation/abstract/RuleAddressSet/RuleAddressSetInternal.sol";
import {IdentityRegistryWhitelistInvariantStorage} from "./IdentityRegistryWhitelistInvariantStorage.sol";
import {VersionModule} from "../../modules/VersionModule.sol";
import {IIdentityRegistryERC3643} from "../interfaces/IIdentityRegistryERC3643.sol";

/**
 * @title IdentityRegistryWhitelistBase
 * @notice A whitelist that presents itself to an ERC-3643 token as an identity registry.
 * @dev This contract is plugged into a token with `token.setIdentityRegistry(address(this))`. It is
 * **not** a compliance rule: it does not implement `IRule` and must not be added to a `RuleEngine`.
 *
 * `registerIdentity` whitelists a wallet, `deleteIdentity` removes it, and `isVerified` answers the
 * whitelist question the token asks on every inbound transfer.
 *
 * ## It is only a whitelist
 * There is no ERC-734 surface here. An earlier revision implemented `keyHasPurpose` so the registry
 * could be passed as `_investorOnchainID` to `recoveryAddress`; it was removed because it bought
 * nothing. `Token.recoveryAddress` calls `keyHasPurpose` on the address the **agent supplies**,
 * without cross-checking it against the registry, so an agent who wants to skip that gate simply
 * passes a different contract. It was convenience for an honest agent, not a control -- and it cost
 * a reverse index plus two behavioural divergences from the reference registry. Supply a real
 * ONCHAINID (or any ERC-734 contract) as `_investorOnchainID` instead.
 *
 * ## Where the whitelist comes from
 * The address set is not re-implemented here: this contract inherits {RuleAddressSetInternal}, the
 * same `EnumerableSet` machinery `RuleWhitelist` and `RuleBlacklist` are built on, so the storage
 * layout and the zero-address guard are shared code rather than a second implementation. No
 * separate whitelist contract is deployed -- the registry *is* the list.
 *
 * Only the `internal` layer is inherited, so the registry exposes exactly one write API -- the
 * ERC-3643 one -- rather than two overlapping ones. The public `RuleAddressSet` surface would add
 * `addAddress` / `removeAddress` alongside {registerIdentity} / {deleteIdentity}, with two sets of
 * roles and events describing the same state change.
 *
 * ## No identity state is kept
 * This contract stores **no identity data at all** -- no ONCHAINID, no country, no claims. Its only
 * state is the inherited address set. `registerIdentity`'s `_identity` and `_country` arguments are
 * accepted so the ERC-3643 signature matches, then discarded; {investorCountry} always returns 0.
 * Verification here means one thing: is this wallet on the whitelist. Everything else in the
 * interface is a wrapper over that single question.
 *
 * Returning a constant country is safe for the token itself. `Token.sol` reads `investorCountry` in
 * exactly one place -- `recoveryAddress`, line 308 -- and only to pass it straight back into
 * `registerIdentity`, which discards it here. It never branches on the value and exposes no getter.
 * The exposure is a *custom* compliance module that calls `investorCountry`: it would see every
 * investor as country 0. No shipped ERC-3643 compliance does (the one consumer,
 * `compliance/legacy/BasicCompliance._getCountry`, has no caller in the reference tree, and the
 * modular framework has no country module). See the technical doc for the full audit.
 */
abstract contract IdentityRegistryWhitelistBase is
    RuleAddressSetInternal,
    VersionModule,
    IIdentityRegistryERC3643,
    IdentityRegistryWhitelistInvariantStorage
{
    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IIdentityRegistryERC3643
     * @dev Adds the wallet to the whitelist. `_identity` is echoed in {IdentityRegistered} for
     * off-chain traceability and `_country` is ignored entirely -- neither is stored.
     *
     * Reverts on the zero address and on an already-registered wallet, matching ERC-3643's
     * reference registry (which reverts with "address stored already").
     */
    function registerIdentity(
        address _userAddress,
        address _identity,
        uint16 /* _country */
    )
        external
        virtual
        override
        onlyIdentityRegistrar
    {
        // Same guards, same errors as the whitelist rules: the zero address is the mint/burn
        // sentinel and must never be listed, or `isVerified(address(0))` would return true.
        require(_userAddress != address(0), RuleAddressSet_ZeroAddressNotAllowed());
        require(_addAddress(_userAddress), RuleAddressSet_AddressAlreadyListed());
        emit IdentityRegistered(_userAddress, _identity);
    }

    /**
     * @inheritdoc IIdentityRegistryERC3643
     * @dev Reverts if the wallet is not registered.
     */
    function deleteIdentity(address _userAddress) external virtual override onlyIdentityRegistrar {
        require(_removeAddress(_userAddress), RuleAddressSet_AddressNotFound());
        emit IdentityRemoved(_userAddress);
    }

    /**
     * @notice Returns how many wallets are registered.
     * @dev There is deliberately no full enumeration getter, matching `RuleWhitelist` and
     * `RuleBlacklist`, which expose a count but not the member list.
     * @return The number of registered wallets.
     */
    function registeredIdentityCount() external view virtual returns (uint256) {
        return _listedAddressCount();
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IIdentityRegistryERC3643
     * @dev `address(0)` is never registered, so it is never verified -- ERC-3643 defines
     * `isVerified` as "is this wallet a valid investor", and the zero address is not a wallet.
     * Mint and burn permission is the token's business, not the registry's.
     */
    function isVerified(address _userAddress) public view virtual override returns (bool) {
        return _isAddressListed(_userAddress);
    }

    /**
     * @inheritdoc IIdentityRegistryERC3643
     * @dev Always returns 0: this registry keeps no identity data, only a whitelist. The function
     * exists because `recoveryAddress` calls it -- omitting it would make every recovery revert --
     * and the 0 it returns is handed straight back to {registerIdentity}, which ignores it.
     */
    function investorCountry(
        address /* _userAddress */
    )
        public
        view
        virtual
        override
        returns (uint16)
    {
        return 0;
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyIdentityRegistrar() {
        _authorizeIdentityRegistrar();
        _;
    }

    /**
     * @notice Authorizes the caller to register and delete identities; reverts otherwise.
     * @dev Implemented by concrete subclasses with the desired access-control policy.
     */
    function _authorizeIdentityRegistrar() internal view virtual;
}
