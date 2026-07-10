// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {MetaTxModuleStandalone, ERC2771Context} from "../../../../modules/MetaTxModuleStandalone.sol";
import {RuleERC2980Internal} from "../RuleERC2980/RuleERC2980Internal.sol";
import {RuleERC2980InvariantStorage} from "../RuleERC2980/invariantStorage/RuleERC2980InvariantStorage.sol";
import {RuleNFTAdapter} from "../core/RuleNFTAdapter.sol";
import {RuleTransferValidation} from "../core/RuleTransferValidation.sol";
/* ==== Interfaces === */
import {IERC2980} from "../../../interfaces/IERC2980.sol";
import {IIdentityRegistryVerified} from "../../../interfaces/IIdentityRegistry.sol";
import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";

/**
 * @title RuleERC2980Base
 * @notice Core ERC-2980 Swiss Compliant transfer restriction logic combining a whitelist and a frozenlist.
 * @dev
 * Transfer logic (frozenlist takes priority over whitelist):
 * 1. If `from`, `to`, or `spender` is frozen → transfer is blocked.
 * 2. If `to` is not whitelisted → transfer is blocked.
 * Note: `from` does NOT need to be whitelisted to send tokens it already holds.
 *
 * Provides public management functions for both lists with abstract authorization hooks
 * so concrete subclasses can plug in their preferred access-control mechanism.
 */
abstract contract RuleERC2980Base is
    MetaTxModuleStandalone,
    RuleERC2980Internal,
    RuleERC2980InvariantStorage,
    RuleNFTAdapter,
    IERC2980,
    IIdentityRegistryVerified
{
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the rule, optionally whitelisting the zero address to allow burns.
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address, set permanently at deployment.
     * @param allowBurn When true, whitelists `address(0)` so tokens can be burned (sent to the zero address).
     */
    constructor(address forwarderIrrevocable, bool allowBurn) MetaTxModuleStandalone(forwarderIrrevocable) {
        if (allowBurn) {
            _addWhitelistAddress(address(0));
            emit AddWhitelistAddress(address(0));
        }
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyWhitelistAdd() {
        _authorizeWhitelistAdd();
        _;
    }

    modifier onlyWhitelistRemove() {
        _authorizeWhitelistRemove();
        _;
    }

    modifier onlyFrozenlistAdd() {
        _authorizeFrozenlistAdd();
        _;
    }

    modifier onlyFrozenlistRemove() {
        _authorizeFrozenlistRemove();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                       WHITELIST MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds multiple addresses to the whitelist.
     * @dev Does not revert if an address is already listed.
     * @param targetAddresses Addresses to add to the whitelist.
     */
    function addWhitelistAddresses(address[] calldata targetAddresses) public onlyWhitelistAdd {
        _addWhitelistAddresses(targetAddresses);
        emit AddWhitelistAddresses(targetAddresses);
    }

    /**
     * @notice Removes multiple addresses from the whitelist.
     * @dev Does not revert if an address is not listed.
     * @param targetAddresses Addresses to remove from the whitelist.
     */
    function removeWhitelistAddresses(address[] calldata targetAddresses) public onlyWhitelistRemove {
        _removeWhitelistAddresses(targetAddresses);
        emit RemoveWhitelistAddresses(targetAddresses);
    }

    /**
     * @notice Adds a single address to the whitelist.
     * @dev
     * Reverts if the address is already listed.
     * Deviation from ERC-2980 `Whitelistable` example interface: the spec's `addAddressToWhitelist`
     * returns `false` on duplicates instead of reverting. This implementation follows the codebase
     * convention of reverting on invalid single-item operations.
     * @param targetAddress Address to add to the whitelist.
     */
    function addWhitelistAddress(address targetAddress) public onlyWhitelistAdd {
        require(!_isWhitelisted(targetAddress), RuleERC2980_AddressAlreadyWhitelisted());
        _addWhitelistAddress(targetAddress);
        emit AddWhitelistAddress(targetAddress);
    }

    /**
     * @notice Removes a single address from the whitelist.
     * @dev
     * Reverts if the address is not listed.
     * Deviation from ERC-2980 `Whitelistable` example interface: the spec's `removeAddressFromWhitelist`
     * returns `false` when not found instead of reverting. This implementation follows the codebase
     * convention of reverting on invalid single-item operations.
     * @param targetAddress Address to remove from the whitelist.
     */
    function removeWhitelistAddress(address targetAddress) public onlyWhitelistRemove {
        require(_isWhitelisted(targetAddress), RuleERC2980_AddressNotWhitelisted());
        _removeWhitelistAddress(targetAddress);
        emit RemoveWhitelistAddress(targetAddress);
    }

    /*//////////////////////////////////////////////////////////////
                      FROZENLIST MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds multiple addresses to the frozenlist.
     * @dev Does not revert if an address is already listed.
     * @param targetAddresses Addresses to add to the frozenlist.
     */
    function addFrozenlistAddresses(address[] calldata targetAddresses) public onlyFrozenlistAdd {
        _addFrozenlistAddresses(targetAddresses);
        emit AddFrozenlistAddresses(targetAddresses);
    }

    /**
     * @notice Removes multiple addresses from the frozenlist.
     * @dev Does not revert if an address is not listed.
     * @param targetAddresses Addresses to remove from the frozenlist.
     */
    function removeFrozenlistAddresses(address[] calldata targetAddresses) public onlyFrozenlistRemove {
        _removeFrozenlistAddresses(targetAddresses);
        emit RemoveFrozenlistAddresses(targetAddresses);
    }

    /**
     * @notice Adds a single address to the frozenlist.
     * @dev
     * Reverts if the address is already listed.
     * Deviation from ERC-2980 `Freezable` example interface: the spec's `addAddressToFrozenlist`
     * returns `false` on duplicates instead of reverting. This implementation follows the codebase
     * convention of reverting on invalid single-item operations.
     * @param targetAddress Address to add to the frozenlist.
     */
    function addFrozenlistAddress(address targetAddress) public onlyFrozenlistAdd {
        require(!_isFrozen(targetAddress), RuleERC2980_AddressAlreadyFrozen());
        _addFrozenlistAddress(targetAddress);
        emit AddFrozenlistAddress(targetAddress);
    }

    /**
     * @notice Removes a single address from the frozenlist.
     * @dev
     * Reverts if the address is not listed.
     * Deviation from ERC-2980 `Freezable` example interface: the spec's `removeAddressFromFrozenlist`
     * returns `false` when not found instead of reverting. This implementation follows the codebase
     * convention of reverting on invalid single-item operations.
     * @param targetAddress Address to remove from the frozenlist.
     */
    function removeFrozenlistAddress(address targetAddress) public onlyFrozenlistRemove {
        require(_isFrozen(targetAddress), RuleERC2980_AddressNotFrozen());
        _removeFrozenlistAddress(targetAddress);
        emit RemoveFrozenlistAddress(targetAddress);
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IERC3643IComplianceContract
     */
    function transferred(address from, address to, uint256 value)
        public
        view
        virtual
        override(IERC3643IComplianceContract)
    {
        _transferred(from, to, value);
    }

    /**
     * @inheritdoc IRuleEngine
     */
    function transferred(address spender, address from, address to, uint256 value)
        public
        view
        virtual
        override(IRuleEngine)
    {
        _transferredFrom(spender, from, to, value);
    }

    /**
     * @inheritdoc IRule
     */
    function canReturnTransferRestrictionCode(uint8 restrictionCode)
        public
        pure
        virtual
        override(IRule)
        returns (bool)
    {
        return restrictionCode == CODE_ADDRESS_FROM_IS_FROZEN || restrictionCode == CODE_ADDRESS_TO_IS_FROZEN
            || restrictionCode == CODE_ADDRESS_SPENDER_IS_FROZEN || restrictionCode == CODE_ADDRESS_TO_NOT_WHITELISTED;
    }

    /**
     * @inheritdoc IERC1404
     */
    function messageForTransferRestriction(uint8 restrictionCode)
        public
        pure
        virtual
        override(IERC1404)
        returns (string memory)
    {
        if (restrictionCode == CODE_ADDRESS_FROM_IS_FROZEN) {
            return TEXT_ADDRESS_FROM_IS_FROZEN;
        } else if (restrictionCode == CODE_ADDRESS_TO_IS_FROZEN) {
            return TEXT_ADDRESS_TO_IS_FROZEN;
        } else if (restrictionCode == CODE_ADDRESS_SPENDER_IS_FROZEN) {
            return TEXT_ADDRESS_SPENDER_IS_FROZEN;
        } else if (restrictionCode == CODE_ADDRESS_TO_NOT_WHITELISTED) {
            return TEXT_ADDRESS_TO_NOT_WHITELISTED;
        } else {
            return TEXT_CODE_NOT_FOUND;
        }
    }

    /**
     * @inheritdoc RuleTransferValidation
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(RuleTransferValidation) returns (bool) {
        return RuleTransferValidation.supportsInterface(interfaceId);
    }

    /**
     * @notice Returns the number of whitelisted addresses.
     * @return The count of addresses currently in the whitelist.
     */
    function whitelistAddressCount() public view returns (uint256) {
        return _whitelistCount();
    }

    /**
     * @notice Returns true if the address is in the whitelist.
     * @param targetAddress Address to check.
     * @return True if the address is whitelisted.
     */
    function isWhitelisted(address targetAddress) public view returns (bool) {
        return _isWhitelisted(targetAddress);
    }

    /**
     * @notice ERC-2980 getter: returns true if the address is whitelisted.
     * @param _operator Address to check.
     * @return True if the address is whitelisted.
     */
    function whitelist(address _operator) public view virtual override(IERC2980) returns (bool) {
        return _isWhitelisted(_operator);
    }

    /**
     * @notice Returns true if the address is whitelisted (identity-verified).
     * @dev Reflects whitelist membership only. Frozen status is intentionally excluded:
     * freezing is a temporary enforcement action and does not revoke identity verification.
     * @param targetAddress Address to check.
     * @return True if the address is whitelisted.
     */
    function isVerified(address targetAddress) public view virtual override(IIdentityRegistryVerified) returns (bool) {
        return _isWhitelisted(targetAddress);
    }

    /**
     * @notice Checks multiple addresses for whitelist membership.
     * @param targetAddresses Addresses to check.
     * @return results Array of booleans, true where the corresponding address is whitelisted.
     */
    function areWhitelisted(address[] memory targetAddresses) public view returns (bool[] memory results) {
        results = new bool[](targetAddresses.length);
        for (uint256 i = 0; i < targetAddresses.length; ++i) {
            results[i] = _isWhitelisted(targetAddresses[i]);
        }
    }

    /**
     * @notice Returns the number of frozen addresses.
     * @return The count of addresses currently in the frozenlist.
     */
    function frozenlistAddressCount() public view returns (uint256) {
        return _frozenlistCount();
    }

    /**
     * @notice Returns true if the address is in the frozenlist.
     * @param targetAddress Address to check.
     * @return True if the address is frozen.
     */
    function isFrozen(address targetAddress) public view returns (bool) {
        return _isFrozen(targetAddress);
    }

    /**
     * @notice ERC-2980 getter: returns true if the address is frozen.
     * @param _operator Address to check.
     * @return True if the address is frozen.
     */
    function frozenlist(address _operator) public view virtual override(IERC2980) returns (bool) {
        return _isFrozen(_operator);
    }

    /**
     * @notice Checks multiple addresses for frozenlist membership.
     * @param targetAddresses Addresses to check.
     * @return results Array of booleans, true where the corresponding address is frozen.
     */
    function areFrozen(address[] memory targetAddresses) public view returns (bool[] memory results) {
        results = new bool[](targetAddresses.length);
        for (uint256 i = 0; i < targetAddresses.length; ++i) {
            results[i] = _isFrozen(targetAddresses[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Authorization hook invoked before adding addresses to the whitelist.
     */
    function _authorizeWhitelistAdd() internal view virtual;
    /**
     * @notice Authorization hook invoked before removing addresses from the whitelist.
     */
    function _authorizeWhitelistRemove() internal view virtual;
    /**
     * @notice Authorization hook invoked before adding addresses to the frozenlist.
     */
    function _authorizeFrozenlistAdd() internal view virtual;
    /**
     * @notice Authorization hook invoked before removing addresses from the frozenlist.
     */
    function _authorizeFrozenlistRemove() internal view virtual;

    /**
     * @inheritdoc RuleTransferValidation
     */
    function _detectTransferRestriction(
        address from,
        address to,
        uint256 /* value */
    )
        internal
        view
        virtual
        override
        returns (uint8)
    {
        // Frozenlist check has priority
        if (_isFrozen(from)) {
            return CODE_ADDRESS_FROM_IS_FROZEN;
        } else if (_isFrozen(to)) {
            return CODE_ADDRESS_TO_IS_FROZEN;
        }
        // Whitelist check: only the recipient must be whitelisted
        if (!_isWhitelisted(to)) {
            return CODE_ADDRESS_TO_NOT_WHITELISTED;
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @inheritdoc RuleTransferValidation
     */
    function _detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        internal
        view
        virtual
        override
        returns (uint8)
    {
        if (_isFrozen(spender)) {
            return CODE_ADDRESS_SPENDER_IS_FROZEN;
        }
        return _detectTransferRestriction(from, to, value);
    }

    /**
     * @inheritdoc RuleNFTAdapter
     */
    function _transferred(address from, address to, uint256 value) internal view virtual override {
        uint8 code = _detectTransferRestriction(from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleERC2980_InvalidTransfer(address(this), from, to, value, code)
        );
    }

    /**
     * @inheritdoc RuleNFTAdapter
     */
    function _transferredFrom(address spender, address from, address to, uint256 value) internal view virtual override {
        uint8 code = _detectTransferRestrictionFrom(spender, from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleERC2980_InvalidTransferFrom(address(this), spender, from, to, value, code)
        );
    }

    /**
     * @inheritdoc ERC2771Context
     */
    function _msgSender() internal view virtual override(ERC2771Context) returns (address sender) {
        return ERC2771Context._msgSender();
    }

    /**
     * @inheritdoc ERC2771Context
     */
    function _msgData() internal view virtual override(ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /**
     * @inheritdoc ERC2771Context
     */
    function _contextSuffixLength() internal view virtual override(ERC2771Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
}
