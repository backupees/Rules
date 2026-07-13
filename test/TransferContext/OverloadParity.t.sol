// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "../HelperContract.sol";
import {ITransferContext} from "src/rules/interfaces/ITransferContext.sol";
import {ISanctionsList} from "src/rules/interfaces/ISanctionsList.sol";
import {IRule} from "RuleEngine/interfaces/IRule.sol";

import {IdentityRegistryMock} from "src/mocks/IdentityRegistryMock.sol";
import {SanctionListOracle} from "src/mocks/SanctionListOracle.sol";

import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {RuleWhitelistWrapper} from "src/rules/validation/deployment/RuleWhitelistWrapper.sol";
import {RuleBlacklist} from "src/rules/validation/deployment/RuleBlacklist.sol";
import {RuleSpenderWhitelist} from "src/rules/validation/deployment/RuleSpenderWhitelist.sol";
import {RuleSanctionsList} from "src/rules/validation/deployment/RuleSanctionsList.sol";
import {RuleERC2980} from "src/rules/validation/deployment/RuleERC2980.sol";
import {RuleIdentityRegistry} from "src/rules/validation/deployment/RuleIdentityRegistry.sol";

/**
 * @notice Flattened view of every overload {RuleNFTAdapter} adds on top of {RuleTransferValidation},
 *         so the parity assertions can be run generically across every rule that inherits it.
 */
interface INFTAdapterRule {
    /* ==== read path — fungible (RuleTransferValidation) ==== */
    function detectTransferRestriction(address from, address to, uint256 value) external view returns (uint8);
    function detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        external
        view
        returns (uint8);
    function canTransfer(address from, address to, uint256 value) external view returns (bool);
    function canTransferFrom(address spender, address from, address to, uint256 value) external view returns (bool);

    /* ==== read path — ERC-7943 tokenId overloads (RuleNFTAdapter) ==== */
    function detectTransferRestriction(address from, address to, uint256 tokenId, uint256 value)
        external
        view
        returns (uint8);
    function detectTransferRestrictionFrom(address spender, address from, address to, uint256 tokenId, uint256 value)
        external
        view
        returns (uint8);
    function canTransfer(address from, address to, uint256 tokenId, uint256 amount) external view returns (bool);
    function canTransferFrom(address spender, address from, address to, uint256 tokenId, uint256 value)
        external
        view
        returns (bool);

    /* ==== write path ==== */
    function transferred(address from, address to, uint256 value) external;
    function transferred(address spender, address from, address to, uint256 value) external;
    function transferred(address from, address to, uint256 tokenId, uint256 value) external;
    function transferred(address spender, address from, address to, uint256 tokenId, uint256 value) external;
    function transferred(ITransferContext.FungibleTransferContext calldata ctx) external;
    function transferred(ITransferContext.MultiTokenTransferContext calldata ctx) external;
}

/**
 * @title OverloadParity
 * @notice Improvement I-10d: exercises the ERC-7943 `tokenId` overloads and the {ITransferContext}
 *         struct entrypoints on EVERY rule that inherits {RuleNFTAdapter}, closing the residual
 *         coverage gap in `RuleNFTAdapter` / `RuleTransferValidation`.
 * @dev The property under test is **parity**: `RuleNFTAdapter` exists only to re-expose the same
 *      restriction logic under extra signatures, ignoring `tokenId`. So for every rule and every
 *      input, the `tokenId` overload MUST be indistinguishable from its fungible counterpart, and
 *      the `ctx` entrypoints MUST dispatch to the same internal hooks. Any divergence is a bug.
 *
 *      This also pins threat `AC-5`: the `ctx` entrypoints are `external` with no access control on
 *      validation rules. That is acceptable precisely because they are view-only — an unprivileged
 *      caller can run the check and maybe revert, but cannot mutate anything.
 */
contract OverloadParity is Test, HelperContract {
    uint256 private constant TOKEN_ID = 42;
    address private constant FORWARDER = address(0);

    IdentityRegistryMock private registry;
    SanctionListOracle private oracle;

    function setUp() public {
        registry = new IdentityRegistryMock();
        oracle = new SanctionListOracle();
    }

    /*//////////////////////////////////////////////////////////////
                        PARITY ASSERTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev The tokenId overloads must return exactly what the fungible ones return.
    function _assertReadParity(address rule, address spender, address from, address to, uint256 value, string memory w)
        internal
        view
    {
        INFTAdapterRule r = INFTAdapterRule(rule);

        assertEq(
            r.detectTransferRestriction(from, to, value),
            r.detectTransferRestriction(from, to, TOKEN_ID, value),
            string.concat(w, ": detectTransferRestriction")
        );
        assertEq(
            r.detectTransferRestrictionFrom(spender, from, to, value),
            r.detectTransferRestrictionFrom(spender, from, to, TOKEN_ID, value),
            string.concat(w, ": detectTransferRestrictionFrom")
        );
        assertEq(
            r.canTransfer(from, to, value), r.canTransfer(from, to, TOKEN_ID, value), string.concat(w, ": canTransfer")
        );
        assertEq(
            r.canTransferFrom(spender, from, to, value),
            r.canTransferFrom(spender, from, to, TOKEN_ID, value),
            string.concat(w, ": canTransferFrom")
        );
    }

    /// @dev The write-path overloads must accept/reject identically to their fungible counterparts.
    function _assertWriteParity(
        address rule,
        address spender,
        address from,
        address to,
        uint256 value,
        string memory w
    ) internal {
        bool direct = _try3(rule, from, to, value);
        bool directNft = _try4Nft(rule, from, to, value);
        assertEq(direct, directNft, string.concat(w, ": transferred(from,to,value) vs tokenId overload"));

        bool delegated = _try4From(rule, spender, from, to, value);
        bool delegatedNft = _try5Nft(rule, spender, from, to, value);
        assertEq(delegated, delegatedNft, string.concat(w, ": transferredFrom vs tokenId overload"));

        // ctx.sender == 0 dispatches to the direct hook...
        assertEq(
            _tryFungibleCtx(rule, ZERO_ADDRESS, from, to, value),
            direct,
            string.concat(w, ": FungibleContext(sender=0) must match transferred(from,to,value)")
        );
        // ...and a spender that differs from `from` dispatches to the delegated hook.
        assertEq(
            _tryFungibleCtx(rule, spender, from, to, value),
            delegated,
            string.concat(w, ": FungibleContext(sender=spender) must match transferredFrom")
        );
        assertEq(
            _tryMultiCtx(rule, spender, from, to, value),
            delegated,
            string.concat(w, ": MultiTokenContext(sender=spender) must match transferredFrom")
        );
        assertEq(
            _tryMultiCtx(rule, ZERO_ADDRESS, from, to, value),
            direct,
            string.concat(w, ": MultiTokenContext(sender=0) must match transferred(from,to,value)")
        );
    }

    /// @dev Runs both parity checks for an allowed pair and a blocked pair.
    function _assertParity(
        address rule,
        address spender,
        address okFrom,
        address okTo,
        address badFrom,
        address badTo,
        string memory what
    ) internal {
        _assertReadParity(rule, spender, okFrom, okTo, 10, string.concat(what, " [allowed]"));
        _assertWriteParity(rule, spender, okFrom, okTo, 10, string.concat(what, " [allowed]"));

        _assertReadParity(rule, spender, badFrom, badTo, 10, string.concat(what, " [blocked]"));
        _assertWriteParity(rule, spender, badFrom, badTo, 10, string.concat(what, " [blocked]"));
    }

    /*//////////////////////////////////////////////////////////////
                        PER-RULE PARITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Parity_RuleWhitelist() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleWhitelist rule = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER, true, false);
        rule.addAddress(ADDRESS1);
        rule.addAddress(ADDRESS2);
        rule.addAddress(ADDRESS3);
        vm.stopPrank();

        _assertParity(address(rule), ADDRESS3, ADDRESS1, ADDRESS2, ATTACKER, ADDRESS2, "RuleWhitelist");
    }

    function test_Parity_RuleWhitelistWrapper() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleWhitelist child = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER, false, false);
        child.addAddress(ADDRESS1);
        child.addAddress(ADDRESS2);
        child.addAddress(ADDRESS3);

        RuleWhitelistWrapper wrapper = new RuleWhitelistWrapper(DEFAULT_ADMIN_ADDRESS, FORWARDER, true);
        wrapper.addRule(IRule(address(child)));
        vm.stopPrank();

        _assertParity(address(wrapper), ADDRESS3, ADDRESS1, ADDRESS2, ATTACKER, ADDRESS2, "RuleWhitelistWrapper");
    }

    function test_Parity_RuleBlacklist() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleBlacklist rule = new RuleBlacklist(DEFAULT_ADMIN_ADDRESS, FORWARDER);
        rule.addAddress(ATTACKER);
        vm.stopPrank();

        _assertParity(address(rule), ADDRESS3, ADDRESS1, ADDRESS2, ATTACKER, ADDRESS2, "RuleBlacklist");
    }

    function test_Parity_RuleSpenderWhitelist() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleSpenderWhitelist rule = new RuleSpenderWhitelist(DEFAULT_ADMIN_ADDRESS, FORWARDER);
        rule.addAddress(ADDRESS3);
        vm.stopPrank();

        // Direct transfers are always allowed by this rule; only the spender leg can block.
        _assertReadParity(address(rule), ADDRESS3, ADDRESS1, ADDRESS2, 10, "RuleSpenderWhitelist [ok spender]");
        _assertWriteParity(address(rule), ADDRESS3, ADDRESS1, ADDRESS2, 10, "RuleSpenderWhitelist [ok spender]");
        _assertReadParity(address(rule), ATTACKER, ADDRESS1, ADDRESS2, 10, "RuleSpenderWhitelist [bad spender]");
        _assertWriteParity(address(rule), ATTACKER, ADDRESS1, ADDRESS2, 10, "RuleSpenderWhitelist [bad spender]");
    }

    function test_Parity_RuleSanctionsList() public {
        oracle.addToSanctionsList(ATTACKER);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleSanctionsList rule =
            new RuleSanctionsList(DEFAULT_ADMIN_ADDRESS, FORWARDER, ISanctionsList(address(oracle)));

        _assertParity(address(rule), ADDRESS3, ADDRESS1, ADDRESS2, ATTACKER, ADDRESS2, "RuleSanctionsList");
    }

    function test_Parity_RuleERC2980() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleERC2980 rule = new RuleERC2980(DEFAULT_ADMIN_ADDRESS, FORWARDER, false);
        rule.addWhitelistAddress(ADDRESS2);
        rule.addFrozenlistAddress(ATTACKER);
        vm.stopPrank();

        _assertParity(address(rule), ADDRESS3, ADDRESS1, ADDRESS2, ATTACKER, ADDRESS2, "RuleERC2980");
    }

    function test_Parity_RuleIdentityRegistry() public {
        registry.setVerified(ADDRESS1, true);
        registry.setVerified(ADDRESS2, true);
        registry.setVerified(ADDRESS3, true);

        vm.prank(DEFAULT_ADMIN_ADDRESS);
        RuleIdentityRegistry rule = new RuleIdentityRegistry(DEFAULT_ADMIN_ADDRESS, address(registry));

        _assertParity(address(rule), ADDRESS3, ADDRESS1, ADDRESS2, ATTACKER, ADDRESS2, "RuleIdentityRegistry");
    }

    /*//////////////////////////////////////////////////////////////
                            AC-5
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice AC-5: the `ctx` entrypoints on {RuleNFTAdapter} are `external` with NO access control.
     *         On a validation rule this is harmless because the hooks are view-only: an arbitrary
     *         caller can run the check (and be reverted by it) but can never mutate state.
     */
    function test_AC5_ContextEntrypointsAreUnguardedButViewOnly() public {
        vm.startPrank(DEFAULT_ADMIN_ADDRESS);
        RuleBlacklist rule = new RuleBlacklist(DEFAULT_ADMIN_ADDRESS, FORWARDER);
        rule.addAddress(ATTACKER);
        vm.stopPrank();

        // Anyone may call the ctx entrypoint for a permitted transfer; it simply succeeds.
        vm.prank(ATTACKER);
        assertTrue(_tryFungibleCtx(address(rule), ZERO_ADDRESS, ADDRESS1, ADDRESS2, 10), "unguarded call should pass");

        // ...and it still enforces the rule for a blocked transfer.
        vm.prank(ADDRESS1);
        assertFalse(
            _tryFungibleCtx(address(rule), ZERO_ADDRESS, ATTACKER, ADDRESS2, 10), "unguarded call must still enforce"
        );

        // No state was mutated: the blacklist is untouched.
        assertTrue(rule.isAddressListed(ATTACKER));
        assertEq(rule.listedAddressCount(), 1);
    }

    /*//////////////////////////////////////////////////////////////
                        LOW-LEVEL TRY HELPERS
    //////////////////////////////////////////////////////////////*/

    function _try3(address rule, address from, address to, uint256 value) internal returns (bool ok) {
        try INFTAdapterRule(rule).transferred(from, to, value) {
            ok = true;
        } catch {
            ok = false;
        }
    }

    function _try4From(address rule, address spender, address from, address to, uint256 value)
        internal
        returns (bool ok)
    {
        try INFTAdapterRule(rule).transferred(spender, from, to, value) {
            ok = true;
        } catch {
            ok = false;
        }
    }

    function _try4Nft(address rule, address from, address to, uint256 value) internal returns (bool ok) {
        try INFTAdapterRule(rule).transferred(from, to, TOKEN_ID, value) {
            ok = true;
        } catch {
            ok = false;
        }
    }

    function _try5Nft(address rule, address spender, address from, address to, uint256 value)
        internal
        returns (bool ok)
    {
        try INFTAdapterRule(rule).transferred(spender, from, to, TOKEN_ID, value) {
            ok = true;
        } catch {
            ok = false;
        }
    }

    function _tryFungibleCtx(address rule, address sender, address from, address to, uint256 value)
        internal
        returns (bool ok)
    {
        ITransferContext.FungibleTransferContext memory ctx = ITransferContext.FungibleTransferContext({
            selector: bytes4(0), sender: sender, from: from, to: to, value: value, data: ""
        });
        try INFTAdapterRule(rule).transferred(ctx) {
            ok = true;
        } catch {
            ok = false;
        }
    }

    function _tryMultiCtx(address rule, address sender, address from, address to, uint256 value)
        internal
        returns (bool ok)
    {
        ITransferContext.MultiTokenTransferContext memory ctx = ITransferContext.MultiTokenTransferContext({
            selector: bytes4(0), sender: sender, from: from, to: to, value: value, tokenId: TOKEN_ID, data: ""
        });
        try INFTAdapterRule(rule).transferred(ctx) {
            ok = true;
        } catch {
            ok = false;
        }
    }
}
