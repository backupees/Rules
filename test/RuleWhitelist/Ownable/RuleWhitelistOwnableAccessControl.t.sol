// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {OwnableAddressListTestBase} from "../../utils/OwnableAddressListTestBase.sol";
import {IAddressList} from "src/rules/interfaces/IAddressList.sol";
import {RuleWhitelistOwnable2Step} from "src/rules/validation/deployment/RuleWhitelistOwnable2Step.sol";

contract RuleWhitelistOwnable2StepAccessControl is OwnableAddressListTestBase {
    function _deployAddressList() internal override returns (IAddressList, address) {
        address ownerAddr = WHITELIST_OPERATOR_ADDRESS;
        RuleWhitelistOwnable2Step rule = new RuleWhitelistOwnable2Step(ownerAddr, ZERO_ADDRESS, true, false);
        return (IAddressList(address(rule)), ownerAddr);
    }

    /// @notice `allowMintBurn` sets the explicit flags; the zero address is never listed.
    function testAllowMintBurnConstructorSetsFlagsAndDoesNotListZeroAddress() public {
        address ownerAddr = WHITELIST_OPERATOR_ADDRESS;
        RuleWhitelistOwnable2Step rule = new RuleWhitelistOwnable2Step(ownerAddr, ZERO_ADDRESS, true, true);

        assertTrue(rule.allowMint());
        assertTrue(rule.allowBurn());
        assertFalse(rule.isAddressListed(ZERO_ADDRESS));
        assertFalse(rule.isVerified(ZERO_ADDRESS));
    }
}
