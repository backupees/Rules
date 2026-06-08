// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleAddressSet} from "../RuleAddressSet/RuleAddressSet.sol";
import {RuleNFTAdapter} from "../core/RuleNFTAdapter.sol";
import {RuleSpenderWhitelistInvariantStorage} from "../invariant/RuleSpenderWhitelistInvariantStorage.sol";
import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";

/**
 * @title RuleSpenderWhitelistBase
 * @notice Restricts `transferFrom`-style flows to whitelisted spenders only.
 * @dev Direct transfers (`transferred(from,to,value)`) are intentionally no-op.
 */
abstract contract RuleSpenderWhitelistBase is RuleAddressSet, RuleNFTAdapter, RuleSpenderWhitelistInvariantStorage {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address forwarderIrrevocable) RuleAddressSet(forwarderIrrevocable) {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function canReturnTransferRestrictionCode(uint8 restrictionCode) external pure override returns (bool) {
        return restrictionCode == CODE_ADDRESS_SPENDER_NOT_WHITELISTED;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Regular transfers are always accepted by this rule.
     */
    function transferred(address, address, uint256) public view override(IERC3643IComplianceContract) {}

    function transferred(address spender, address from, address to, uint256 value) public view override(IRuleEngine) {
        _transferredFrom(spender, from, to, value);
    }

    function messageForTransferRestriction(uint8 restrictionCode)
        public
        pure
        override(IERC1404)
        returns (string memory)
    {
        if (restrictionCode == CODE_ADDRESS_SPENDER_NOT_WHITELISTED) {
            return TEXT_ADDRESS_SPENDER_NOT_WHITELISTED;
        }
        return TEXT_CODE_NOT_FOUND;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _detectTransferRestriction(address, address, uint256) internal pure virtual override returns (uint8) {
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    function _detectTransferRestrictionFrom(address spender, address from, address to, uint256)
        internal
        view
        virtual
        override
        returns (uint8)
    {
        // Mint (from == address(0)) and burn (to == address(0)) are exempt from the spender check:
        // the minter/burner acts on its own authority, not as a delegated ERC-20 spender.
        if (from != address(0) && to != address(0) && !_isAddressListed(spender)) {
            return CODE_ADDRESS_SPENDER_NOT_WHITELISTED;
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    function _transferred(address, address, uint256) internal view virtual override {
        // no-op: regular transfers are intentionally ignored by this rule
    }

    function _transferredFrom(address spender, address from, address to, uint256 value) internal view virtual override {
        uint8 code = _detectTransferRestrictionFrom(spender, from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleSpenderWhitelist_InvalidTransferFrom(address(this), spender, from, to, value, code)
        );
    }
}
