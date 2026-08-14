// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {SanctionListOracle} from "src/mocks/SanctionListOracle.sol";
import {RuleSanctionsList, ISanctionsList} from "src/rules/validation/deployment/RuleSanctionsList.sol";

/**
 * @title RuleSanctionsListMintBurnSentinel
 * @notice The zero address is the ERC-20 mint/burn sentinel and must never be sent to the oracle
 *         (`CLAUDE_ANALYSIS.md` F-1).
 * @dev The oracle here sanctions `address(0)` itself -- a degenerate input a real oracle has never
 *      been asked about, and one it is free to answer either way. Before the fix the rule forwarded
 *      the sentinel to the oracle, so a `true` answer blocked EVERY mint and EVERY burn on every
 *      token using this rule, trapping holders behind a third party's handling of a non-wallet.
 *      These assertions fail without the `from != address(0)` / `to != address(0)` guards.
 */
contract RuleSanctionsListMintBurnSentinel is Test, HelperContract {
    SanctionListOracle private oracle;
    RuleSanctionsList private rule;

    function setUp() public {
        oracle = new SanctionListOracle();
        // A real sanctioned wallet, and the sentinel.
        oracle.addToSanctionsList(ATTACKER);
        oracle.addToSanctionsList(ZERO_ADDRESS);
        rule = new RuleSanctionsList(SANCTIONLIST_OPERATOR_ADDRESS, ZERO_ADDRESS, ISanctionsList(address(oracle)));
    }

    function testOracleReallyDoesSanctionTheSentinel() public view {
        // Guards the premise of every assertion below.
        assertTrue(oracle.isSanctioned(ZERO_ADDRESS));
    }

    function testMintIsNotBlockedWhenTheOracleSanctionsTheZeroAddress() public view {
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS2, 10), TRANSFER_OK);
        assertTrue(rule.canTransfer(ZERO_ADDRESS, ADDRESS2, 10));
    }

    function testBurnIsNotBlockedWhenTheOracleSanctionsTheZeroAddress() public view {
        assertEq(rule.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 10), TRANSFER_OK);
        assertTrue(rule.canTransfer(ADDRESS1, ZERO_ADDRESS, 10));
    }

    function testMintAndBurnDoNotRevertOnTheWritePath() public view {
        // `transferred` reverts on a non-zero code, so this is the enforcement-side equivalent.
        rule.transferred(ZERO_ADDRESS, ADDRESS2, 10);
        rule.transferred(ADDRESS1, ZERO_ADDRESS, 10);
    }

    function testMintToASanctionedRecipientIsStillBlocked() public view {
        // The sentinel guard must not weaken screening of the REAL participant.
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ATTACKER, 10), CODE_ADDRESS_TO_IS_SANCTIONED);
    }

    function testBurnFromASanctionedHolderIsStillBlocked() public view {
        assertEq(rule.detectTransferRestriction(ATTACKER, ZERO_ADDRESS, 10), CODE_ADDRESS_FROM_IS_SANCTIONED);
    }

    function testOrdinaryTransfersAreUnaffected() public view {
        assertEq(rule.detectTransferRestriction(ADDRESS1, ADDRESS2, 10), TRANSFER_OK);
        assertEq(rule.detectTransferRestriction(ATTACKER, ADDRESS2, 10), CODE_ADDRESS_FROM_IS_SANCTIONED);
        assertEq(rule.detectTransferRestriction(ADDRESS1, ATTACKER, 10), CODE_ADDRESS_TO_IS_SANCTIONED);
    }

    /**
     * @notice The spender leg is deliberately NOT guarded; the minter must still be screened.
     * @dev `CLAUDE.md` records that the deny-lists screen the minter, which arrives as `spender` on
     *      the 4-arg mint path. Guarding `from`/`to` must not silently disable that.
     */
    function testTheMinterIsStillScreenedAsSpender() public view {
        assertEq(
            rule.detectTransferRestrictionFrom(ATTACKER, ZERO_ADDRESS, ADDRESS2, 10), CODE_ADDRESS_SPENDER_IS_SANCTIONED
        );
    }
}
