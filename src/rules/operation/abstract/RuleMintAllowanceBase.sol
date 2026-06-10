// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643ComplianceRead, IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IERC7551Compliance} from "CMTAT/interfaces/tokenization/draft-IERC7551.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";
import {ERC3643ComplianceModule} from "RuleEngine/modules/ERC3643ComplianceModule.sol";
import {VersionModule} from "../../../modules/VersionModule.sol";
import {RuleMintAllowanceInvariantStorage} from "./RuleMintAllowanceInvariantStorage.sol";

/**
 * @title RuleMintAllowanceBase
 * @notice Core logic for per-minter mint quota enforcement.
 * @dev Operators set the number of tokens each minter address is allowed to mint.
 *      Each mint reduces the minter's allowance. Allowances can be set to an absolute
 *      value or adjusted incrementally via `increaseMintAllowance`/`decreaseMintAllowance`.
 *
 *      The rule tracks mints via the 4-arg `transferred(spender, from=0, to, value)` path
 *      introduced in CMTAT v3.3. The 3-arg `transferred(from=0, to, value)` path has no
 *      minter identity and performs no deduction.
 *
 *      `detectTransferRestriction(from, to, value)` always returns TRANSFER_OK because
 *      the minter identity is unavailable in the 3-arg call; use
 *      `detectTransferRestrictionFrom(minter, address(0), to, amount)` to query allowance.
 *
 *      Callers of the state-modifying `transferred()` functions must be bound via
 *      `bindToken(ruleEngineAddress)` before minting starts. In a standard CMTAT +
 *      RuleEngine setup the RuleEngine address is the entity to bind.
 */
abstract contract RuleMintAllowanceBase is
    VersionModule,
    ERC3643ComplianceModule,
    RuleMintAllowanceInvariantStorage,
    IRule
{
    /*//////////////////////////////////////////////////////////////
                             STATE
    //////////////////////////////////////////////////////////////*/

    mapping(address minter => uint256 allowance) public mintAllowance;

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyAllowanceOperator() {
        _authorizeSetMintAllowance();
        _;
    }

    function _authorizeSetMintAllowance() internal view virtual;

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function canReturnTransferRestrictionCode(uint8 restrictionCode) external pure override(IRule) returns (bool) {
        return restrictionCode == CODE_MINTER_ALLOWANCE_EXCEEDED;
    }

    function created(address, uint256) external virtual override onlyBoundToken {}

    function destroyed(address, uint256) external virtual override onlyBoundToken {}

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets `minter`'s allowance to an absolute `amount`.
     */
    function setMintAllowance(address minter, uint256 amount) public virtual onlyAllowanceOperator {
        _setMintAllowance(minter, amount);
    }

    /**
     * @notice Increases `minter`'s allowance by `amount`.
     */
    function increaseMintAllowance(address minter, uint256 amount) public virtual onlyAllowanceOperator {
        uint256 newAllowance = mintAllowance[minter] + amount;
        mintAllowance[minter] = newAllowance;
        emit MintAllowanceIncreased(minter, amount, newAllowance);
    }

    /**
     * @notice Decreases `minter`'s allowance by `amount`. Reverts if the reduction
     *         would underflow (i.e. `amount > current allowance`).
     */
    function decreaseMintAllowance(address minter, uint256 amount) public virtual onlyAllowanceOperator {
        uint256 current = mintAllowance[minter];
        require(amount <= current, RuleMintAllowance_DecreaseBelowZero(minter, current, amount));
        uint256 newAllowance = current - amount;
        mintAllowance[minter] = newAllowance;
        emit MintAllowanceDecreased(minter, amount, newAllowance);
    }

    /**
     * @notice Binds a caller to this rule. Reverts if a caller is already bound.
     * @dev Enforces single-target binding to prevent one allowance state from being
     *      shared across several RuleEngines/tokens. To migrate, call `unbindToken`
     *      first, then bind the new caller.
     */
    function bindToken(address token) public virtual override onlyComplianceManager {
        require(getTokenBound() == address(0), RuleMintAllowance_TokenAlreadyBound());
        _bindToken(token);
    }

    function messageForTransferRestriction(uint8 restrictionCode)
        public
        pure
        override(IERC1404)
        returns (string memory)
    {
        if (restrictionCode == CODE_MINTER_ALLOWANCE_EXCEEDED) {
            return TEXT_MINTER_ALLOWANCE_EXCEEDED;
        }
        return TEXT_CODE_NOT_FOUND;
    }

    /**
     * @dev 3-arg path: no minter identity available; performs no deduction.
     *      Mints always arrive via the 4-arg path in CMTAT v3.3+.
     */
    function transferred(address from, address to, uint256 value)
        public
        virtual
        override(IERC3643IComplianceContract)
        onlyBoundToken
    {
        _transferred(from, to, value);
    }

    /**
     * @dev 4-arg path: `spender` is the minter when `from == address(0)`.
     *      Deducts `value` from `mintAllowance[spender]`; reverts if insufficient.
     */
    function transferred(address spender, address from, address to, uint256 value)
        public
        virtual
        override(IRuleEngine)
        onlyBoundToken
    {
        _transferredFrom(spender, from, to, value);
    }

    /**
     * @dev Always returns TRANSFER_OK: the minter address is not available in the
     *      3-arg call. Call `detectTransferRestrictionFrom` to check a minter's quota.
     */
    function detectTransferRestriction(address, address, uint256)
        public
        view
        virtual
        override(IERC1404)
        returns (uint8)
    {
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    function detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        public
        view
        virtual
        override(IERC1404Extend)
        returns (uint8)
    {
        return _detectTransferRestrictionFrom(spender, from, to, value);
    }

    /**
     * @dev Always returns true: use `canTransferFrom` to check mint allowance.
     */
    function canTransfer(address, address, uint256)
        public
        view
        virtual
        override(IERC3643ComplianceRead)
        returns (bool)
    {
        return true;
    }

    function canTransferFrom(address spender, address from, address to, uint256 value)
        public
        view
        virtual
        override(IERC7551Compliance)
        returns (bool)
    {
        return detectTransferRestrictionFrom(spender, from, to, value)
            == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _detectTransferRestrictionFrom(address spender, address from, address, uint256 value)
        internal
        view
        virtual
        returns (uint8)
    {
        if (from == address(0) && mintAllowance[spender] < value) {
            return CODE_MINTER_ALLOWANCE_EXCEEDED;
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    function _transferred(address, address, uint256) internal virtual {
        // 3-arg path: no minter identity; regular transfers are not tracked by this rule.
    }

    function _transferredFrom(address spender, address from, address, uint256 value) internal virtual {
        if (from != address(0)) {
            return;
        }
        uint256 current = mintAllowance[spender];
        require(value <= current, RuleMintAllowance_AllowanceExceeded(address(this), spender, current, value));
        uint256 remaining = current - value;
        mintAllowance[spender] = remaining;
        emit MintAllowanceConsumed(spender, value, remaining);
    }

    function _setMintAllowance(address minter, uint256 amount) internal virtual {
        mintAllowance[minter] = amount;
        emit MintAllowanceSet(minter, amount);
    }
}
