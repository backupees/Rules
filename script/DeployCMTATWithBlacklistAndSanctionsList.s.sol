// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {ICMTATConstructor, CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IERC1643CMTAT} from "CMTAT/interfaces/tokenization/draft-IERC1643CMTAT.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleEngine} from "RuleEngine/deployment/RuleEngine.sol";
import {RuleBlacklist} from "src/rules/validation/deployment/RuleBlacklist.sol";
import {RuleSanctionsList} from "src/rules/validation/deployment/RuleSanctionsList.sol";
import {ISanctionsList} from "src/rules/interfaces/ISanctionsList.sol";

/**
 * @title DeployCMTATWithBlacklistAndSanctionsList
 * @notice Deploys a CMTAT token with a RuleEngine enforcing two validation rules:
 *         a blacklist (RuleBlacklist) and a sanctions screening (RuleSanctionsList).
 *
 *         Deployment order:
 *         1. CMTATStandardStandalone   — token contract (deployer as temporary admin)
 *         2. RuleBlacklist     — blocks blacklisted senders / recipients
 *         3. RuleSanctionsList — blocks sanctioned addresses via Chainalysis oracle
 *         4. RuleEngine        — aggregates both rules; token bound at construction
 *         5. Wire RuleEngine → CMTAT via setRuleEngine
 *         6. Hand over all admin roles to `admin`
 */
contract DeployCMTATWithBlacklistAndSanctionsList is Script {
    function deploy(address admin, address forwarder, ISanctionsList sanctionsOracle)
        public
        returns (
            CMTATStandardStandalone token,
            RuleEngine ruleEngine,
            RuleBlacklist ruleBlacklist,
            RuleSanctionsList ruleSanctionsList
        )
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

        // Deploy CMTAT with the deployer as temporary admin so we can configure it.
        token = new CMTATStandardStandalone(forwarder, address(this), erc20Attributes, extraInformationAttributes, engines);

        // Deploy rules; each rule is owned directly by the intended admin.
        ruleBlacklist = new RuleBlacklist(admin, address(0));
        ruleSanctionsList = new RuleSanctionsList(admin, address(0), sanctionsOracle);

        // Deploy RuleEngine with the deployer as temporary admin so we can add rules.
        // The token is bound at construction so it is authorised to call transferred().
        ruleEngine = new RuleEngine(address(this), forwarder, address(token));

        // Register both rules in evaluation order: blacklist first, sanctions second.
        ruleEngine.addRule(ruleBlacklist);
        ruleEngine.addRule(ruleSanctionsList);

        // Connect the RuleEngine to the token.
        token.setRuleEngine(IRuleEngine(address(ruleEngine)));

        // Transfer admin rights to the intended admin and remove the deployer.
        if (admin != address(this)) {
            ruleEngine.grantRole(bytes32(0), admin);
            ruleEngine.renounceRole(bytes32(0), address(this));
            token.grantRole(bytes32(0), admin);
            token.renounceRole(bytes32(0), address(this));
        }
    }

    function run()
        external
        returns (
            CMTATStandardStandalone token,
            RuleEngine ruleEngine,
            RuleBlacklist ruleBlacklist,
            RuleSanctionsList ruleSanctionsList
        )
    {
        vm.startBroadcast();
        // Pass address(0) for sanctionsOracle to deploy without an oracle configured.
        // The oracle can be set post-deployment via RuleSanctionsList.setSanctionListOracle().
        (token, ruleEngine, ruleBlacklist, ruleSanctionsList) =
            deploy(msg.sender, address(0), ISanctionsList(address(0)));
        vm.stopBroadcast();
    }
}
