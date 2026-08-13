// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {ITotalSupply} from "../../../interfaces/ITotalSupply.sol";

/**
 * @title TokenSupplyReader
 * @notice Shared mechanics for the rules that cap minting against a supply figure read from a token
 * they do not control: {RuleMaxTotalSupplyBase} and {RuleChainlinkPoRBase}.
 * @dev The two rules answer different questions -- a static ceiling versus a Chainlink Proof of
 * Reserve figure -- but they share one concern exactly: *read `totalSupply()` from a foreign contract
 * on a path that MUST NOT revert*. That concern was implemented twice, byte for byte, along with the
 * reasoning behind it (`CLAUDE_ANALYSIS.md` D-2).
 *
 * ## Why the token is a hook rather than state here
 * This contract declares **no storage**. Each rule keeps its own `tokenContract` variable and
 * implements {_supplyToken}. Declaring the variable here instead would work, but it would reorder
 * every inheriting rule's storage slots for no benefit -- `RuleChainlinkPoR` would see
 * `tokenContract` move ahead of `reservesFeed`. A stateless base is free of that risk.
 *
 * ## Why validation is NOT shared
 * Both rules validate a candidate token the same way -- non-zero, has code, `totalSupply()` callable
 * -- but each reverts with its own named error (`RuleMaxTotalSupply_TokenIsNotAContract` vs
 * `RuleChainlinkPoR_TokenIsNotAContract`, and so on), per the codebase's one-error-namespace-per-rule
 * convention. Only the non-trivial part, the `try/catch` probe, is shared here as
 * {_probeTotalSupplyCallable}; each rule composes it with its own `require`s so the three distinct
 * configuration failures keep three distinct, named errors. Collapsing them into a single boolean
 * would trade a real diagnostic for a couple of saved lines.
 *
 * ## Deployment precondition (both rules)
 * {_currentSupply} is `try/catch`-wrapped but performs **no code-length check**: a `try` call to a
 * codeless address reverts *uncatchably*, so the guard would be useless there anyway. (The mechanism is the
 * ABI decoder, not `EXTCODESIZE` — solc >= 0.8.10 skips the existence check when return data is expected, the
 * CALL to a codeless account succeeds with 0 bytes, and decoding fails in THIS frame after the call returned,
 * where `catch` cannot reach it.) Safety comes
 * from configuration instead -- each rule's setter rejects a candidate without code, and EIP-6780
 * (Cancun) makes that permanent, since `SELFDESTRUCT` can only clear an account created in the same
 * transaction. **This reasoning assumes a Cancun-or-later chain**, which `foundry.toml` targets.
 * On an older chain a validated token could still become codeless and the ERC-1404 views would
 * revert instead of returning a restriction code.
 */
abstract contract TokenSupplyReader {
    /**
     * @notice The token whose `totalSupply()` this rule reads.
     * @dev Implemented by each rule against its own storage, so this base stays stateless.
     * @return The configured token.
     */
    function _supplyToken() internal view virtual returns (ITotalSupply);

    /**
     * @notice Reads the configured token's current total supply without ever reverting.
     * @dev Wrapped in `try/catch` so the ERC-1404 / ERC-3643 read path stays revert-free if the token
     * breaks after configuration -- a proxy upgraded to something that reverts, or a pausable
     * implementation that reverts while paused. Configuration already probes `totalSupply()`, so
     * reaching the failure branch means the token changed behaviour since. Callers translate
     * `available == false` into their own "supply unavailable" restriction code.
     * @return available True when the supply could be read.
     * @return supply The total supply; meaningless when `available` is false.
     */
    function _currentSupply() internal view virtual returns (bool available, uint256 supply) {
        try _supplyToken().totalSupply() returns (uint256 totalSupply_) {
            return (true, totalSupply_);
        } catch {
            return (false, 0);
        }
    }

    /**
     * @notice Returns whether `candidate` answers `totalSupply()` without reverting.
     * @dev Used at configuration time to turn what would otherwise be a silent read-path failure
     * into an immediate, named error raised by the calling rule. `totalSupply()` is mandatory for
     * both rules -- the cap check cannot work without it -- unlike `decimals()`, which only
     * `RuleChainlinkPoR` consults and treats as optional.
     *
     * WARNING: the caller MUST have already established that `candidate` has code. A `try` call to a
     * codeless address reverts uncatchably -- the ABI decoder fails in the caller's frame, outside `catch`'s
     * reach -- and this probe cannot contain it. Note code alone is not sufficient either: a contract that
     * returns 0 bytes fails the same way.
     * @param candidate The token contract to probe.
     * @return True when `totalSupply()` is callable.
     */
    function _probeTotalSupplyCallable(address candidate) internal view virtual returns (bool) {
        try ITotalSupply(candidate).totalSupply() returns (uint256) {
            return true;
        } catch {
            return false;
        }
    }
}
