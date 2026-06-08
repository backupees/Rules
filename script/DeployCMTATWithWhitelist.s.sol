// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {ICMTATConstructor, CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IERC1643CMTAT} from "CMTAT/interfaces/tokenization/draft-IERC1643CMTAT.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleWhitelist} from "src/rules/validation/deployment/RuleWhitelist.sol";

contract DeployCMTATWithWhitelist is Script {
    function deploy(address admin, address forwarder, bool checkSpender)
        public
        returns (CMTATStandardStandalone token, RuleWhitelist rule)
    {
        ICMTATConstructor.ERC20Attributes memory erc20Attributes =
            ICMTATConstructor.ERC20Attributes("CMTA Token", "CMTAT", 0);
        ICMTATConstructor.ExtraInformationAttributes memory extraInformationAttributes =
            ICMTATConstructor.ExtraInformationAttributes(
                "CMTAT_ISIN",
                IERC1643CMTAT.DocumentInfo(
                    "Terms", "https://cmta.ch", 0x9ff867f6592aa9d6d039e7aad6bd71f1659720cbc4dd9eae1554f6eab490098b
                ),
                "CMTAT_info"
            );
        ICMTATConstructor.Engine memory engines = ICMTATConstructor.Engine(IRuleEngine(address(0)));

        token = new CMTATStandardStandalone(forwarder, address(this), erc20Attributes, extraInformationAttributes, engines);
        rule = new RuleWhitelist(admin, address(0), checkSpender, false);

        token.setRuleEngine(IRuleEngine(address(rule)));

        if (admin != address(this)) {
            token.grantRole(bytes32(0), admin);
            token.renounceRole(bytes32(0), address(this));
        }
    }

    function run() external returns (CMTATStandardStandalone token, RuleWhitelist rule) {
        vm.startBroadcast();
        (token, rule) = deploy(msg.sender, address(0), false);
        vm.stopBroadcast();
    }
}
