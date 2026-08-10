// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IdentityRegistryWhitelistInvariantStorage} from "./IdentityRegistryWhitelistInvariantStorage.sol";
import {IERC734KeyHasPurpose, IIdentityRegistryERC3643} from "../interfaces/IIdentityRegistryERC3643.sol";

/**
 * @title IdentityRegistryWhitelistBase
 * @notice A whitelist that presents itself to an ERC-3643 token as an identity registry.
 * @dev This contract is plugged into a token with `token.setIdentityRegistry(address(this))`. It is
 * **not** a compliance rule: it does not implement `IRule` and must not be added to a `RuleEngine`.
 *
 * `registerIdentity` whitelists a wallet, `deleteIdentity` removes it, and `isVerified` answers the
 * whitelist question the token asks on every inbound transfer.
 *
 * ## Serving as the ONCHAINID for `recoveryAddress`
 * `Token.recoveryAddress(lostWallet, newWallet, investorOnchainID)` calls
 * `keyHasPurpose(keccak256(abi.encode(newWallet)), 1)` on the **caller-supplied**
 * `investorOnchainID`, not on anything the registry returns. Passing this contract's own address as
 * `investorOnchainID` therefore routes that check here, and {keyHasPurpose} answers it from the
 * whitelist -- no ONCHAINID deployment is needed anywhere.
 *
 * The key is a hash, so it cannot be inverted. A reverse index `wallet-key -> wallet` is written by
 * {registerIdentity} and cleared by {deleteIdentity}, which is what makes the lookup possible. The
 * consequence is documented in the technical doc: **the new wallet must already be registered
 * before `recoveryAddress` is called**.
 *
 * ## No identity state is kept
 * This contract stores **no identity data at all** -- no ONCHAINID, no country, no claims. Its only
 * state is the whitelist and the reverse index that indexes it. `registerIdentity`'s `_identity`
 * and `_country` arguments are accepted so the ERC-3643 signature matches, then discarded;
 * {investorCountry} always returns 0. Verification here means one thing: is this wallet on the
 * whitelist. Everything else in the interface is a wrapper over that single question.
 */
abstract contract IdentityRegistryWhitelistBase is
    IIdentityRegistryERC3643,
    IERC734KeyHasPurpose,
    IdentityRegistryWhitelistInvariantStorage
{
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * @dev Registered wallets. Enumerable so an operator can audit the whole set on-chain.
     */
    EnumerableSet.AddressSet private _registered;
    /**
     * @dev `keccak256(abi.encode(wallet)) -> wallet`, the reverse index that makes {keyHasPurpose}
     * possible. Kept exactly in step with {_registered}.
     */
    mapping(bytes32 walletKey => address wallet) private _walletOfKey;

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IIdentityRegistryERC3643
     * @dev Adds the wallet to the whitelist. `_identity` is echoed in {IdentityRegistered} for
     * off-chain traceability and `_country` is ignored entirely -- neither is stored.
     *
     * Reverts only on the zero address. Re-registering an already-registered wallet is a no-op, not
     * an error.
     *
     * IMPORTANT: this is a deliberate divergence from ERC-3643's reference registry, which reverts
     * with "address stored already". It is forced by answering {keyHasPurpose} from the whitelist:
     * `recoveryAddress` requires `keyHasPurpose(key(newWallet), 1)` to be true *before* it calls
     * `registerIdentity(newWallet, ...)`, so the new wallet must already be registered -- and a
     * duplicate-rejecting `registerIdentity` would then abort every recovery. See the technical doc.
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
        require(_userAddress != address(0), IdentityRegistryWhitelist_AddressZeroNotAllowed());
        // Return value intentionally ignored: false simply means the wallet was already registered,
        // and with no identity state to refresh, re-registration is a genuine no-op.
        _registered.add(_userAddress);
        _walletOfKey[_walletKey(_userAddress)] = _userAddress;
        emit IdentityRegistered(_userAddress, _identity);
    }

    /**
     * @inheritdoc IIdentityRegistryERC3643
     * @dev Reverts if the wallet is not registered.
     */
    function deleteIdentity(address _userAddress) external virtual override onlyIdentityRegistrar {
        require(_registered.remove(_userAddress), IdentityRegistryWhitelist_AddressNotRegistered(_userAddress));
        delete _walletOfKey[_walletKey(_userAddress)];
        emit IdentityRemoved(_userAddress);
    }

    /**
     * @notice Returns every registered wallet.
     * @dev Unbounded: intended for off-chain reads. Do not call from another contract.
     * @return The registered wallets.
     */
    function registeredIdentities() external view virtual returns (address[] memory) {
        return _registered.values();
    }

    /**
     * @notice Returns how many wallets are registered.
     * @return The number of registered wallets.
     */
    function registeredIdentityCount() external view virtual returns (uint256) {
        return _registered.length();
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
        return _registered.contains(_userAddress);
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

    /**
     * @inheritdoc IERC734KeyHasPurpose
     * @dev Answers from the whitelist: a key resolves to its wallet through the reverse index, and
     * the result is that wallet's {isVerified}. An unknown key maps to `address(0)`, which is never
     * registered, so unknown keys are rejected -- fail-closed.
     *
     * WARNING: this contract is not a real ERC-734 identity. It holds no keys and no claims, and
     * `_purpose` is **ignored**: any purpose returns the same whitelist answer. It exists solely so
     * the registry can be passed as `_investorOnchainID` to `recoveryAddress`. See the technical
     * doc before relying on it for anything else.
     */
    function keyHasPurpose(
        bytes32 _key,
        uint256 /* _purpose */
    )
        public
        view
        virtual
        override
        returns (bool)
    {
        return isVerified(_walletOfKey[_key]);
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

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Derives the ERC-734 key ERC-3643 uses for a wallet.
     * @dev Must match `Token.recoveryAddress` exactly: `keccak256(abi.encode(_newWallet))`.
     * @param wallet The wallet to derive the key for.
     * @return key The wallet key.
     */
    function _walletKey(address wallet) internal pure virtual returns (bytes32 key) {
        // Linter suggestion (`asm-keccak256`): hash in assembly to avoid the abi.encode allocation.
        // `mstore` of an address writes it left-padded into a 32-byte word, which IS `abi.encode`,
        // so this is byte-identical to `keccak256(abi.encode(wallet))`. Scratch space (0x00-0x3f)
        // is reserved by Solidity for exactly this. The equivalence is pinned by
        // `testKeyHasPurpose_UsesTheErc3643KeyDerivation`, which also asserts the encodePacked
        // form does NOT match -- getting this wrong would silently break every recovery.
        assembly ("memory-safe") {
            mstore(0x00, wallet)
            key := keccak256(0x00, 0x20)
        }
    }
}
