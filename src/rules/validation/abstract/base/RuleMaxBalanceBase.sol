// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleTransferValidation} from "../core/RuleTransferValidation.sol";
import {BalanceCapManager} from "../core/BalanceCapManager.sol";

/**
 * @title RuleMaxBalanceBase
 * @notice Caps how many tokens a single address may hold. One cap applies to every holder; the
 * operator may exempt specific addresses from it.
 *
 * @dev This contract is the **rule half**: the constructor, the ERC-1404 / ERC-3643 surface
 * (`canReturnTransferRestrictionCode`, `messageForTransferRestriction`, `transferred`) and the
 * restriction logic that turns a breached cap into a restriction code. The cap itself -- the
 * observed token, the ceiling, the exemption list, the setters and the revert-free balance read --
 * lives in {BalanceCapManager}, which carries no constructor and no ERC-1404 dependency so it can be
 * reused or initialized differently.
 *
 * @dev The rule screens the **receiver**: a transfer is rejected when
 * `balanceOf(to) + value > maxBalance`. That covers mints as well, since a mint raises the
 * receiver's balance the same way a transfer does. Burns (`to == address(0)`) are exempt, and the
 * sender is never screened -- reducing a balance can never breach a maximum.
 *
 * WARNING: **this rule is only as strong as the one-entity-one-wallet property of the token.** It
 * counts tokens per *address*, which is the only thing a compliance contract can observe. A holder
 * who wants more than `maxBalance` can simply spread the position across several addresses. Deploy
 * it together with a rule that ties addresses to identities -- `RuleWhitelist`,
 * `RuleReceiverWhitelist` or `RuleIdentityRegistry` -- and admit one address per investor. Used
 * alone on a permissionless token it is a speed bump, not a limit.
 *
 * @dev **The check assumes the token calls this BEFORE it moves the value.** It compares
 * `balanceOf(to) + value` against the cap, which is only correct while `balanceOf(to)` still
 * excludes `value`. CMTAT satisfies this: `_checkTransferred(...)` runs before
 * `ERC20Upgradeable._transfer(...)`. A token that notified its compliance contract *after* updating
 * balances would double-count, halving the effective cap and rejecting a transfer that exactly
 * reaches it. Pinned by `testMintExactlyToTheCapProvesPreUpdateAccounting`.
 *
 * @dev `maxBalance` has **no magic value**. `0` means non-exempt addresses may not hold any tokens;
 * it does not disable the rule. To lift the cap, set it to `type(uint256).max` or remove the rule
 * from the engine.
 *
 * @dev IMPORTANT: the read path (`detectTransferRestriction*` / `canTransfer*`) must never revert,
 * so a balance that cannot be read yields {CODE_BALANCE_UNAVAILABLE} rather than a revert. That is
 * fail-closed: without a balance the cap cannot be verified, so the transfer is blocked rather than
 * assumed safe. Burns and exempt receivers are resolved before any balance is read, so they keep
 * working while the token is unreadable.
 */
abstract contract RuleMaxBalanceBase is RuleTransferValidation, BalanceCapManager {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the rule with the observed token and the per-holder cap.
     * @dev Routes through {BalanceCapManager}'s internals, which are constructor-agnostic, so the
     * initial configuration is announced by {MaxBalanceTokenUpdated} and {MaxBalanceUpdated} exactly
     * like every later change. An upgradeable variant would call the same two from an initializer.
     * @param balanceToken_ Token whose `balanceOf` is checked; must be a contract.
     * @param maxBalance_ Maximum balance per non-exempt address. `0` forbids holding entirely.
     */
    constructor(address balanceToken_, uint256 maxBalance_) {
        _setBalanceToken(balanceToken_);
        _setMaxBalance(maxBalance_);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether this rule can produce the given restriction code.
     * @param restrictionCode Restriction code to test.
     * @return True if `restrictionCode` is one of this rule's codes.
     */
    function canReturnTransferRestrictionCode(uint8 restrictionCode) external pure override returns (bool) {
        return restrictionCode == CODE_MAX_BALANCE_EXCEEDED || restrictionCode == CODE_BALANCE_UNAVAILABLE;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the balance `to` may still receive before reaching the cap.
     * @dev Mirrors what {_detectTransferRestriction} computes, so an integrator can size a transfer
     * without simulating it. Never reverts. This is the ERC-1404-flavoured wrapper over
     * {BalanceCapManager._remainingCapacity}: the manager answers in booleans, the rule maps that to
     * a restriction code.
     * @param to The prospective receiver.
     * @return restrictionCode `0` when the headroom is meaningful, otherwise the code a transfer
     * would return.
     * @return headroom Remaining capacity in token units. `type(uint256).max` for an exempt address
     * or the burn sentinel; meaningless when `restrictionCode` is non-zero.
     */
    function remainingCapacity(address to) public view virtual returns (uint8 restrictionCode, uint256 headroom) {
        (bool balanceAvailable, uint256 headroom_) = _remainingCapacity(to);
        if (!balanceAvailable) {
            return (CODE_BALANCE_UNAVAILABLE, 0);
        }
        return (uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK), headroom_);
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
        if (restrictionCode == CODE_MAX_BALANCE_EXCEEDED) {
            return TEXT_MAX_BALANCE_EXCEEDED;
        } else if (restrictionCode == CODE_BALANCE_UNAVAILABLE) {
            return TEXT_BALANCE_UNAVAILABLE;
        }
        return TEXT_CODE_NOT_FOUND;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc RuleTransferValidation
     */
    function _detectTransferRestriction(
        address,
        /* from */
        address to,
        uint256 value
    )
        internal
        view
        virtual
        override
        returns (uint8)
    {
        (bool balanceAvailable, bool exceeded) = _capExceeded(to, value);
        if (!balanceAvailable) {
            return CODE_BALANCE_UNAVAILABLE;
        }
        if (exceeded) {
            return CODE_MAX_BALANCE_EXCEEDED;
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @inheritdoc RuleTransferValidation
     * @dev The spender is irrelevant: the cap constrains who ends up holding the tokens, not who
     * moved them.
     */
    function _detectTransferRestrictionFrom(address, address from, address to, uint256 value)
        internal
        view
        virtual
        override
        returns (uint8)
    {
        return _detectTransferRestriction(from, to, value);
    }

    /**
     * @notice Enforces the cap for a direct transfer, reverting on violation.
     * @param from Sender address.
     * @param to Recipient address whose resulting balance is checked.
     * @param value Transfer amount.
     */
    function _transferred(address from, address to, uint256 value) internal view virtual {
        uint8 code = _detectTransferRestriction(from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleMaxBalance_InvalidTransfer(address(this), from, to, value, code)
        );
    }

    /**
     * @notice Enforces the cap for a `transferFrom`, reverting on violation.
     * @param spender Approved spender initiating the transfer; the minter on the mint path.
     * @param from Sender address.
     * @param to Recipient address whose resulting balance is checked.
     * @param value Transfer amount.
     */
    function _transferredFrom(address spender, address from, address to, uint256 value) internal view virtual {
        uint8 code = _detectTransferRestrictionFrom(spender, from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleMaxBalance_InvalidTransferFrom(address(this), spender, from, to, value, code)
        );
    }
}
