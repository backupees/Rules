// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";
import {DeployCMTATWithWhitelist} from "script/DeployCMTATWithWhitelist.s.sol";

contract DeployCMTATWithWhitelistTest is Test {
    function testDeployCMTATWithWhitelist() public {
        DeployCMTATWithWhitelist script = new DeployCMTATWithWhitelist();
        (CMTATStandardStandalone token, RuleWhitelist rule) = _deploy(script);
        assertEq(address(token.ruleEngine()), address(rule));
    }

    function _deploy(DeployCMTATWithWhitelist script) internal returns (CMTATStandardStandalone token, RuleWhitelist rule) {
        (token, rule) = script.deploy(address(1), address(0), false);
    }
}
