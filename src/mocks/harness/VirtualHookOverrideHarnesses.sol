// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {RuleBlacklist} from "../../rules/validation/deployment/RuleBlacklist.sol";
import {RuleConditionalTransferLight} from "../../rules/operation/RuleConditionalTransferLight.sol";

/**
 * @title VirtualHookOverrideHarnesses
 * @notice Proves that the `internal virtual` convention actually holds for hooks that were
 *         previously non-`virtual` and therefore impossible to override.
 * @dev These contracts exist to be compiled: dropping `virtual` from either hook makes the whole
 *      project fail to build, which is the only way a convention with no runtime behaviour can be
 *      regression-tested. The accompanying tests additionally check that the override is reached,
 *      so this is not merely a compile-time assertion.
 */

/**
 * @notice Overrides the transfer-execution authorization hook with an allow-list of one address.
 * @dev Before the hook was made `virtual`, a subclass could not change who may consume approvals --
 *      the most likely customization point on this rule.
 */
contract ConditionalTransferLightCustomExecutorHarness is RuleConditionalTransferLight {
    /**
     * @notice The only address permitted to execute approved transfers.
     */
    address public immutable SOLE_EXECUTOR;

    /**
     * @notice Raised when a caller other than {SOLE_EXECUTOR} tries to execute a transfer.
     */
    error NotTheSoleExecutor(address caller);

    constructor(address admin, address soleExecutor) RuleConditionalTransferLight(admin) {
        SOLE_EXECUTOR = soleExecutor;
    }

    /**
     * @notice Replaces the bound-token / bound-engine policy with a single hard-coded executor.
     */
    function _authorizeTransferExecution() internal view virtual override {
        require(_msgSender() == SOLE_EXECUTOR, NotTheSoleExecutor(_msgSender()));
    }
}

/**
 * @notice Overrides the blacklist's restriction hook to also reject a single quarantined address.
 * @dev Exercises `_detectTransferRestriction` and `_detectTransferRestrictionFrom`, both of which
 *      were non-`virtual` on this rule.
 */
contract BlacklistQuarantineHarness is RuleBlacklist {
    /**
     * @notice Restriction code returned for the quarantined address.
     */
    uint8 public constant CODE_QUARANTINED = 200;

    /**
     * @notice Address rejected in addition to whatever the blacklist itself decides.
     */
    address public immutable QUARANTINED;

    constructor(address admin, address forwarderIrrevocable, address quarantined)
        RuleBlacklist(admin, forwarderIrrevocable)
    {
        QUARANTINED = quarantined;
    }

    /**
     * @notice Applies the base blacklist check, then the extra quarantine rule.
     */
    function _detectTransferRestriction(address from, address to, uint256 value)
        internal
        view
        virtual
        override
        returns (uint8)
    {
        uint8 code = super._detectTransferRestriction(from, to, value);
        if (code != uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK)) {
            return code;
        }
        if (from == QUARANTINED || to == QUARANTINED) {
            return CODE_QUARANTINED;
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @notice Applies the base spender check, then the extra quarantine rule to the spender.
     */
    function _detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        internal
        view
        virtual
        override
        returns (uint8)
    {
        uint8 code = super._detectTransferRestrictionFrom(spender, from, to, value);
        if (code != uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK)) {
            return code;
        }
        if (spender == QUARANTINED) {
            return CODE_QUARANTINED;
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }
}
