// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "./HelperContract.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {RuleBlacklist} from "src/rules/validation/deployment/RuleBlacklist.sol";
import {RuleSanctionsList} from "src/rules/validation/deployment/RuleSanctionsList.sol";
import {ISanctionsList} from "src/rules/interfaces/ISanctionsList.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";
import {RuleWhitelistWrapper} from "src/rules/validation/deployment/RuleWhitelistWrapper.sol";
import {RuleERC2980} from "src/rules/validation/deployment/RuleERC2980.sol";
import {RuleConditionalTransferLight} from "src/rules/operation/RuleConditionalTransferLight.sol";

contract VersionTest is Test, HelperContract {
    string constant EXPECTED_VERSION = "0.4.0";

    function testVersionRuleWhitelist() public {
        RuleWhitelist rule = new RuleWhitelist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, true, false);
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleBlacklist() public {
        RuleBlacklist rule = new RuleBlacklist(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS);
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleSanctionsList() public {
        RuleSanctionsList rule =
            new RuleSanctionsList(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, ISanctionsList(ZERO_ADDRESS));
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleMaxTotalSupply() public {
        RuleMaxTotalSupply rule = new RuleMaxTotalSupply(DEFAULT_ADMIN_ADDRESS, ADDRESS1, 0);
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleWhitelistWrapper() public {
        RuleWhitelistWrapper rule = new RuleWhitelistWrapper(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false, true);
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleERC2980() public {
        RuleERC2980 rule = new RuleERC2980(DEFAULT_ADMIN_ADDRESS, ZERO_ADDRESS, false);
        assertEq(rule.version(), EXPECTED_VERSION);
    }

    function testVersionRuleConditionalTransferLight() public {
        RuleConditionalTransferLight rule = new RuleConditionalTransferLight(DEFAULT_ADMIN_ADDRESS);
        assertEq(rule.version(), EXPECTED_VERSION);
    }
}
