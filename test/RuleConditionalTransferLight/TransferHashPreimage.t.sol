// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {RuleConditionalTransferLight} from "src/rules/operation/RuleConditionalTransferLight.sol";
import {RuleConditionalTransferLightMultiToken} from "src/rules/operation/RuleConditionalTransferLightMultiToken.sol";

/**
 * @title TransferHashPreimage
 * @notice Pins the approval-key preimage documented on `_transferHash` (`CLAUDE_ANALYSIS.md` F-4).
 * @dev The key is a project-specific encoding — 32-byte words with each address LEFT-aligned and
 *      right-padded — which is neither `abi.encodePacked` nor `abi.encode`. Anyone deriving the
 *      storage slot off-chain (`eth_getStorageAt`, a state proof, an indexer reading storage rather
 *      than events) needs that layout, and getting it wrong fails *silently*: a wrong key reads `0`,
 *      which is indistinguishable from "no approval exists".
 *
 *      These tests go through the contract's own public `approvalCounts(bytes32)` getter, so they
 *      verify the documented formulations against the real storage key rather than against a
 *      reimplementation of the assembly. If the encoding is ever changed, the NatSpec that tells
 *      integrators how to reproduce it becomes wrong — and this fails.
 */
contract TransferHashPreimage is Test, HelperContract {
    address private constant FROM = address(0xA11CE);
    address private constant TO = address(0xB0B);
    address private constant TOKEN = address(0x7043);
    uint256 private constant VALUE = 12_345;

    RuleConditionalTransferLight private rule;
    RuleConditionalTransferLightMultiToken private multi;

    function setUp() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);
        rule.bindToken(ADDRESS3);
        rule.approveTransfer(FROM, TO, VALUE);

        multi = new RuleConditionalTransferLightMultiToken(DEFAULT_ADMIN_ADDRESS);
        multi.bindToken(TOKEN);
        multi.approveTransfer(TOKEN, FROM, TO, VALUE);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        Single-token rule
    //////////////////////////////////////////////////////////////*/

    function testDocumentedPreimageMatchesTheStorageKey() public view {
        assertEq(rule.approvedCount(FROM, TO, VALUE), 1, "premise: one approval recorded");

        // Formulation (1) from the NatSpec: explicit padding.
        bytes32 padded = keccak256(abi.encodePacked(FROM, bytes12(0), TO, bytes12(0), VALUE));
        assertEq(rule.approvalCounts(padded), 1, "documented encodePacked form must hit the key");

        // Formulation (2): left-aligned words. Must be the identical preimage.
        bytes32 words = keccak256(abi.encode(bytes32(bytes20(FROM)), bytes32(bytes20(TO)), VALUE));
        assertEq(words, padded, "the two documented formulations must agree");
        assertEq(rule.approvalCounts(words), 1, "documented abi.encode form must hit the key");
    }

    function testTheTwoStandardEncodingsDoNotMatch() public view {
        // The point of the NatSpec warning: both of these look right and are wrong.
        assertEq(
            rule.approvalCounts(keccak256(abi.encodePacked(FROM, TO, VALUE))),
            0,
            "abi.encodePacked(from,to,value) must NOT be the key"
        );
        assertEq(
            rule.approvalCounts(keccak256(abi.encode(FROM, TO, VALUE))),
            0,
            "abi.encode(from,to,value) must NOT be the key"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        Multi-token rule
    //////////////////////////////////////////////////////////////*/

    function testMultiTokenDocumentedPreimageMatchesTheStorageKey() public view {
        assertEq(multi.approvedCount(TOKEN, FROM, TO, VALUE), 1, "premise: one approval recorded");

        bytes32 padded = keccak256(abi.encodePacked(TOKEN, bytes12(0), FROM, bytes12(0), TO, bytes12(0), VALUE));
        assertEq(multi.approvalCounts(padded), 1, "documented form must hit the key");

        bytes32 words =
            keccak256(abi.encode(bytes32(bytes20(TOKEN)), bytes32(bytes20(FROM)), bytes32(bytes20(TO)), VALUE));
        assertEq(words, padded, "the two documented formulations must agree");
        assertEq(multi.approvalCounts(words), 1, "documented form must hit the key");
    }

    function testMultiTokenIsKeyedOnTheTokenToo() public view {
        // Same (from, to, value) under a different token must be a different key.
        bytes32 otherToken =
            keccak256(abi.encodePacked(address(0xDEAD), bytes12(0), FROM, bytes12(0), TO, bytes12(0), VALUE));
        assertEq(multi.approvalCounts(otherToken), 0);
    }
}
