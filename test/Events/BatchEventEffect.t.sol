// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test, Vm} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {IAddressList} from "src/rules/interfaces/IAddressList.sol";
import {RuleERC2980} from "src/rules/validation/deployment/RuleERC2980.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {
    RuleERC2980InvariantStorage
} from "src/rules/validation/abstract/RuleERC2980/invariantStorage/RuleERC2980InvariantStorage.sol";

/**
 * @title BatchEventEffect
 * @notice Batch events must report what actually changed, not just what was submitted
 *         (`CLAUDE_ANALYSIS.md` C-4).
 * @dev A batch skips entries already present (or already absent, on removal), so the input array
 *      alone cannot tell a consumer whether anything happened: a batch of 100 fresh members and a
 *      batch of 100 no-ops emitted the identical event. The `added` / `removed` / `skipped` counters
 *      were being computed inside the loops and then discarded by every caller.
 *
 *      These tests pin the counters at the boundary that matters — a batch that is *partly* a no-op —
 *      for the shared `RuleAddressSet` machinery and for `RuleERC2980`, which keeps its own copy of
 *      the same loops for its whitelist and its frozenlist.
 */
contract BatchEventEffect is Test, HelperContract {
    RuleWhitelist private rule;
    RuleERC2980 private erc2980;

    function setUp() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false, true);
        erc2980 = new RuleERC2980(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, true);
        vm.stopPrank();
    }

    function _three() internal pure returns (address[] memory a) {
        a = new address[](3);
        a[0] = ADDRESS1;
        a[1] = ADDRESS2;
        a[2] = ADDRESS3;
    }

    /*//////////////////////////////////////////////////////////////
                        RuleAddressSet machinery
    //////////////////////////////////////////////////////////////*/

    function testAddAddressesReportsAllNew() public {
        address[] memory batch = _three();
        vm.expectEmit(true, true, true, true);
        emit IAddressList.AddAddresses(batch, 3, 0);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddresses(batch);
    }

    /**
     * @notice The case the input array cannot express: a batch that changes nothing.
     * @dev Before C-4 this emitted an event byte-identical to the one above.
     */
    function testAddAddressesReportsAFullyRedundantBatch() public {
        address[] memory batch = _three();
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddresses(batch);

        vm.expectEmit(true, true, true, true);
        emit IAddressList.AddAddresses(batch, 0, 3); // nothing added, all skipped
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddresses(batch);

        assertEq(rule.listedAddressCount(), 3, "a redundant batch must not change the set");
    }

    function testAddAddressesReportsAPartialBatch() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(ADDRESS2); // one already present

        address[] memory batch = _three();
        vm.expectEmit(true, true, true, true);
        emit IAddressList.AddAddresses(batch, 2, 1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddresses(batch);

        assertEq(rule.listedAddressCount(), 3);
    }

    function testRemoveAddressesReportsAPartialBatch() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule.addAddress(ADDRESS1);
        rule.addAddress(ADDRESS2);
        vm.stopPrank();

        address[] memory batch = _three(); // ADDRESS3 was never listed
        vm.expectEmit(true, true, true, true);
        emit IAddressList.RemoveAddresses(batch, 2, 1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.removeAddresses(batch);

        assertEq(rule.listedAddressCount(), 0);
    }

    /**
     * @notice The counters must always account for the whole input.
     */
    function testFuzz_CountersSumToTheInputLength(uint8 preloaded) public {
        vm.assume(preloaded <= 3);
        address[] memory batch = _three();

        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        for (uint256 i = 0; i < preloaded; ++i) {
            rule.addAddress(batch[i]);
        }
        vm.recordLogs();
        rule.addAddresses(batch);
        vm.stopPrank();

        Vm.Log[] memory logs = vm.getRecordedLogs();
        (, uint256 added, uint256 skipped) = abi.decode(logs[logs.length - 1].data, (address[], uint256, uint256));
        assertEq(added + skipped, batch.length, "added + skipped must cover the input");
        assertEq(skipped, preloaded, "skipped must equal what was already present");
    }

    /*//////////////////////////////////////////////////////////////
              RuleERC2980 — its own copy of the same loops
    //////////////////////////////////////////////////////////////*/

    function testWhitelistBatchReportsAPartialBatch() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        erc2980.addWhitelistAddress(ADDRESS1);

        address[] memory batch = _three();
        vm.expectEmit(true, true, true, true);
        emit RuleERC2980InvariantStorage.AddWhitelistAddresses(batch, 2, 1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        erc2980.addWhitelistAddresses(batch);
    }

    function testFrozenlistBatchReportsAPartialBatch() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        erc2980.addFrozenlistAddress(ADDRESS3);

        address[] memory batch = _three();
        vm.expectEmit(true, true, true, true);
        emit RuleERC2980InvariantStorage.AddFrozenlistAddresses(batch, 2, 1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        erc2980.addFrozenlistAddresses(batch);
    }

    function testFrozenlistRemoveReportsAPartialBatch() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        erc2980.addFrozenlistAddress(ADDRESS1);

        address[] memory batch = _three();
        vm.expectEmit(true, true, true, true);
        emit RuleERC2980InvariantStorage.RemoveFrozenlistAddresses(batch, 1, 2);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        erc2980.removeFrozenlistAddresses(batch);
    }

    function testWhitelistRemoveReportsAPartialBatch() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        erc2980.addWhitelistAddress(ADDRESS1);
        erc2980.addWhitelistAddress(ADDRESS2);
        vm.stopPrank();

        address[] memory batch = _three();
        vm.expectEmit(true, true, true, true);
        emit RuleERC2980InvariantStorage.RemoveWhitelistAddresses(batch, 2, 1);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        erc2980.removeWhitelistAddresses(batch);
    }
}
