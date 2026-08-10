// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {HelperContract} from "../HelperContract.sol";
import {AggregatorV3Mock} from "src/mocks/AggregatorV3Mock.sol";
import {AggregatorV3Interface} from "src/rules/interfaces/AggregatorV3Interface.sol";
import {RuleChainlinkPoR} from "src/rules/validation/deployment/RuleChainlinkPoR.sol";
import {TotalSupplyDecimalsMock} from "src/mocks/TotalSupplyDecimalsMock.sol";

/**
 * @title Decimal-scaling tests for RuleChainlinkPoR
 * @notice `tokenDecimals` is used in exactly two places: the bound check in `_setTokenMetadata`
 *         and `_scaleReserve`. These tests pin the scaling behaviour across the realistic
 *         combinations of token decimals (0 for CMTAT equity, 6 for USDC-style, 18 for ERC-20
 *         default) and feed decimals (8 and 18 are what Chainlink actually publishes), including
 *         the degenerate ends of the accepted ranges.
 *
 *         The `tokenDecimals == 0` case matters because CMTAT equity tokens report 0 decimals,
 *         which Chainlink's own `SecureMintPolicy` rejects. It is the case where `_scaleReserve`
 *         divides by the largest possible factor, so it is where truncation bites hardest.
 */
contract RuleChainlinkPoRDecimals is Test, HelperContract {
    uint256 constant ONE_DAY = 1 days;

    function setUp() public {
        vm.warp(1_000_000);
    }

    /**
     * @notice Deploys a rule over a token with `tokenDecimals` and a feed with `feedDecimals`
     *         reporting `answer`.
     */
    function _deploy(uint8 tokenDecimals, uint8 feedDecimals, int256 answer)
        private
        returns (RuleChainlinkPoR rule, TotalSupplyDecimalsMock token)
    {
        token = new TotalSupplyDecimalsMock(tokenDecimals);
        AggregatorV3Mock feed = new AggregatorV3Mock(feedDecimals, answer);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleChainlinkPoR(
            DEFAULT_ADMIN_ADDRESS, address(token), tokenDecimals, AggregatorV3Interface(address(feed)), ONE_DAY
        );
    }

    /**
     * @notice Asserts the backed supply for a given decimals pairing, and that the rule enforces
     *         exactly that boundary on the mint path.
     */
    function _assertBackedSupply(uint8 tokenDecimals, uint8 feedDecimals, int256 answer, uint256 expected) private {
        (RuleChainlinkPoR rule, TotalSupplyDecimalsMock token) = _deploy(tokenDecimals, feedDecimals, answer);

        (uint8 code, uint256 backedSupply) = rule.maxBackedSupply();
        assertEq(code, TRANSFER_OK, "feed answer should be usable");
        assertEq(backedSupply, expected, "backed supply mismatch");

        // The boundary is enforced, not merely reported.
        token.setTotalSupply(0);
        assertEq(
            rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, expected), TRANSFER_OK, "limit must be mintable"
        );
        assertEq(
            rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, expected + 1),
            CODE_RESERVES_EXCEEDED,
            "one over the limit must be rejected"
        );
    }

    /*//////////////////////////////////////////////////////////////
              1_000 WHOLE UNITS ACROSS TOKEN / FEED DECIMALS
    //////////////////////////////////////////////////////////////*/

    function testScaling_Token18_Feed8() public {
        _assertBackedSupply(18, 8, 1000 * 1e8, 1000 * 1e18);
    }

    function testScaling_Token6_Feed8() public {
        _assertBackedSupply(6, 8, 1000 * 1e8, 1000 * 1e6);
    }

    function testScaling_Token0_Feed8() public {
        _assertBackedSupply(0, 8, 1000 * 1e8, 1000);
    }

    function testScaling_Token18_Feed18() public {
        _assertBackedSupply(18, 18, 1000 * 1e18, 1000 * 1e18);
    }

    function testScaling_Token6_Feed18() public {
        _assertBackedSupply(6, 18, int256(1000 * 1e18), 1000 * 1e6);
    }

    function testScaling_Token0_Feed18() public {
        _assertBackedSupply(0, 18, int256(1000 * 1e18), 1000);
    }

    /*//////////////////////////////////////////////////////////////
                        DEGENERATE DECIMAL ENDS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Both sides at 0 decimals: whole units on the feed, whole tokens on the token.
     *         `_scaleReserve` takes the `to == from` short circuit and passes the answer through.
     */
    function testScaling_Token0_Feed0_IsIdentity() public {
        _assertBackedSupply(0, 0, 1000, 1000);
    }

    /**
     * @notice A 0-decimals feed with an 18-decimals token exercises the scale-up branch, which is
     *         unreachable when the token has 0 decimals.
     */
    function testScaling_Token18_Feed0_ScalesUp() public {
        _assertBackedSupply(18, 0, 1000, 1000 * 1e18);
    }

    /**
     * @notice The widest accepted spread: a 36-decimals feed against a 0-decimals token divides by
     *         10 ** 36. This is the largest divisor the rule can ever build and it must not revert.
     */
    function testScaling_Token0_FeedMax_DoesNotRevert() public {
        uint8 maxFeedDecimals = 36;
        _assertBackedSupply(0, maxFeedDecimals, int256(1000 * (10 ** 36)), 1000);
    }

    /*//////////////////////////////////////////////////////////////
                    TRUNCATION IS CONSERVATIVE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Scaling down truncates, and truncation always rounds the backed supply DOWN. That is
     *         the safe direction for a reserve rule: it can under-mint, never over-mint.
     */
    function testTruncation_Token0_DropsTheFractionalReserve() public {
        // 1000.99999999 units reported with 8 decimals backs only 1000 whole tokens.
        _assertBackedSupply(0, 8, 1000 * 1e8 + 99_999_999, 1000);
    }

    function testTruncation_Token6_DropsSubUnitDigits() public {
        // 1000.00000001 with 8 feed decimals: the two digits below 1e-6 are dropped.
        _assertBackedSupply(6, 8, 1000 * 1e8 + 1, 1000 * 1e6);
    }

    /**
     * @notice With 0-decimals tokens, reserves below one whole unit back nothing at all, so every
     *         non-zero mint is rejected. A zero-value mint still passes: it is trivially backed.
     */
    function testTruncation_Token0_SubUnitReservesBackNothing() public {
        (RuleChainlinkPoR rule, TotalSupplyDecimalsMock token) = _deploy(0, 8, 99_999_999); // 0.99999999

        (uint8 code, uint256 backedSupply) = rule.maxBackedSupply();
        assertEq(code, TRANSFER_OK);
        assertEq(backedSupply, 0);

        token.setTotalSupply(0);
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1), CODE_RESERVES_EXCEEDED);
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 0), TRANSFER_OK);
    }

    /*//////////////////////////////////////////////////////////////
                  ENFORCEMENT AGAINST A NON-ZERO SUPPLY
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice The headroom calculation is decimals-agnostic: whatever the scaling, a mint is
     *         allowed exactly up to `backedSupply - totalSupply`.
     */
    function testHeadroomIsCorrectAtEveryTokenDecimals() public {
        uint8[3] memory tokenDecimalsCases = [uint8(0), 6, 18];

        for (uint256 i = 0; i < tokenDecimalsCases.length; i++) {
            uint8 tokenDecimals = tokenDecimalsCases[i];
            (RuleChainlinkPoR rule, TotalSupplyDecimalsMock token) = _deploy(tokenDecimals, 8, 1000 * 1e8);

            uint256 unit = 10 ** uint256(tokenDecimals);
            uint256 backed = 1000 * unit;
            uint256 supply = 400 * unit;
            token.setTotalSupply(supply);

            uint256 headroom = backed - supply;
            assertEq(
                rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, headroom),
                TRANSFER_OK,
                "exact headroom must be mintable"
            );
            assertEq(
                rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, headroom + 1),
                CODE_RESERVES_EXCEEDED,
                "one over the headroom must be rejected"
            );
        }
    }

    /**
     * @notice A supply already above the backed amount rejects even a 1-unit mint, at any decimals.
     */
    function testSupplyAboveReservesRejectsAtEveryTokenDecimals() public {
        uint8[3] memory tokenDecimalsCases = [uint8(0), 6, 18];

        for (uint256 i = 0; i < tokenDecimalsCases.length; i++) {
            uint8 tokenDecimals = tokenDecimalsCases[i];
            (RuleChainlinkPoR rule, TotalSupplyDecimalsMock token) = _deploy(tokenDecimals, 8, 1000 * 1e8);

            token.setTotalSupply(1000 * (10 ** uint256(tokenDecimals)) + 1);
            assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1), CODE_RESERVES_EXCEEDED);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                FUZZ
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Cross-checks the branchy `_scaleReserve` against its mathematical definition,
     *         `answer * 10**tokenDecimals / 10**feedDecimals`, computed with `Math.mulDiv` so the
     *         reference carries the full intermediate product. `answer` is bounded away from the
     *         saturation regime, which `testScaling_SaturatesInsteadOfOverflowing` covers separately.
     */
    function testFuzz_ScalingMatchesTheMathematicalDefinition(uint8 tokenDecimals, uint8 feedDecimals, uint256 answer)
        public
    {
        tokenDecimals = uint8(bound(tokenDecimals, 0, 18));
        feedDecimals = uint8(bound(feedDecimals, 0, 36));
        answer = bound(answer, 0, 1e30);

        // `answer` is bounded to 1e30 above, far inside int256.
        // forge-lint: disable-next-line(unsafe-typecast)
        (RuleChainlinkPoR rule,) = _deploy(tokenDecimals, feedDecimals, int256(answer));

        (uint8 code, uint256 backedSupply) = rule.maxBackedSupply();
        assertEq(code, TRANSFER_OK);
        assertEq(backedSupply, Math.mulDiv(answer, 10 ** uint256(tokenDecimals), 10 ** uint256(feedDecimals)));
    }

    /**
     * @notice Whatever the decimals pairing, the read path returns a code and never reverts — the
     *         ERC-1404 / ERC-3643 MUST-NOT-revert contract holds across the whole decimals domain.
     */
    function testFuzz_ReadPathNeverRevertsAtAnyDecimals(
        uint8 tokenDecimals,
        uint8 feedDecimals,
        int256 answer,
        uint256 currentSupply,
        uint256 value
    ) public {
        tokenDecimals = uint8(bound(tokenDecimals, 0, 18));
        feedDecimals = uint8(bound(feedDecimals, 0, 36));

        (RuleChainlinkPoR rule, TotalSupplyDecimalsMock token) = _deploy(tokenDecimals, feedDecimals, answer);
        token.setTotalSupply(currentSupply);

        uint8 restrictionCode = rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, value);

        if (answer < 0) {
            assertEq(restrictionCode, CODE_RESERVES_ANSWER_INVALID);
            return;
        }
        (, uint256 backedSupply) = rule.maxBackedSupply();
        bool exceeds = currentSupply > backedSupply || value > backedSupply - currentSupply;
        assertEq(restrictionCode, exceeds ? CODE_RESERVES_EXCEEDED : TRANSFER_OK);
    }
}
