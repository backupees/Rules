// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {AggregatorV3Mock} from "src/mocks/AggregatorV3Mock.sol";
import {AggregatorV3Interface} from "src/rules/interfaces/AggregatorV3Interface.sol";
import {RuleChainlinkPoR} from "src/rules/validation/deployment/RuleChainlinkPoR.sol";
import {TotalSupplyDecimalsMock} from "src/mocks/TotalSupplyDecimalsMock.sol";
import {TotalSupplyMock} from "src/mocks/TotalSupplyMock.sol";

/**
 * @title Unit tests for RuleChainlinkPoR
 */
contract RuleChainlinkPoRUnit is Test, HelperContract {
    uint8 constant TOKEN_DECIMALS = 18;
    uint8 constant FEED_DECIMALS = 8;
    // 1_000 reserve units reported with 8 decimals.
    int256 constant RESERVE_1000 = 1000 * 1e8;
    // The same 1_000 units expressed with the token's 18 decimals.
    uint256 constant RESERVE_1000_SCALED = 1000 * 1e18;
    uint256 constant ONE_DAY = 1 days;

    TotalSupplyDecimalsMock private token;
    AggregatorV3Mock private feed;
    RuleChainlinkPoR private rule;

    function setUp() public {
        // Move away from block.timestamp == 1 so staleness arithmetic is meaningful.
        vm.warp(1_000_000);
        token = new TotalSupplyDecimalsMock(TOKEN_DECIMALS);
        feed = new AggregatorV3Mock(FEED_DECIMALS, RESERVE_1000);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule = new RuleChainlinkPoR(
            DEFAULT_ADMIN_ADDRESS, address(token), TOKEN_DECIMALS, AggregatorV3Interface(address(feed)), ONE_DAY
        );
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function testConstructor_StoresConfiguration() public view {
        assertEq(address(rule.reservesFeed()), address(feed));
        assertEq(address(rule.tokenContract()), address(token));
        assertEq(rule.feedDecimals(), FEED_DECIMALS);
        assertEq(rule.tokenDecimals(), TOKEN_DECIMALS);
        assertEq(rule.maxStalenessSeconds(), ONE_DAY);
    }

    function testConstructor_RevertsOnZeroFeed() public {
        vm.expectRevert(RuleChainlinkPoR_FeedAddressZeroNotAllowed.selector);
        new RuleChainlinkPoR(
            DEFAULT_ADMIN_ADDRESS, address(token), TOKEN_DECIMALS, AggregatorV3Interface(ZERO_ADDRESS), ONE_DAY
        );
    }

    function testConstructor_RevertsOnNonContractFeed() public {
        vm.expectRevert(abi.encodeWithSelector(RuleChainlinkPoR_FeedIsNotAContract.selector, ADDRESS1));
        new RuleChainlinkPoR(
            DEFAULT_ADMIN_ADDRESS, address(token), TOKEN_DECIMALS, AggregatorV3Interface(ADDRESS1), ONE_DAY
        );
    }

    function testConstructor_RevertsOnZeroToken() public {
        vm.expectRevert(RuleChainlinkPoR_TokenAddressZeroNotAllowed.selector);
        new RuleChainlinkPoR(
            DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, TOKEN_DECIMALS, AggregatorV3Interface(address(feed)), ONE_DAY
        );
    }

    /*//////////////////////////////////////////////////////////////
                        FEED CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    function testSetReservesFeed_UpdatesFeedAndDecimals() public {
        // RESERVE_1000_SCALED is the constant 1000 * 1e18, far inside int256.
        // forge-lint: disable-next-line(unsafe-typecast)
        AggregatorV3Mock newFeed = new AggregatorV3Mock(18, int256(RESERVE_1000_SCALED));

        vm.expectEmit(true, false, false, true);
        emit ReservesFeedUpdated(address(newFeed), 18);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setReservesFeed(AggregatorV3Interface(address(newFeed)));

        assertEq(address(rule.reservesFeed()), address(newFeed));
        assertEq(rule.feedDecimals(), 18);
    }

    function testSetReservesFeed_RevertsWhenDecimalsUnavailable() public {
        AggregatorV3Mock brokenFeed = new AggregatorV3Mock(FEED_DECIMALS, RESERVE_1000);
        brokenFeed.setRevertOnDecimals(true);

        vm.expectRevert(abi.encodeWithSelector(RuleChainlinkPoR_FeedDecimalsUnavailable.selector, address(brokenFeed)));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setReservesFeed(AggregatorV3Interface(address(brokenFeed)));
    }

    function testSetReservesFeed_RevertsWhenDecimalsTooLarge() public {
        uint8 tooManyDecimals = rule.MAX_FEED_DECIMALS() + 1;
        AggregatorV3Mock wideFeed = new AggregatorV3Mock(tooManyDecimals, RESERVE_1000);

        vm.expectRevert(abi.encodeWithSelector(RuleChainlinkPoR_FeedDecimalsTooLarge.selector, tooManyDecimals));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setReservesFeed(AggregatorV3Interface(address(wideFeed)));
    }

    function testSetReservesFeed_OnlyAdmin() public {
        vm.expectRevert();
        vm.prank(ATTACKER);
        rule.setReservesFeed(AggregatorV3Interface(address(feed)));
    }

    /*//////////////////////////////////////////////////////////////
                        TOKEN CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    function testSetTokenMetadata_UpdatesTokenAndDecimals() public {
        TotalSupplyDecimalsMock newToken = new TotalSupplyDecimalsMock(6);

        vm.expectEmit(true, false, false, true);
        emit TokenMetadataUpdated(address(newToken), 6);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setTokenMetadata(address(newToken), 6);

        assertEq(address(rule.tokenContract()), address(newToken));
        assertEq(rule.tokenDecimals(), 6);
    }

    function testSetTokenMetadata_AcceptsTokenWithoutDecimals() public {
        TotalSupplyMock plainToken = new TotalSupplyMock();

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setTokenMetadata(address(plainToken), 6);

        assertEq(address(rule.tokenContract()), address(plainToken));
        assertEq(rule.tokenDecimals(), 6);
    }

    function testSetTokenMetadata_RevertsOnDecimalsMismatch() public {
        vm.expectRevert(abi.encodeWithSelector(RuleChainlinkPoR_TokenDecimalsMismatch.selector, 6, TOKEN_DECIMALS));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setTokenMetadata(address(token), 6);
    }

    /**
     * @notice A 0-decimals token is valid: CMTAT equity tokens commonly report 0 decimals.
     */
    function testSetTokenMetadata_AcceptsZeroDecimals() public {
        TotalSupplyDecimalsMock shareToken = new TotalSupplyDecimalsMock(0);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setTokenMetadata(address(shareToken), 0);
        assertEq(rule.tokenDecimals(), 0);

        // 1000 reserve units with 8 feed decimals scale down to 1000 whole tokens.
        shareToken.setTotalSupply(0);
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1000), TRANSFER_OK);
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1001), CODE_RESERVES_EXCEEDED);
    }

    function testSetTokenMetadata_RevertsAboveMaxDecimals() public {
        uint8 tooManyDecimals = rule.MAX_TOKEN_DECIMALS() + 1;
        vm.expectRevert(abi.encodeWithSelector(RuleChainlinkPoR_InvalidTokenDecimals.selector, tooManyDecimals));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setTokenMetadata(address(token), tooManyDecimals);
    }

    function testSetTokenMetadata_RevertsOnZeroToken() public {
        vm.expectRevert(RuleChainlinkPoR_TokenAddressZeroNotAllowed.selector);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setTokenMetadata(ZERO_ADDRESS, TOKEN_DECIMALS);
    }

    function testSetTokenMetadata_OnlyAdmin() public {
        vm.expectRevert();
        vm.prank(ATTACKER);
        rule.setTokenMetadata(address(token), TOKEN_DECIMALS);
    }

    /*//////////////////////////////////////////////////////////////
                      STALENESS CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    function testSetMaxStalenessSeconds_UpdatesThreshold() public {
        vm.expectEmit(false, false, false, true);
        emit MaxStalenessSecondsUpdated(3600);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMaxStalenessSeconds(3600);

        assertEq(rule.maxStalenessSeconds(), 3600);
    }

    function testSetMaxStalenessSeconds_OnlyAdmin() public {
        vm.expectRevert();
        vm.prank(ATTACKER);
        rule.setMaxStalenessSeconds(3600);
    }

    /*//////////////////////////////////////////////////////////////
                        RESERVE ENFORCEMENT
    //////////////////////////////////////////////////////////////*/

    function testDetectRestriction_MintWithinReserves() public {
        token.setTotalSupply(900 * 1e18);
        resUint8 = rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 100 * 1e18);
        assertEq(resUint8, TRANSFER_OK);
    }

    function testDetectRestriction_MintExceedingReserves() public {
        token.setTotalSupply(900 * 1e18);
        resUint8 = rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 100 * 1e18 + 1);
        assertEq(resUint8, CODE_RESERVES_EXCEEDED);
    }

    function testDetectRestriction_MintWhenSupplyAlreadyAboveReserves() public {
        token.setTotalSupply(RESERVE_1000_SCALED + 1);
        resUint8 = rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1);
        assertEq(resUint8, CODE_RESERVES_EXCEEDED);
    }

    function testDetectRestriction_TransferIsNeverGated() public {
        token.setTotalSupply(RESERVE_1000_SCALED * 10);
        resUint8 = rule.detectTransferRestriction(ADDRESS1, ADDRESS2, type(uint256).max);
        assertEq(resUint8, TRANSFER_OK);
    }

    function testDetectRestriction_BurnIsNeverGated() public {
        token.setTotalSupply(RESERVE_1000_SCALED * 10);
        resUint8 = rule.detectTransferRestriction(ADDRESS1, ZERO_ADDRESS, 5);
        assertEq(resUint8, TRANSFER_OK);
    }

    function testDetectRestrictionFrom_UsesTheSameLogicAndIgnoresSpender() public {
        token.setTotalSupply(900 * 1e18);
        assertEq(rule.detectTransferRestrictionFrom(ADDRESS3, ZERO_ADDRESS, ADDRESS1, 100 * 1e18), TRANSFER_OK);
        assertEq(
            rule.detectTransferRestrictionFrom(ADDRESS3, ZERO_ADDRESS, ADDRESS1, 100 * 1e18 + 1), CODE_RESERVES_EXCEEDED
        );
    }

    function testCanTransferAndCanTransferFrom() public {
        token.setTotalSupply(900 * 1e18);
        assertTrue(rule.canTransfer(ZERO_ADDRESS, ADDRESS1, 100 * 1e18));
        assertFalse(rule.canTransfer(ZERO_ADDRESS, ADDRESS1, 100 * 1e18 + 1));
        assertTrue(rule.canTransferFrom(ADDRESS3, ZERO_ADDRESS, ADDRESS1, 100 * 1e18));
        assertFalse(rule.canTransferFrom(ADDRESS3, ZERO_ADDRESS, ADDRESS1, 100 * 1e18 + 1));
    }

    /*//////////////////////////////////////////////////////////////
                        FEED FAILURE MODES
    //////////////////////////////////////////////////////////////*/

    function testDetectRestriction_StaleFeedBlocksMint() public {
        vm.warp(block.timestamp + ONE_DAY + 1);
        token.setTotalSupply(0);
        resUint8 = rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1);
        assertEq(resUint8, CODE_RESERVES_FEED_STALE);
    }

    function testDetectRestriction_FeedExactlyAtThresholdIsAccepted() public {
        vm.warp(block.timestamp + ONE_DAY);
        token.setTotalSupply(0);
        resUint8 = rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1);
        assertEq(resUint8, TRANSFER_OK);
    }

    function testDetectRestriction_StalenessCheckDisabledWithZeroThreshold() public {
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setMaxStalenessSeconds(0);

        vm.warp(block.timestamp + 3650 days);
        token.setTotalSupply(0);
        resUint8 = rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1);
        assertEq(resUint8, TRANSFER_OK);
    }

    function testDetectRestriction_NegativeAnswerBlocksMint() public {
        feed.setAnswer(-1);
        token.setTotalSupply(0);
        resUint8 = rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1);
        assertEq(resUint8, CODE_RESERVES_ANSWER_INVALID);
    }

    function testDetectRestriction_IncompleteRoundBlocksMint() public {
        feed.setUpdatedAt(0);
        token.setTotalSupply(0);
        resUint8 = rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1);
        assertEq(resUint8, CODE_RESERVES_ANSWER_INVALID);
    }

    function testDetectRestriction_RevertingFeedBlocksMintWithoutReverting() public {
        feed.setRevertOnLatestRoundData(true);
        token.setTotalSupply(0);
        resUint8 = rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1);
        assertEq(resUint8, CODE_RESERVES_ANSWER_INVALID);
    }

    function testDetectRestriction_FeedWithoutCodeBlocksMintWithoutReverting() public {
        // The feed had code when it was configured, and lost it afterwards.
        vm.etch(address(feed), "");
        token.setTotalSupply(0);
        resUint8 = rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1);
        assertEq(resUint8, CODE_RESERVES_ANSWER_INVALID);
    }

    function testDetectRestriction_ZeroReserveBlocksAnyMint() public {
        feed.setAnswer(0);
        token.setTotalSupply(0);
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 1), CODE_RESERVES_EXCEEDED);
        // A zero-value mint is still backed.
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, 0), TRANSFER_OK);
    }

    /*//////////////////////////////////////////////////////////////
                            DECIMAL SCALING
    //////////////////////////////////////////////////////////////*/

    function testScaling_FeedDecimalsEqualTokenDecimals() public {
        // RESERVE_1000_SCALED is the constant 1000 * 1e18, far inside int256.
        // forge-lint: disable-next-line(unsafe-typecast)
        AggregatorV3Mock sameDecimalsFeed = new AggregatorV3Mock(TOKEN_DECIMALS, int256(RESERVE_1000_SCALED));
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setReservesFeed(AggregatorV3Interface(address(sameDecimalsFeed)));

        (uint8 code, uint256 backedSupply) = rule.maxBackedSupply();
        assertEq(code, TRANSFER_OK);
        assertEq(backedSupply, RESERVE_1000_SCALED);
    }

    function testScaling_FeedDecimalsAboveTokenDecimalsTruncates() public {
        // Token with 6 decimals, feed with 8: the two least significant digits are dropped.
        TotalSupplyDecimalsMock smallToken = new TotalSupplyDecimalsMock(6);
        vm.prank(DEFAULT_ADMIN_ADDRESS);
        rule.setTokenMetadata(address(smallToken), 6);

        // 1000.00000001 units reported with 8 decimals.
        feed.setAnswer(RESERVE_1000 + 1);

        (uint8 code, uint256 backedSupply) = rule.maxBackedSupply();
        assertEq(code, TRANSFER_OK);
        assertEq(backedSupply, 1000 * 1e6);
    }

    function testScaling_SaturatesInsteadOfOverflowing() public {
        feed.setAnswer(type(int256).max);

        (uint8 code, uint256 backedSupply) = rule.maxBackedSupply();
        assertEq(code, TRANSFER_OK);
        assertEq(backedSupply, type(uint256).max);

        token.setTotalSupply(0);
        assertEq(rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, type(uint256).max), TRANSFER_OK);
    }

    function testMaxBackedSupply_ReportsFeedFailure() public {
        feed.setRevertOnLatestRoundData(true);
        (uint8 code, uint256 backedSupply) = rule.maxBackedSupply();
        assertEq(code, CODE_RESERVES_ANSWER_INVALID);
        assertEq(backedSupply, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            WRITE PATH
    //////////////////////////////////////////////////////////////*/

    function testTransferred_RevertsWhenMintNotBacked() public {
        token.setTotalSupply(RESERVE_1000_SCALED);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleChainlinkPoR_InvalidTransfer.selector,
                address(rule),
                ZERO_ADDRESS,
                ADDRESS1,
                1,
                CODE_RESERVES_EXCEEDED
            )
        );
        rule.transferred(ZERO_ADDRESS, ADDRESS1, 1);
    }

    function testTransferredFrom_RevertsWhenMintNotBacked() public {
        token.setTotalSupply(RESERVE_1000_SCALED);
        vm.expectRevert(
            abi.encodeWithSelector(
                RuleChainlinkPoR_InvalidTransferFrom.selector,
                address(rule),
                ADDRESS3,
                ZERO_ADDRESS,
                ADDRESS1,
                1,
                CODE_RESERVES_EXCEEDED
            )
        );
        rule.transferred(ADDRESS3, ZERO_ADDRESS, ADDRESS1, 1);
    }

    function testTransferred_DoesNotRevertWhenBacked() public {
        token.setTotalSupply(900 * 1e18);
        rule.transferred(ZERO_ADDRESS, ADDRESS1, 100 * 1e18);
        rule.transferred(ADDRESS3, ZERO_ADDRESS, ADDRESS1, 100 * 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                        ERC-1404 SURFACE
    //////////////////////////////////////////////////////////////*/

    function testCanReturnTransferRestrictionCode() public view {
        assertTrue(rule.canReturnTransferRestrictionCode(CODE_RESERVES_EXCEEDED));
        assertTrue(rule.canReturnTransferRestrictionCode(CODE_RESERVES_FEED_STALE));
        assertTrue(rule.canReturnTransferRestrictionCode(CODE_RESERVES_ANSWER_INVALID));
        assertFalse(rule.canReturnTransferRestrictionCode(CODE_NONEXISTENT));
    }

    function testMessageForTransferRestriction() public view {
        assertEq(rule.messageForTransferRestriction(CODE_RESERVES_EXCEEDED), TEXT_RESERVES_EXCEEDED);
        assertEq(rule.messageForTransferRestriction(CODE_RESERVES_FEED_STALE), TEXT_RESERVES_FEED_STALE);
        assertEq(rule.messageForTransferRestriction(CODE_RESERVES_ANSWER_INVALID), TEXT_RESERVES_ANSWER_INVALID);
        assertEq(rule.messageForTransferRestriction(CODE_NONEXISTENT), TEXT_CODE_NOT_FOUND);
    }

    /**
     * @notice The mock honours the whole `AggregatorV3Interface` surface, so a rule reading any of
     * it sees Chainlink-shaped data.
     */
    function testFeedMockExposesTheFullAggregatorSurface() public {
        assertEq(feed.description(), "AggregatorV3Mock");
        assertEq(feed.version(), 3);

        feed.setDecimals(18);
        assertEq(feed.decimals(), 18);

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt,) = feed.getRoundData(7);
        assertEq(roundId, 7);
        assertEq(answer, RESERVE_1000);
        assertEq(startedAt, updatedAt);
    }

    /*//////////////////////////////////////////////////////////////
                                FUZZ
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Full-domain fuzz over supply and mint amount: the view must always return a code and
     * never revert, including where `currentSupply + value` would overflow.
     */
    function testFuzz_MintBoundsNeverRevert(uint256 currentSupply, uint256 value, int256 answer) public {
        feed.setAnswer(answer);
        token.setTotalSupply(currentSupply);

        resUint8 = rule.detectTransferRestriction(ZERO_ADDRESS, ADDRESS1, value);

        if (answer < 0) {
            assertEq(resUint8, CODE_RESERVES_ANSWER_INVALID);
            return;
        }
        (uint8 code, uint256 backedSupply) = rule.maxBackedSupply();
        assertEq(code, TRANSFER_OK);
        bool exceeds = currentSupply > backedSupply || value > backedSupply - currentSupply;
        assertEq(resUint8, exceeds ? CODE_RESERVES_EXCEEDED : TRANSFER_OK);
    }
}
