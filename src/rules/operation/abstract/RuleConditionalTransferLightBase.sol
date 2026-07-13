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
import {RuleConditionalTransferLightApprovalBase} from "./RuleConditionalTransferLightApprovalBase.sol";
import {VersionModule} from "../../../modules/VersionModule.sol";

/**
 * @title RuleConditionalTransferLightBase
 * @dev Wires the approval state machine into the ERC-3643 / ERC-1404 / IRule compliance
 *      interface layer and enforces single-token binding.
 */
abstract contract RuleConditionalTransferLightBase is
    VersionModule,
    ERC3643ComplianceModule,
    RuleConditionalTransferLightApprovalBase,
    IRule
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Compliance hook invoked when tokens are created (minted); consumes an approval if applicable.
     * @param to The recipient of the created tokens.
     * @param value The amount of tokens created.
     */
    function created(address to, uint256 value) external onlyBoundToken {
        _transferred(address(0), to, value);
    }

    /**
     * @notice Compliance hook invoked when tokens are destroyed (burned); consumes an approval if applicable.
     * @param from The holder whose tokens are destroyed.
     * @param value The amount of tokens destroyed.
     */
    function destroyed(address from, uint256 value) external onlyBoundToken {
        _transferred(from, address(0), value);
    }

    /**
     * @inheritdoc IRule
     */
    function canReturnTransferRestrictionCode(uint8 restrictionCode) external pure override(IRule) returns (bool) {
        return restrictionCode == CODE_TRANSFER_REQUEST_NOT_APPROVED;
    }

    /**
     * @inheritdoc IERC1404
     */
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

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Approves and performs a transferFrom using this rule as spender.
     * @dev Requires `from` to have approved this contract on the token.
     * @dev This function is only safe for tokens that call back `transferred()` during transfer.
     * @dev CEI is intentionally inverted so the approval exists for the callback.
     * @param from The holder to transfer tokens from.
     * @param to The recipient of the transfer.
     * @param value The amount to transfer.
     * @return True when the transfer succeeds.
     */
    function approveAndTransferIfAllowed(address from, address to, uint256 value)
        public
        onlyTransferApprover
        returns (bool)
    {
        address token = getTokenBound();
        require(token != address(0), RuleConditionalTransferLight_TokenNotBound());

        approveTransfer(from, to, value);

        uint256 allowed = IERC20(token).allowance(from, address(this));
        require(allowed >= value, RuleConditionalTransferLight_InsufficientAllowance(token, from, allowed, value));

        IERC20(token).safeTransferFrom(from, to, value);
        return true;
    }

    /**
     * @inheritdoc IERC3643IComplianceContract
     */
    function transferred(address from, address to, uint256 value)
        public
        override(IERC3643IComplianceContract)
        onlyTransferExecutor
    {
        _transferred(from, to, value);
    }

    /**
     * @inheritdoc IRuleEngine
     */
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
        _transferred(from, to, value);
    }

    /**
     * @notice Binds a token to this rule. Reverts if a token is already bound.
     * @dev Enforces single-token binding to prevent cross-token approval replay.
     *      To migrate to a new token, call `unbindToken` first.
     * @dev WARNING: `unbindToken` does not clear `approvalCounts`. Stale approvals
     *      from the previous token remain in storage and can be consumed after rebinding.
     *      The operator who controls rebinding also controls approvals, so the trust
     *      model is preserved, but integrators should be aware of this behavior.
     *      Call {resetApproval} for each affected transfer before rebinding to discard them.
     * @param token The token to bind to this rule.
     */
    function bindToken(address token) public override onlyComplianceManager {
        require(getTokenBound() == address(0), RuleConditionalTransferLight_TokenAlreadyBound());
        _bindToken(token);
    }

    /**
     * @inheritdoc IERC1404
     */
    function detectTransferRestriction(address from, address to, uint256 value)
        public
        view
        override(IERC1404)
        returns (uint8)
    {
        if (from == address(0) || to == address(0)) {
            return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
        }
        bytes32 transferHash = _transferHash(from, to, value);
        if (approvalCounts[transferHash] == 0) {
            return CODE_TRANSFER_REQUEST_NOT_APPROVED;
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @inheritdoc IERC1404Extend
     */
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

    /**
     * @inheritdoc IERC3643ComplianceRead
     */
    function canTransfer(address from, address to, uint256 value)
        public
        view
        override(IERC3643ComplianceRead)
        returns (bool)
    {
        return detectTransferRestriction(from, to, value) == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @inheritdoc IERC7551Compliance
     */
    function canTransferFrom(address spender, address from, address to, uint256 value)
        public
        view
        override(IERC7551Compliance)
        returns (bool)
    {
        return detectTransferRestrictionFrom(spender, from, to, value)
            == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Authorizes transfer execution: only the bound token may call the execution hooks.
     */
    function _authorizeTransferExecution() internal view override {
        require(isTokenBound(_msgSender()), RuleConditionalTransferLight_TransferExecutorUnauthorized(_msgSender()));
    }
}
