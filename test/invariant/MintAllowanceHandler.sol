// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RuleMintAllowance} from "src/rules/operation/RuleMintAllowance.sol";

/**
 * @title MintAllowanceHandler
 * @notice Invariant-test handler driving the mint-quota accounting of {RuleMintAllowance}.
 * @dev The handler is the entity bound to the rule (`bindToken(handler)`), so it can call the
 *      `transferred` execution hook directly, and it holds `ALLOWANCE_OPERATOR_ROLE` so it can
 *      set/increase/decrease quotas.
 *
 *      It maintains a ghost mirror of the expected allowance per minter. The suite asserts:
 *        - `rule.mintAllowance(m) == ghostAllowance[m]` for every minter (exact accounting, INV-7)
 *        - `totalMinted <= totalCredited` (a minter can never mint more than was ever granted)
 *
 *      Calls that would revert are skipped rather than attempted; if a rule call did revert, the whole
 *      handler call reverts and the ghost update rolls back with it, so the mirror stays consistent.
 */
contract MintAllowanceHandler is Test {
    /**
     * @notice The rule under test.
     */
    RuleMintAllowance public immutable rule;

    /**
     * @notice Sum of every amount ever credited (absolute sets + increases).
     */
    uint256 public totalCredited;
    /**
     * @notice Sum of every amount ever minted through the quota.
     */
    uint256 public totalMinted;
    /**
     * @notice Number of non-mint `transferred` calls made (these must never touch a quota).
     */
    uint256 public regularTransferCalls;

    /**
     * @notice Ghost mirror of the expected remaining allowance per minter.
     */
    mapping(address minter => uint256 allowance) public ghostAllowance;

    /**
     * @dev Small minter set so the fuzzer repeatedly hits the same quotas.
     */
    address[3] internal _minters = [address(0xB1), address(0xB2), address(0xB3)];

    /**
     * @dev Upper bound per credit, keeping `totalCredited` far from overflow across all runs.
     */
    uint256 internal constant MAX_CREDIT = 1e30;

    constructor(RuleMintAllowance rule_) {
        rule = rule_;
    }

    /*//////////////////////////////////////////////////////////////
                            HANDLER ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets a minter's quota to an absolute amount.
     */
    function setAllowance(uint256 minterSeed, uint256 amount) external {
        address minter = _minter(minterSeed);
        amount = bound(amount, 0, MAX_CREDIT);
        rule.setMintAllowance(minter, amount);
        ghostAllowance[minter] = amount;
        totalCredited += amount;
    }

    /**
     * @notice Increases a minter's quota.
     */
    function increase(uint256 minterSeed, uint256 amount) external {
        address minter = _minter(minterSeed);
        amount = bound(amount, 0, MAX_CREDIT);
        rule.increaseMintAllowance(minter, amount);
        ghostAllowance[minter] += amount;
        totalCredited += amount;
    }

    /**
     * @notice Decreases a minter's quota, staying within the current balance so the call is accepted.
     */
    function decrease(uint256 minterSeed, uint256 amount) external {
        address minter = _minter(minterSeed);
        uint256 current = ghostAllowance[minter];
        if (current == 0) {
            return;
        }
        amount = bound(amount, 0, current);
        rule.decreaseMintAllowance(minter, amount);
        ghostAllowance[minter] = current - amount;
    }

    /**
     * @notice Mints within the minter's quota via the spender-aware hook (`from == address(0)`).
     */
    function mint(uint256 minterSeed, uint256 toSeed, uint256 value) external {
        address minter = _minter(minterSeed);
        uint256 current = ghostAllowance[minter];
        if (current == 0) {
            return;
        }
        value = bound(value, 1, current);
        address to = _minters[toSeed % _minters.length];

        rule.transferred(minter, address(0), to, value);

        ghostAllowance[minter] = current - value;
        totalMinted += value;
    }

    /**
     * @notice A non-mint transfer (`from != address(0)`) must never touch any quota. The ghost is
     *         deliberately left unchanged, so the mirror invariant proves the rule ignores it.
     */
    function regularTransfer(uint256 minterSeed, uint256 value) external {
        address spender = _minter(minterSeed);
        value = bound(value, 0, 1e24);
        rule.transferred(spender, _minters[0], _minters[1], value);
        regularTransferCalls += 1;
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the minter at `index` and its expected (ghost) allowance.
     */
    function minterAt(uint256 index) external view returns (address minter, uint256 expected) {
        minter = _minters[index % _minters.length];
        expected = ghostAllowance[minter];
    }

    /**
     * @notice Number of distinct minters driven by the handler.
     */
    function minterCount() external view returns (uint256) {
        return _minters.length;
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _minter(uint256 seed) internal view virtual returns (address) {
        return _minters[seed % _minters.length];
    }
}
