// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {
    IERC7943NonFungibleCompliance,
    IERC7943NonFungibleComplianceExtend
} from "../../../interfaces/IERC7943NonFungibleCompliance.sol";
import {RuleTransferValidation} from "./RuleTransferValidation.sol";
import {ITransferContext} from "../../../interfaces/ITransferContext.sol";

/**
 * @title Rule NFT Adapter
 * @notice Provides ERC-7943 overloads for rules that already implement core transfer checks.
 * @dev Delegates tokenId overloads to RuleTransferValidation's internal hooks.
 */
abstract contract RuleNFTAdapter is RuleTransferValidation, IERC7943NonFungibleComplianceExtend, ITransferContext {
    /**
     * @notice Selector of the ERC-3643 compliance `transferred` hook.
     */
    bytes4 internal constant TRANSFERRED_SELECTOR_ERC3643 = IERC3643IComplianceContract.transferred.selector;
    /**
     * @notice Selector of the RuleEngine `transferred` hook.
     */
    bytes4 internal constant TRANSFERRED_SELECTOR_RULE_ENGINE = IRuleEngine.transferred.selector;
    /**
     * @notice Selector of the ERC-7943 `transferred(from,to,tokenId,value)` hook.
     */
    bytes4 internal constant TRANSFERRED_SELECTOR_ERC7943 =
        bytes4(keccak256("transferred(address,address,uint256,uint256)"));
    /**
     * @notice Selector of the ERC-7943 `transferred(spender,from,to,tokenId,value)` hook.
     */
    bytes4 internal constant TRANSFERRED_SELECTOR_ERC7943_FROM =
        bytes4(keccak256("transferred(address,address,address,uint256,uint256)"));

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ITransferContext
     */
    function transferred(MultiTokenTransferContext calldata ctx) external virtual override {
        if (ctx.sender != address(0) && ctx.sender != ctx.from) {
            _transferredFrom(ctx.sender, ctx.from, ctx.to, ctx.value);
        } else {
            _transferred(ctx.from, ctx.to, ctx.value);
        }
    }

    /**
     * @inheritdoc ITransferContext
     */
    function transferred(FungibleTransferContext calldata ctx) external virtual override {
        if (ctx.sender != address(0) && ctx.sender != ctx.from) {
            _transferredFrom(ctx.sender, ctx.from, ctx.to, ctx.value);
        } else {
            _transferred(ctx.from, ctx.to, ctx.value);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IERC7943NonFungibleComplianceExtend
     */
    function transferred(
        address from,
        address to,
        uint256,
        /* tokenId */
        uint256 value
    )
        public
        virtual
        override(IERC7943NonFungibleComplianceExtend)
    {
        _transferred(from, to, value);
    }

    /**
     * @inheritdoc IERC7943NonFungibleComplianceExtend
     */
    function transferred(
        address spender,
        address from,
        address to,
        uint256,
        /* tokenId */
        uint256 value
    )
        public
        virtual
        override(IERC7943NonFungibleComplianceExtend)
    {
        _transferredFrom(spender, from, to, value);
    }

    /**
     * @inheritdoc IERC7943NonFungibleComplianceExtend
     */
    function detectTransferRestriction(
        address from,
        address to,
        uint256,
        /* tokenId */
        uint256 value
    )
        public
        view
        virtual
        override(IERC7943NonFungibleComplianceExtend)
        returns (uint8)
    {
        return _detectTransferRestriction(from, to, value);
    }

    /**
     * @inheritdoc IERC7943NonFungibleComplianceExtend
     */
    function detectTransferRestrictionFrom(
        address spender,
        address from,
        address to,
        uint256,
        /* tokenId */
        uint256 value
    )
        public
        view
        virtual
        override(IERC7943NonFungibleComplianceExtend)
        returns (uint8)
    {
        return _detectTransferRestrictionFrom(spender, from, to, value);
    }

    /**
     * @inheritdoc IERC7943NonFungibleCompliance
     */
    function canTransfer(
        address from,
        address to,
        uint256,
        /* tokenId */
        uint256 amount
    )
        public
        view
        virtual
        override(IERC7943NonFungibleCompliance)
        returns (bool)
    {
        return _detectTransferRestriction(from, to, amount) == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @inheritdoc IERC7943NonFungibleComplianceExtend
     */
    function canTransferFrom(
        address spender,
        address from,
        address to,
        uint256,
        /* tokenId */
        uint256 value
    )
        public
        view
        virtual
        override(IERC7943NonFungibleComplianceExtend)
        returns (bool)
    {
        return _detectTransferRestrictionFrom(spender, from, to, value)
            == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal hook for post-transfer validation or state updates.
     * @param from Address tokens are transferred from.
     * @param to Address tokens are transferred to.
     * @param value Amount transferred.
     */
    function _transferred(address from, address to, uint256 value) internal virtual;

    /**
     * @notice Internal hook for post-transfer validation or state updates (spender-aware).
     * @param spender Address executing the transfer on behalf of `from`.
     * @param from Address tokens are transferred from.
     * @param to Address tokens are transferred to.
     * @param value Amount transferred.
     */
    function _transferredFrom(address spender, address from, address to, uint256 value) internal virtual;
}
