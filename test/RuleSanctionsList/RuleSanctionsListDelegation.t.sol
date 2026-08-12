// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {SanctionsListExtraCheckHarness} from "src/mocks/harness/SanctionsListDelegationHarness.sol";
import {SanctionListOracle} from "src/mocks/SanctionListOracle.sol";
import {ISanctionsList} from "src/rules/interfaces/ISanctionsList.sol";

/**
 * @title RuleSanctionsListDelegation
 * @notice The `transferFrom` path must always consult the direct restriction check, whether or not
 *         an oracle is configured (`FEEDBACK_12.md` F-2).
 * @dev The subclass under test adds an oracle-independent check. With no oracle configured, the
 *      previous implementation returned `TRANSFER_OK` from `detectTransferRestrictionFrom` without
 *      ever reaching `_detectTransferRestriction`, so the subclass's check applied to `transfer` but
 *      not to `transferFrom`. `testExtraCheckAppliesToTransferFromWithNoOracle` fails against that
 *      implementation and is the reason the restructure exists.
 */
contract RuleSanctionsListDelegation is Test, HelperContract {
    address private constant BLOCKED = address(0xB10C);
    address private constant SANCTIONED = address(99);

    SanctionListOracle private oracle;

    function setUp() public {
        oracle = new SanctionListOracle();
        oracle.addToSanctionsList(SANCTIONED);
    }

    function _withoutOracle() internal returns (SanctionsListExtraCheckHarness) {
        return new SanctionsListExtraCheckHarness(
            SANCTIONLIST_OPERATOR_ADDRESS, ZERO_ADDRESS, ISanctionsList(address(0)), BLOCKED
        );
    }

    function _withOracle() internal returns (SanctionsListExtraCheckHarness) {
        return new SanctionsListExtraCheckHarness(
            SANCTIONLIST_OPERATOR_ADDRESS, ZERO_ADDRESS, ISanctionsList(address(oracle)), BLOCKED
        );
    }

    /*//////////////////////////////////////////////////////////////
                        No oracle configured
    //////////////////////////////////////////////////////////////*/

    function testExtraCheckAppliesToTransferWithNoOracle() public {
        // This direction always worked: the direct path calls the hook unconditionally.
        SanctionsListExtraCheckHarness rule = _withoutOracle();
        assertEq(rule.detectTransferRestriction(BLOCKED, ADDRESS2, 10), rule.CODE_EXTRA_BLOCKED());
    }

    function testExtraCheckAppliesToTransferFromWithNoOracle() public {
        // THE REGRESSION: with the delegation nested inside the oracle-set branch this returned
        // TRANSFER_OK, so `transfer` and `transferFrom` disagreed about the same pair of addresses.
        SanctionsListExtraCheckHarness rule = _withoutOracle();
        assertEq(
            rule.detectTransferRestrictionFrom(ADDRESS3, BLOCKED, ADDRESS2, 10),
            rule.CODE_EXTRA_BLOCKED(),
            "transferFrom must reach the same hook as transfer"
        );
        assertFalse(rule.canTransferFrom(ADDRESS3, BLOCKED, ADDRESS2, 10));
    }

    function testTheTwoEntrypointsAgreeWithNoOracle() public {
        SanctionsListExtraCheckHarness rule = _withoutOracle();
        assertEq(
            rule.detectTransferRestriction(ADDRESS1, BLOCKED, 10),
            rule.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, BLOCKED, 10),
            "the receiver leg must be screened identically on both paths"
        );
        // An unrelated pair is still unrestricted; the rule is not simply rejecting everything.
        assertEq(rule.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 10), TRANSFER_OK);
    }

    /*//////////////////////////////////////////////////////////////
                        Oracle configured
    //////////////////////////////////////////////////////////////*/

    function testExtraCheckStillAppliesWithAnOracle() public {
        SanctionsListExtraCheckHarness rule = _withOracle();
        assertEq(rule.detectTransferRestriction(BLOCKED, ADDRESS2, 10), rule.CODE_EXTRA_BLOCKED());
        assertEq(rule.detectTransferRestrictionFrom(ADDRESS3, BLOCKED, ADDRESS2, 10), rule.CODE_EXTRA_BLOCKED());
    }

    function testTheSpenderCheckStillTakesPriority() public {
        // The oracle-driven spender check must still short-circuit ahead of the delegated hook.
        SanctionsListExtraCheckHarness rule = _withOracle();
        assertEq(
            rule.detectTransferRestrictionFrom(SANCTIONED, BLOCKED, ADDRESS2, 10), CODE_ADDRESS_SPENDER_IS_SANCTIONED
        );
    }

    function testBaseScreeningIsUnchanged() public {
        SanctionsListExtraCheckHarness rule = _withOracle();
        assertEq(rule.detectTransferRestriction(SANCTIONED, ADDRESS2, 10), CODE_ADDRESS_FROM_IS_SANCTIONED);
        assertEq(rule.detectTransferRestriction(ADDRESS1, SANCTIONED, 10), CODE_ADDRESS_TO_IS_SANCTIONED);
        assertEq(rule.detectTransferRestrictionFrom(ADDRESS3, ADDRESS1, ADDRESS2, 10), TRANSFER_OK);
    }
}
