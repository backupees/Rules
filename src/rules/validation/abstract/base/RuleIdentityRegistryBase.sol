// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleNFTAdapter} from "../core/RuleNFTAdapter.sol";
import {RuleIdentityRegistryInvariantStorage} from "../invariant/RuleIdentityRegistryInvariantStorage.sol";
import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {IIdentityRegistryVerified} from "../../../interfaces/IIdentityRegistry.sol";

/**
 * @title RuleIdentityRegistryBase
 * @notice Checks the ERC-3643 Identity Registry for transfer participants when configured.
 * @dev Burns (to == address(0)) are allowed even if the sender is not verified.
 */
abstract contract RuleIdentityRegistryBase is RuleNFTAdapter, RuleIdentityRegistryInvariantStorage {
    /**
     * @notice The ERC-3643 Identity Registry consulted to verify transfer participants; the zero address disables checks.
     */
    IIdentityRegistryVerified public identityRegistry;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the rule with an optional identity registry.
     * @param identityRegistry_ Identity registry address; when the zero address, the registry is left unset (checks disabled).
     */
    constructor(address identityRegistry_) {
        if (identityRegistry_ != address(0)) {
            identityRegistry = IIdentityRegistryVerified(identityRegistry_);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyIdentityRegistryManager() {
        _authorizeIdentityRegistryManager();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether this rule can produce the given restriction code.
     * @param restrictionCode Restriction code to test.
     * @return True if `restrictionCode` is one of this rule's identity-verification codes.
     */
    function canReturnTransferRestrictionCode(uint8 restrictionCode) external pure override returns (bool) {
        return restrictionCode == CODE_ADDRESS_FROM_NOT_VERIFIED || restrictionCode == CODE_ADDRESS_TO_NOT_VERIFIED
            || restrictionCode == CODE_ADDRESS_SPENDER_NOT_VERIFIED;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the identity registry consulted during transfer checks.
     * @param newRegistry New identity registry address; must not be the zero address.
     */
    function setIdentityRegistry(address newRegistry) public onlyIdentityRegistryManager {
        require(newRegistry != address(0), RuleIdentityRegistry_RegistryAddressZeroNotAllowed());
        identityRegistry = IIdentityRegistryVerified(newRegistry);
        emit IdentityRegistryUpdated(newRegistry);
    }

    /**
     * @notice Clears the identity registry, disabling identity checks (all transfers pass this rule).
     */
    function clearIdentityRegistry() public onlyIdentityRegistryManager {
        identityRegistry = IIdentityRegistryVerified(address(0));
        emit IdentityRegistryUpdated(address(0));
    }

    /**
     * @inheritdoc IERC3643IComplianceContract
     */
    function transferred(address from, address to, uint256 value) public view override(IERC3643IComplianceContract) {
        _transferred(from, to, value);
    }

    /**
     * @inheritdoc IRuleEngine
     */
    function transferred(address spender, address from, address to, uint256 value) public view override(IRuleEngine) {
        _transferredFrom(spender, from, to, value);
    }

    /**
     * @inheritdoc IERC1404
     */
    function messageForTransferRestriction(uint8 restrictionCode)
        public
        pure
        override(IERC1404)
        returns (string memory)
    {
        if (restrictionCode == CODE_ADDRESS_FROM_NOT_VERIFIED) {
            return TEXT_ADDRESS_FROM_NOT_VERIFIED;
        } else if (restrictionCode == CODE_ADDRESS_TO_NOT_VERIFIED) {
            return TEXT_ADDRESS_TO_NOT_VERIFIED;
        } else if (restrictionCode == CODE_ADDRESS_SPENDER_NOT_VERIFIED) {
            return TEXT_ADDRESS_SPENDER_NOT_VERIFIED;
        }
        return TEXT_CODE_NOT_FOUND;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Authorization hook invoked before updating or clearing the identity registry.
     */
    function _authorizeIdentityRegistryManager() internal view virtual;

    /**
     * @notice Detects the restriction code for a direct transfer, verifying `from` and `to` against the registry.
     * @param from Sender address; must be verified unless it is the zero address (mint).
     * @param to Recipient address; must be verified unless it is the zero address (burn).
     * @return The applicable restriction code, or TRANSFER_OK when no restriction applies.
     */
    function _detectTransferRestriction(
        address from,
        address to,
        uint256 /* value */
    )
        internal
        view
        override
        returns (uint8)
    {
        if (address(identityRegistry) == address(0)) {
            return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
        }
        if (to == address(0)) {
            return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
        }

        if (from != address(0) && !identityRegistry.isVerified(from)) {
            return CODE_ADDRESS_FROM_NOT_VERIFIED;
        }
        if (to != address(0) && !identityRegistry.isVerified(to)) {
            return CODE_ADDRESS_TO_NOT_VERIFIED;
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @notice Detects the restriction code for a `transferFrom`, verifying `spender` and delegating to the direct check.
     * @param spender Approved spender initiating the transfer; must be verified unless it is the zero address.
     * @param from Sender address, forwarded to the direct transfer check.
     * @param to Recipient address, forwarded to the direct transfer check.
     * @param value Transfer amount, forwarded to the direct transfer check.
     * @return The applicable restriction code, or TRANSFER_OK when no restriction applies.
     */
    function _detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        internal
        view
        override
        returns (uint8)
    {
        if (address(identityRegistry) == address(0)) {
            return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
        }
        if (to == address(0)) {
            return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
        }
        if (spender != address(0) && !identityRegistry.isVerified(spender)) {
            return CODE_ADDRESS_SPENDER_NOT_VERIFIED;
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
            RuleIdentityRegistry_InvalidTransfer(address(this), from, to, value, code)
        );
    }

    /**
     * @inheritdoc RuleNFTAdapter
     */
    function _transferredFrom(address spender, address from, address to, uint256 value) internal view virtual override {
        uint8 code = _detectTransferRestrictionFrom(spender, from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleIdentityRegistry_InvalidTransferFrom(address(this), spender, from, to, value, code)
        );
    }
}
