// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RuleConditionalTransferLight} from "src/rules/operation/RuleConditionalTransferLight.sol";

/**
 * @title ConditionalTransferHandler
 * @notice Invariant-test handler driving the approval state machine of {RuleConditionalTransferLight}.
 * @dev The handler is itself the entity bound to the rule (`bindToken(handler)`), so it can call the
 *      `transferred` execution hooks directly, and it holds `OPERATOR_ROLE` so it can approve/cancel.
 *
 *      Ghost counters track every accepted operation. The suite asserts:
 *          totalApproved - totalCancelled - totalExecuted == Σ approvalCounts
 *      i.e. approvals are conserved: each `approveTransfer` is eventually either cancelled, consumed,
 *      or still outstanding — never double-spent and never lost (INV-5).
 *
 *      Calls that would revert are skipped rather than attempted, so the accounting reflects only
 *      operations the rule actually accepted.
 */
contract ConditionalTransferHandler is Test {
    /**
     * @notice The rule under test.
     */
    RuleConditionalTransferLight public immutable rule;

    /**
     * @notice Number of approvals successfully recorded.
     */
    uint256 public totalApproved;
    /**
     * @notice Number of approvals successfully cancelled.
     */
    uint256 public totalCancelled;
    /**
     * @notice Number of approvals successfully consumed by a transfer.
     */
    uint256 public totalExecuted;
    /**
     * @notice Number of mint/burn callbacks made (these must never consume an approval).
     */
    uint256 public mintBurnCalls;

    /**
     * @notice A (from, to, value) tuple that has been approved at least once.
     */
    struct TransferKey {
        address from;
        address to;
        uint256 value;
    }

    TransferKey[] internal _keys;
    mapping(bytes32 hash => bool seen) internal _seen;

    /**
     * @dev Small actor set and value range so the fuzzer collides on the same tuples often.
     */
    address[3] internal _actors = [address(0xA1), address(0xA2), address(0xA3)];

    constructor(RuleConditionalTransferLight rule_) {
        rule = rule_;
    }

    /*//////////////////////////////////////////////////////////////
                            HANDLER ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Records one approval for a fuzzed (from, to, value) tuple.
     */
    function approve(uint256 fromSeed, uint256 toSeed, uint256 valueSeed) external {
        (address from, address to, uint256 value) = _tuple(fromSeed, toSeed, valueSeed);
        rule.approveTransfer(from, to, value);
        totalApproved += 1;
        _record(from, to, value);
    }

    /**
     * @notice Cancels one outstanding approval, if any exists for the selected tuple.
     */
    function cancel(uint256 idx) external {
        if (_keys.length == 0) {
            return;
        }
        TransferKey memory k = _keys[idx % _keys.length];
        if (rule.approvedCount(k.from, k.to, k.value) == 0) {
            return;
        }
        rule.cancelTransferApproval(k.from, k.to, k.value);
        totalCancelled += 1;
    }

    /**
     * @notice Consumes one outstanding approval via the execution hook (handler is the bound entity).
     */
    function execute(uint256 idx) external {
        if (_keys.length == 0) {
            return;
        }
        TransferKey memory k = _keys[idx % _keys.length];
        if (rule.approvedCount(k.from, k.to, k.value) == 0) {
            return;
        }
        rule.transferred(k.from, k.to, k.value);
        totalExecuted += 1;
    }

    /**
     * @notice Fires a mint or burn callback. These are exempt from approval consumption, so they must
     *         leave `approvalCounts` untouched — deliberately NOT counted in `totalExecuted`, which is
     *         what makes the conservation invariant prove the exemption.
     */
    function executeMintOrBurn(uint256 seed, uint256 valueSeed) external {
        address other = _actors[seed % _actors.length];
        uint256 value = bound(valueSeed, 0, 1e24);
        if (seed % 2 == 0) {
            rule.transferred(address(0), other, value);
        } else {
            rule.transferred(other, address(0), value);
        }
        mintBurnCalls += 1;
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sum of `approvalCounts` across every tuple ever approved.
     */
    function sumApprovalCounts() external view returns (uint256 sum) {
        for (uint256 i = 0; i < _keys.length; ++i) {
            TransferKey memory k = _keys[i];
            sum += rule.approvedCount(k.from, k.to, k.value);
        }
    }

    /**
     * @notice Number of distinct tuples approved at least once.
     */
    function keyCount() external view returns (uint256) {
        return _keys.length;
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _tuple(uint256 fromSeed, uint256 toSeed, uint256 valueSeed)
        internal
        view
        virtual
        returns (address from, address to, uint256 value)
    {
        from = _actors[fromSeed % _actors.length];
        to = _actors[toSeed % _actors.length];
        value = bound(valueSeed, 1, 5);
    }

    function _record(address from, address to, uint256 value) internal virtual {
        bytes32 key = keccak256(abi.encode(from, to, value));
        if (!_seen[key]) {
            _seen[key] = true;
            _keys.push(TransferKey(from, to, value));
        }
    }
}
