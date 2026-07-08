// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleWhitelistWrapper} from "src/rules/validation/deployment/RuleWhitelistWrapper.sol";

/**
 * @title RuleWhitelistWrapperHarnessInternal — test harness exposing RuleWhitelistWrapper internal transfer hook
 */
contract RuleWhitelistWrapperHarnessInternal is RuleWhitelistWrapper {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the harness forwarding to the RuleWhitelistWrapper constructor
     * @param admin Address granted the admin role
     * @param forwarderIrrevocable Trusted ERC-2771 forwarder address
     * @param checkSpender_ Whether the spender is also checked against the whitelist
     */
    constructor(address admin, address forwarderIrrevocable, bool checkSpender_)
        RuleWhitelistWrapper(admin, forwarderIrrevocable, checkSpender_)
    {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Exposes the internal `_transferred()` post-transfer hook
     * @param spender Address executing the transfer (relevant for `transferFrom`)
     * @param from Source address of the transfer
     * @param to Destination address of the transfer
     * @param value Amount transferred
     */
    function exposedTransferredSpenderInternal(address spender, address from, address to, uint256 value) external view {
        _transferred(spender, from, to, value);
    }
}
