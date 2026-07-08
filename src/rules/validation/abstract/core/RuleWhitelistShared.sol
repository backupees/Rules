// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

/* ==== CMTAT === */
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
/* ==== Abstract contracts === */
import {RuleWhitelistInvariantStorage} from "../RuleAddressSet/invariantStorage/RuleWhitelistInvariantStorage.sol";
import {RuleNFTAdapter} from "./RuleNFTAdapter.sol";

/**
 * @title Rule Whitelist Shared
 * @notice Provides common logic for validating whitelist-based transfer restrictions.
 * @dev
 * - Implements ERC-3643–compatible `transferred` hooks to enforce whitelist checks.
 * - Defines utility functions for restriction code validation and message mapping.
 * - Inherits restriction code constants and messages from {RuleWhitelistInvariantStorage}.
 */
abstract contract RuleWhitelistShared is RuleNFTAdapter, RuleWhitelistInvariantStorage {
    /**
     * Indicate if the spender is verified or not
     */
    bool public checkSpender;

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks whether a restriction code is recognized by this rule.
     * @dev
     * Used to verify if a returned restriction code belongs to the whitelist rule.
     * @param restrictionCode The restriction code to validate.
     * @return isKnown True if the restriction code is recognized by this rule, false otherwise.
     */
    function canReturnTransferRestrictionCode(uint8 restrictionCode) external pure override returns (bool isKnown) {
        return restrictionCode == CODE_ADDRESS_FROM_NOT_WHITELISTED
            || restrictionCode == CODE_ADDRESS_TO_NOT_WHITELISTED
            || restrictionCode == CODE_ADDRESS_SPENDER_NOT_WHITELISTED;
    }

    /**
     * @notice Returns the human-readable message corresponding to a restriction code.
     * @dev
     * Returns a descriptive text that explains why a transfer was restricted.
     * @param restrictionCode The restriction code to decode.
     * @return message A human-readable explanation of the restriction.
     */
    function messageForTransferRestriction(uint8 restrictionCode)
        external
        pure
        override
        returns (string memory message)
    {
        if (restrictionCode == CODE_ADDRESS_FROM_NOT_WHITELISTED) {
            return TEXT_ADDRESS_FROM_NOT_WHITELISTED;
        } else if (restrictionCode == CODE_ADDRESS_TO_NOT_WHITELISTED) {
            return TEXT_ADDRESS_TO_NOT_WHITELISTED;
        } else if (restrictionCode == CODE_ADDRESS_SPENDER_NOT_WHITELISTED) {
            return TEXT_ADDRESS_SPENDER_NOT_WHITELISTED;
        } else {
            return TEXT_CODE_NOT_FOUND;
        }
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice ERC-3643 hook called when a transfer occurs.
     * @dev
     * - Validates that both `from` and `to` addresses are whitelisted.
     * - Reverts if any restriction code other than `TRANSFER_OK` is returned.
     * - Validation only; does not modify state.
     * - Should be called during token transfer logic to enforce whitelist compliance.
     * @param from The address sending tokens.
     * @param to The address receiving tokens.
     * @param value The token amount being transferred.
     */
    function transferred(address from, address to, uint256 value) public view override(IERC3643IComplianceContract) {
        _transferred(from, to, value);
    }

    /**
     * @notice hook called when a delegated transfer occurs (`transferFrom`).
     * @dev
     * - Validates that `spender`, `from`, and `to` are all whitelisted.
     * - Reverts if any restriction code other than `TRANSFER_OK` is returned.
     * - Validation only; does not modify state.
     * @param spender The address performing the transfer on behalf of another.
     * @param from The address from which tokens are transferred.
     * @param to The recipient address.
     * @param value The token amount being transferred.
     */
    function transferred(address spender, address from, address to, uint256 value) public view override(IRuleEngine) {
        _transferredFrom(spender, from, to, value);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc RuleNFTAdapter
     */
    function _transferred(address from, address to, uint256 value) internal view virtual override {
        uint8 code = _detectTransferRestriction(from, to, value);
        require(
            code == uint8(REJECTED_CODE_BASE.TRANSFER_OK),
            RuleWhitelist_InvalidTransfer(address(this), from, to, value, code)
        );
    }

    /**
     * @inheritdoc RuleNFTAdapter
     */
    function _transferredFrom(address spender, address from, address to, uint256 value) internal view virtual override {
        uint8 code = _detectTransferRestrictionFrom(spender, from, to, value);
        require(
            code == uint8(REJECTED_CODE_BASE.TRANSFER_OK),
            RuleWhitelist_InvalidTransferFrom(address(this), spender, from, to, value, code)
        );
    }
}
