// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643ComplianceRead, IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IERC7551Compliance} from "CMTAT/interfaces/tokenization/draft-IERC7551.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";
import {ERC3643ComplianceModule} from "RuleEngine/modules/ERC3643ComplianceModule.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VersionModule} from "../../../modules/VersionModule.sol";
import {RuleConditionalTransferLightMultiTokenInvariantStorage} from "./RuleConditionalTransferLightMultiTokenInvariantStorage.sol";
import {ITransferContext} from "../../interfaces/ITransferContext.sol";

abstract contract RuleConditionalTransferLightMultiTokenBase is
    VersionModule,
    ERC3643ComplianceModule,
    RuleConditionalTransferLightMultiTokenInvariantStorage,
    IRule
{
    using SafeERC20 for IERC20;

    mapping(bytes32 => uint256) public approvalCounts;

    modifier onlyTransferApprover() {
        _authorizeTransferApproval();
        _;
    }

    modifier onlyTransferExecutor() {
        _authorizeTransferExecution();
        _;
    }

    function _authorizeTransferApproval() internal view virtual;

    function canReturnTransferRestrictionCode(uint8 restrictionCode) external pure override(IRule) returns (bool) {
        return restrictionCode == CODE_TRANSFER_REQUEST_NOT_APPROVED;
    }

    function messageForTransferRestriction(uint8 restrictionCode)
        external
        pure
        override(IERC1404)
        returns (string memory)
    {
        if (restrictionCode == CODE_TRANSFER_REQUEST_NOT_APPROVED) {
            return TEXT_TRANSFER_REQUEST_NOT_APPROVED;
        }
        return TEXT_CODE_NOT_FOUND;
    }

    function created(address to, uint256 value) external onlyBoundToken {
        _transferred(_msgSender(), address(0), to, value);
    }

    function destroyed(address from, uint256 value) external onlyBoundToken {
        _transferred(_msgSender(), from, address(0), value);
    }

    function approveTransfer(address token, address from, address to, uint256 value) public onlyTransferApprover {
        _approveTransfer(token, from, to, value);
    }

    function cancelTransferApproval(address token, address from, address to, uint256 value) public onlyTransferApprover {
        _cancelTransferApproval(token, from, to, value);
    }

    function approvedCount(address token, address from, address to, uint256 value) public view returns (uint256) {
        bytes32 transferHash = _transferHash(token, from, to, value);
        return approvalCounts[transferHash];
    }

    function approveAndTransferIfAllowed(address token, address from, address to, uint256 value)
        public
        onlyTransferApprover
        returns (bool)
    {
        require(isTokenBound(token), RuleConditionalTransferLightMultiToken_InvalidToken());

        _approveTransfer(token, from, to, value);

        uint256 allowed = IERC20(token).allowance(from, address(this));
        require(
            allowed >= value,
            RuleConditionalTransferLightMultiToken_InsufficientAllowance(token, from, allowed, value)
        );

        IERC20(token).safeTransferFrom(from, to, value);
        return true;
    }

    function transferred(address from, address to, uint256 value)
        public
        override(IERC3643IComplianceContract)
        onlyTransferExecutor
    {
        _transferred(_msgSender(), from, to, value);
    }

    function transferred(
        address,
        /* spender */
        address from,
        address to,
        uint256 value
    )
        public
        override(IRuleEngine)
        onlyTransferExecutor
    {
        _transferred(_msgSender(), from, to, value);
    }

    function transferred(ITransferContext.FungibleTransferContext calldata ctx) external onlyTransferExecutor {
        _transferred(_msgSender(), ctx.from, ctx.to, ctx.value);
    }

    function detectTransferRestriction(address from, address to, uint256 value)
        public
        view
        override(IERC1404)
        returns (uint8)
    {
        if (from == address(0) || to == address(0)) {
            return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
        }

        address token = _msgSender();
        if (!isTokenBound(token)) {
            return CODE_TRANSFER_REQUEST_NOT_APPROVED;
        }

        bytes32 transferHash = _transferHash(token, from, to, value);
        if (approvalCounts[transferHash] == 0) {
            return CODE_TRANSFER_REQUEST_NOT_APPROVED;
        }

        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    function detectTransferRestrictionFrom(
        address,
        /* spender */
        address from,
        address to,
        uint256 value
    )
        public
        view
        override(IERC1404Extend)
        returns (uint8)
    {
        return detectTransferRestriction(from, to, value);
    }

    function canTransfer(address from, address to, uint256 value)
        public
        view
        override(IERC3643ComplianceRead)
        returns (bool)
    {
        return detectTransferRestriction(from, to, value) == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    function canTransferFrom(address spender, address from, address to, uint256 value)
        public
        view
        override(IERC7551Compliance)
        returns (bool)
    {
        return detectTransferRestrictionFrom(spender, from, to, value)
            == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    function _authorizeTransferExecution() internal view virtual {
        require(
            isTokenBound(_msgSender()),
            RuleConditionalTransferLightMultiToken_TransferExecutorUnauthorized(_msgSender())
        );
    }

    function _authorizeComplianceBindingChange(address) internal virtual override {
        _onlyComplianceManager();
    }

    function _approveTransfer(address token, address from, address to, uint256 value) internal virtual {
        require(isTokenBound(token), RuleConditionalTransferLightMultiToken_InvalidToken());
        bytes32 transferHash = _transferHash(token, from, to, value);
        approvalCounts[transferHash] += 1;
        emit TransferApproved(token, from, to, value, approvalCounts[transferHash]);
    }

    function _cancelTransferApproval(address token, address from, address to, uint256 value) internal virtual {
        require(isTokenBound(token), RuleConditionalTransferLightMultiToken_InvalidToken());
        bytes32 transferHash = _transferHash(token, from, to, value);
        uint256 count = approvalCounts[transferHash];

        require(count != 0, RuleConditionalTransferLightMultiToken_TransferApprovalNotFound());

        approvalCounts[transferHash] = count - 1;
        emit TransferApprovalCancelled(token, from, to, value, approvalCounts[transferHash]);
    }

    function _transferred(address token, address from, address to, uint256 value) internal virtual {
        if (from == address(0) || to == address(0)) {
            return;
        }

        bytes32 transferHash = _transferHash(token, from, to, value);
        uint256 count = approvalCounts[transferHash];

        require(count != 0, RuleConditionalTransferLightMultiToken_TransferNotApproved());

        approvalCounts[transferHash] = count - 1;
        emit TransferExecuted(token, from, to, value, approvalCounts[transferHash]);
    }

    function _transferHash(address token, address from, address to, uint256 value)
        internal
        pure
        virtual
        returns (bytes32 hash)
    {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, shl(96, token))
            mstore(add(ptr, 0x20), shl(96, from))
            mstore(add(ptr, 0x40), shl(96, to))
            mstore(add(ptr, 0x60), value)
            hash := keccak256(ptr, 0x80)
        }
    }
}
