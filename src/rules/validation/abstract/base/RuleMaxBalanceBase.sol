// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleMaxBalanceInvariantStorage} from "../invariant/RuleMaxBalanceInvariantStorage.sol";
import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {IBalanceOf} from "../../../interfaces/IBalanceOf.sol";
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleTransferValidation} from "../core/RuleTransferValidation.sol";
import {RuleAddressSetInternal} from "../RuleAddressSet/RuleAddressSetInternal.sol";

/**
 * @title RuleMaxBalanceBase
 * @notice Caps how many tokens a single address may hold. One cap applies to every holder; the
 * operator may exempt specific addresses from it.
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
 * alone on a permissionless token it is a speed bump, not a limit. See
 * `doc/technical/RuleMaxBalance.md`.
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
 * so `balanceOf` is wrapped in `try/catch` and a failure yields {CODE_BALANCE_UNAVAILABLE} rather
 * than a revert. That relies on `balanceToken` still having code, which the setter enforces at
 * configuration time and EIP-6780 (Cancun) makes permanent -- a `try` to a codeless address reverts
 * *uncatchably*. This library targets Cancun or later (see `foundry.toml`). The token is trusted to
 * report an *accurate* balance, but it is NOT trusted to stay callable: that is guarded.
 *
 * @dev The exemption list reuses {RuleAddressSetInternal}, the same `EnumerableSet` machinery as
 * `RuleWhitelist`, so the storage, the zero-address guard and the batch semantics are shared code
 * rather than a second implementation. Only the internal layer is inherited, so this rule publishes
 * one write API with exemption-specific names and events instead of two overlapping ones.
 */
abstract contract RuleMaxBalanceBase is RuleTransferValidation, RuleAddressSetInternal, RuleMaxBalanceInvariantStorage {
    /**
     * @notice The token whose balances are observed.
     * @dev Trusted to report an accurate balance; not trusted to stay callable.
     */
    IBalanceOf public balanceToken;
    /**
     * @notice Maximum number of tokens a single non-exempt address may hold.
     */
    uint256 public maxBalance;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the rule with the observed token and the per-holder cap.
     * @dev Routes through the same internals the public setters use, so the initial configuration is
     * announced by {MaxBalanceTokenUpdated} and {MaxBalanceUpdated} exactly like every later change.
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
     * @notice Updates the maximum balance allowed per non-exempt address.
     * @dev Lowering the cap does **not** claw back balances that already exceed it. Existing holders
     * keep their tokens and may still send them away; they simply cannot receive more until they are
     * back under the cap.
     * @param newMaxBalance The new cap. `0` forbids holding entirely; it does not disable the rule.
     */
    function setMaxBalance(uint256 newMaxBalance) public virtual onlyMaxBalanceManager {
        _setMaxBalance(newMaxBalance);
    }

    /**
     * @notice Updates the token whose balances are observed.
     * @param newBalanceToken The new token contract; must be a contract exposing `balanceOf`.
     */
    function setBalanceToken(address newBalanceToken) public virtual onlyMaxBalanceManager {
        _setBalanceToken(newBalanceToken);
    }

    /**
     * @notice Exempts an address from the cap.
     * @dev Reverts if the address is already exempt, matching the single-item convention used
     * elsewhere in the library. `address(0)` is rejected: it is the mint/burn sentinel, never a
     * holder, and the rule already handles it explicitly.
     * @param targetAddress The address to exempt.
     */
    function addExemptAddress(address targetAddress) public virtual onlyMaxBalanceManager {
        _addExemptAddress(targetAddress);
    }

    /**
     * @notice Removes an address's exemption.
     * @dev Reverts if the address is not exempt. The address keeps whatever it already holds; it
     * simply cannot receive more once over the cap.
     * @param targetAddress The address to bring back under the cap.
     */
    function removeExemptAddress(address targetAddress) public virtual onlyMaxBalanceManager {
        _removeExemptAddress(targetAddress);
    }

    /**
     * @notice Exempts several addresses in one call.
     * @dev Duplicates are skipped and counted rather than reverting; `address(0)` rejects the whole
     * batch. Both follow the library-wide batch convention.
     * @param targetAddresses The addresses to exempt.
     */
    function addExemptAddresses(address[] calldata targetAddresses) public virtual onlyMaxBalanceManager {
        (uint256 added, uint256 skipped) = _addAddresses(targetAddresses);
        emit ExemptAddressesAdded(targetAddresses, added, skipped);
    }

    /**
     * @notice Removes the exemption from several addresses in one call.
     * @dev Addresses that are not exempt are skipped and counted rather than reverting.
     * @param targetAddresses The addresses to bring back under the cap.
     */
    function removeExemptAddresses(address[] calldata targetAddresses) public virtual onlyMaxBalanceManager {
        (uint256 removed, uint256 skipped) = _removeAddresses(targetAddresses);
        emit ExemptAddressesRemoved(targetAddresses, removed, skipped);
    }

    /**
     * @notice Returns whether an address is exempt from the cap.
     * @param targetAddress The address to test.
     * @return True when the address may hold any amount.
     */
    function isExemptAddress(address targetAddress) public view virtual returns (bool) {
        return _isAddressListed(targetAddress);
    }

    /**
     * @notice Returns how many addresses are exempt.
     * @return The number of exempt addresses.
     */
    function exemptAddressCount() public view virtual returns (uint256) {
        return _listedAddressCount();
    }

    /**
     * @notice Returns the balance `to` may still receive before reaching the cap.
     * @dev Mirrors what {_detectTransferRestriction} computes, so an integrator can size a transfer
     * without simulating it. Never reverts.
     * @param to The prospective receiver.
     * @return restrictionCode `0` when the headroom is meaningful, otherwise the code a transfer
     * would return.
     * @return headroom Remaining capacity in token units. `type(uint256).max` for an exempt address
     * or the burn sentinel; meaningless when `restrictionCode` is non-zero.
     */
    function remainingCapacity(address to) public view virtual returns (uint8 restrictionCode, uint256 headroom) {
        if (to == address(0) || _isAddressListed(to)) {
            return (uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK), type(uint256).max);
        }
        (bool available, uint256 balance) = _balanceOf(to);
        if (!available) {
            return (CODE_BALANCE_UNAVAILABLE, 0);
        }
        uint256 cap = maxBalance;
        if (balance >= cap) {
            return (uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK), 0);
        }
        return (uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK), cap - balance);
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
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyMaxBalanceManager() {
        _authorizeMaxBalanceManager();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Authorization hook invoked before any configuration or exemption change.
     * @dev Implemented by concrete subclasses with the desired access-control policy.
     */
    function _authorizeMaxBalanceManager() internal view virtual;

    /**
     * @notice Exempts an address: guards, writes and announces, in one place.
     * @dev Owns the guards as well as the event, so every write path gets both. A subclass that
     *      wanted to pre-exempt a treasury address from its constructor can call this instead of
     *      restating the two `require`s, which is what the scalar setters already do via
     *      {_setMaxBalance} and {_setBalanceToken}.
     *
     *      `_addAddress` does not guard the sentinel; the caller must, exactly as the whitelist
     *      rules and `IdentityRegistryWhitelist` do. The batch path is guarded separately, by the
     *      function pointer `_addAddresses` passes to `AddressSetBatchLib`. Invariant I-12.
     * @param targetAddress The address to exempt.
     */
    function _addExemptAddress(address targetAddress) internal virtual {
        require(targetAddress != address(0), RuleAddressSet_ZeroAddressNotAllowed());
        require(_addAddress(targetAddress), RuleAddressSet_AddressAlreadyListed());
        emit ExemptAddressAdded(targetAddress);
    }

    /**
     * @notice Removes an exemption: guards, writes and announces, in one place.
     * @param targetAddress The address to bring back under the cap.
     */
    function _removeExemptAddress(address targetAddress) internal virtual {
        require(_removeAddress(targetAddress), RuleAddressSet_AddressNotFound());
        emit ExemptAddressRemoved(targetAddress);
    }

    /**
     * @notice Stores the cap and emits {MaxBalanceUpdated}.
     * @param newMaxBalance The new cap.
     */
    function _setMaxBalance(uint256 newMaxBalance) internal virtual {
        maxBalance = newMaxBalance;
        emit MaxBalanceUpdated(newMaxBalance);
    }

    /**
     * @notice Stores the observed token and emits {MaxBalanceTokenUpdated}.
     * @dev Probes `balanceOf` at configuration time so a token that cannot serve the check fails
     * loudly at setup instead of silently blocking every transfer with {CODE_BALANCE_UNAVAILABLE}.
     * @param newBalanceToken The new token contract.
     */
    function _setBalanceToken(address newBalanceToken) internal virtual {
        require(newBalanceToken != address(0), RuleMaxBalance_TokenAddressZeroNotAllowed());
        // Explicit, rather than relying on the uncatchable extcodesize revert the probe below happens
        // to produce for a codeless address: that is compiler behaviour, not a check.
        require(newBalanceToken.code.length != 0, RuleMaxBalance_TokenIsNotAContract(newBalanceToken));
        try IBalanceOf(newBalanceToken).balanceOf(address(this)) returns (uint256) {
        // callable
        }
        catch {
            revert RuleMaxBalance_TokenBalanceUnavailable(newBalanceToken);
        }
        balanceToken = IBalanceOf(newBalanceToken);
        emit MaxBalanceTokenUpdated(newBalanceToken);
    }

    /**
     * @notice Reads an address's balance without ever reverting.
     * @dev Wrapped in `try/catch` so the ERC-1404 / ERC-3643 read path stays revert-free if the token
     * breaks after configuration -- a proxy upgraded to something that reverts, or a pausable
     * implementation that reverts while paused.
     * @param account The address to query.
     * @return available True when the balance could be read.
     * @return balance The balance; meaningless when `available` is false.
     */
    function _balanceOf(address account) internal view virtual returns (bool available, uint256 balance) {
        try balanceToken.balanceOf(account) returns (uint256 balance_) {
            return (true, balance_);
        } catch {
            return (false, 0);
        }
    }

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
        // Burns cannot breach a maximum, and address(0) is the sentinel rather than a holder.
        if (to == address(0)) {
            return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
        }
        // Exempt receivers may hold any amount.
        if (_isAddressListed(to)) {
            return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
        }
        (bool available, uint256 balance) = _balanceOf(to);
        if (!available) {
            return CODE_BALANCE_UNAVAILABLE;
        }
        // Overflow-safe: `balance + value` could exceed uint256 on a MUST-NOT-revert view, so
        // compare against the remaining headroom instead.
        uint256 cap = maxBalance;
        if (balance > cap || value > cap - balance) {
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
