// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleBlacklist} from "src/rules/validation/deployment/RuleBlacklist.sol";
import {DeployCMTATWithBlacklist} from "script/DeployCMTATWithBlacklist.s.sol";

contract DeployCMTATWithBlacklistTest is Test {
    function testDeployCMTATWithBlacklist() public {
        DeployCMTATWithBlacklist script = new DeployCMTATWithBlacklist();
        (CMTATStandardStandalone token, RuleBlacklist rule) = _deploy(script);

        assertEq(address(token.ruleEngine()), address(rule));
    }

    function _deploy(DeployCMTATWithBlacklist script)
        internal
        returns (CMTATStandardStandalone token, RuleBlacklist rule)
    {
        (token, rule) = script.deploy(address(1), address(0));
    }
}
