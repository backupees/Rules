// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {ICMTATConstructor, CMTATStandardStandalone} from "CMTAT/deployment/CMTATStandardStandalone.sol";
import {IERC1643CMTAT} from "CMTAT/interfaces/tokenization/draft-IERC1643CMTAT.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleEngine} from "RuleEngine/deployment/RuleEngine.sol";
import {RuleBlacklist} from "src/rules/validation/deployment/RuleBlacklist.sol";
import {RuleMaxTotalSupply} from "src/rules/validation/deployment/RuleMaxTotalSupply.sol";
import {RuleSanctionsList} from "src/rules/validation/deployment/RuleSanctionsList.sol";
import {ISanctionsList} from "src/rules/interfaces/ISanctionsList.sol";

/**
 * @title DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply
 * @notice Deploys a CMTAT token behind a RuleEngine enforcing three validation rules: a blacklist,
 *         sanctions screening, and a hard cap on total supply.
 *
 *         Deployment order:
 *         1. `CMTATStandardStandalone` — the token (deployer as temporary admin, so it can be wired)
 *         2. `RuleBlacklist`           — blocks blacklisted sender / recipient / spender
 *         3. `RuleSanctionsList`       — blocks sanctioned addresses via a Chainalysis-style oracle
 *         4. `RuleMaxTotalSupply`      — rejects mints that would push `totalSupply` past the cap
 *         5. `RuleEngine`              — aggregates all three; the token is bound at construction
 *         6. `token.setRuleEngine(...)`
 *         7. Hand every admin role to `admin`, renounce the deployer's
 *
 * @dev **Step 4 must follow step 1.** Unlike the other two rules, `RuleMaxTotalSupply` validates its
 *      token at construction — non-zero, has code, and `totalSupply()` callable — so it cannot be
 *      deployed before the token exists. Passing a placeholder address reverts with
 *      `RuleMaxTotalSupply_TokenIsNotAContract`.
 *
 * @dev **One `RuleMaxTotalSupply` instance protects one token.** It reads `totalSupply()` from the
 *      `tokenContract` it was given, never from whichever token triggered the check, and behind a
 *      RuleEngine it cannot learn that identity. Do not add this instance to a second RuleEngine:
 *      both tokens would be capped against this one's supply. Deploy a second instance instead.
 *
 * @dev Rule order matters only for *which* restriction code a rejected transfer reports — the
 *      RuleEngine returns the first non-zero code — not for whether it is rejected. Blacklist first,
 *      then sanctions, then the supply cap, so an address-level rejection is reported in preference
 *      to a supply-level one.
 */
contract DeployCMTATWithBlacklistSanctionsListAndMaxTotalSupply is Script {
    /**
     * @notice Deploys and wires the whole set.
     * @dev `deployer` is passed explicitly rather than read as `address(this)`, because the two
     *      execution contexts disagree about who makes the wiring calls: under `forge script` the
     *      broadcaster does, while a test calling {deploy} directly makes them from the script
     *      contract. Foundry also *rejects* `address(this)` inside a broadcast outright — "script
     *      contracts are ephemeral and their addresses should not be relied upon" — so a script that
     *      reads it works under test and reverts on the real deployment path.
     * @param admin Address that ends up holding every admin role.
     * @param deployer Address that executes the calls below and therefore holds the temporary admin
     *        roles: `msg.sender` under `forge script`, the script contract's address under test.
     * @param forwarder ERC-2771 trusted forwarder; `address(0)` disables meta-transactions.
     * @param sanctionsOracle Sanctions oracle; `address(0)` leaves screening disabled until
     *        `RuleSanctionsList.setSanctionListOracle` is called. **An unset oracle fails OPEN** —
     *        the rule passes every transfer.
     * @param maxTotalSupply The supply ceiling enforced on mints.
     * @return token The deployed CMTAT.
     * @return ruleEngine The engine holding the three rules.
     * @return ruleBlacklist The blacklist rule.
     * @return ruleSanctionsList The sanctions rule.
     * @return ruleMaxTotalSupply The supply-cap rule.
     */
    function deploy(
        address admin,
        address deployer,
        address forwarder,
        ISanctionsList sanctionsOracle,
        uint256 maxTotalSupply
    )
        public
        returns (
            CMTATStandardStandalone token,
            RuleEngine ruleEngine,
            RuleBlacklist ruleBlacklist,
            RuleSanctionsList ruleSanctionsList,
            RuleMaxTotalSupply ruleMaxTotalSupply
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

        // 1. The token, with the deployer as temporary admin so the wiring below is permitted.
        token = new CMTATStandardStandalone(forwarder, deployer, erc20Attributes, extraInformationAttributes, engines);

        // 2-3. Address-screening rules; each is owned by the intended admin from the start.
        ruleBlacklist = new RuleBlacklist(admin, forwarder);
        ruleSanctionsList = new RuleSanctionsList(admin, forwarder, sanctionsOracle);

        // 4. The supply cap. MUST come after the token: the constructor probes `totalSupply()`.
        ruleMaxTotalSupply = new RuleMaxTotalSupply(admin, address(token), maxTotalSupply);

        // 5. The engine, deployer-owned for now so rules can be added. Binding the token at
        //    construction is what authorises it to call `transferred()` on the engine.
        ruleEngine = new RuleEngine(deployer, forwarder, address(token));

        ruleEngine.addRule(ruleBlacklist);
        ruleEngine.addRule(ruleSanctionsList);
        ruleEngine.addRule(ruleMaxTotalSupply);

        // 6. Connect the engine to the token.
        token.setRuleEngine(IRuleEngine(address(ruleEngine)));

        // 7. Hand over, and drop the deployer's rights so the deployment key is not a standing risk.
        if (admin != deployer) {
            ruleEngine.grantRole(bytes32(0), admin);
            ruleEngine.renounceRole(bytes32(0), deployer);
            token.grantRole(bytes32(0), admin);
            token.renounceRole(bytes32(0), deployer);
        }
    }

    /**
     * @notice Broadcast entrypoint. Deploys with no sanctions oracle and a 1 000 000 unit cap.
     * @dev The oracle is left unset because its address is chain-specific (Chainalysis publishes one
     *      per network). **Until it is set, sanctions screening is disabled and passes everything** —
     *      call `setSanctionListOracle` before the token goes live.
     */
    function run()
        external
        returns (
            CMTATStandardStandalone token,
            RuleEngine ruleEngine,
            RuleBlacklist ruleBlacklist,
            RuleSanctionsList ruleSanctionsList,
            RuleMaxTotalSupply ruleMaxTotalSupply
        )
    {
        vm.startBroadcast();
        // The broadcaster is both the final admin and the acting deployer, so the hand-over below
        // is a no-op and no temporary rights outlive the transaction.
        (token, ruleEngine, ruleBlacklist, ruleSanctionsList, ruleMaxTotalSupply) =
            deploy(msg.sender, msg.sender, address(0), ISanctionsList(address(0)), 1_000_000);
        vm.stopBroadcast();
    }
}
