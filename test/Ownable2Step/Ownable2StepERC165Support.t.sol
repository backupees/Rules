// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {OwnableInterfaceId} from "RuleEngine/modules/library/OwnableInterfaceId.sol";
import {Ownable2StepInterfaceId} from "RuleEngine/modules/library/Ownable2StepInterfaceId.sol";

import {RuleBlacklistOwnable2Step} from "src/rules/validation/deployment/RuleBlacklistOwnable2Step.sol";
import {RuleWhitelistOwnable2Step} from "src/rules/validation/deployment/RuleWhitelistOwnable2Step.sol";
import {RuleWhitelistWrapperOwnable2Step} from "src/rules/validation/deployment/RuleWhitelistWrapperOwnable2Step.sol";
import {RuleSpenderWhitelistOwnable2Step} from "src/rules/validation/deployment/RuleSpenderWhitelistOwnable2Step.sol";
import {RuleERC2980Ownable2Step} from "src/rules/validation/deployment/RuleERC2980Ownable2Step.sol";
import {RuleSanctionsListOwnable2Step} from "src/rules/validation/deployment/RuleSanctionsListOwnable2Step.sol";
import {RuleIdentityRegistryOwnable2Step} from "src/rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol";
import {RuleMaxTotalSupplyOwnable2Step} from "src/rules/validation/deployment/RuleMaxTotalSupplyOwnable2Step.sol";
import {
    RuleConditionalTransferLightOwnable2Step
} from "src/rules/operation/RuleConditionalTransferLightOwnable2Step.sol";
import {
    RuleConditionalTransferLightMultiTokenOwnable2Step
} from "src/rules/operation/RuleConditionalTransferLightMultiTokenOwnable2Step.sol";
import {ISanctionsList} from "src/rules/interfaces/ISanctionsList.sol";

contract Ownable2StepERC165SupportTest is Test {
    address internal constant OWNER = address(0xA11CE);

    function testAllOwnable2StepRulesAdvertiseOwnableInterfaces() public {
        RuleBlacklistOwnable2Step blacklist = new RuleBlacklistOwnable2Step(OWNER, address(0));
        RuleWhitelistOwnable2Step whitelist = new RuleWhitelistOwnable2Step(OWNER, address(0), false, false);
        RuleWhitelistWrapperOwnable2Step wrapper = new RuleWhitelistWrapperOwnable2Step(OWNER, address(0), false, true);
        RuleSpenderWhitelistOwnable2Step spenderWhitelist = new RuleSpenderWhitelistOwnable2Step(OWNER, address(0));
        RuleERC2980Ownable2Step erc2980 = new RuleERC2980Ownable2Step(OWNER, address(0), false);
        RuleSanctionsListOwnable2Step sanctions =
            new RuleSanctionsListOwnable2Step(OWNER, address(0), ISanctionsList(address(0)));
        RuleIdentityRegistryOwnable2Step identity =
            new RuleIdentityRegistryOwnable2Step(OWNER, address(0), false, false);
        RuleMaxTotalSupplyOwnable2Step maxSupply = new RuleMaxTotalSupplyOwnable2Step(OWNER, address(1), 1);
        RuleConditionalTransferLightOwnable2Step conditional = new RuleConditionalTransferLightOwnable2Step(OWNER);
        RuleConditionalTransferLightMultiTokenOwnable2Step conditionalMulti =
            new RuleConditionalTransferLightMultiTokenOwnable2Step(OWNER);

        _assertOwnable2StepInterfaces(address(blacklist));
        _assertOwnable2StepInterfaces(address(whitelist));
        _assertOwnable2StepInterfaces(address(wrapper));
        _assertOwnable2StepInterfaces(address(spenderWhitelist));
        _assertOwnable2StepInterfaces(address(erc2980));
        _assertOwnable2StepInterfaces(address(sanctions));
        _assertOwnable2StepInterfaces(address(identity));
        _assertOwnable2StepInterfaces(address(maxSupply));
        _assertOwnable2StepInterfaces(address(conditional));
        _assertOwnable2StepInterfaces(address(conditionalMulti));
    }

    function _assertOwnable2StepInterfaces(address target) internal view {
        IERC165 i = IERC165(target);
        assertTrue(i.supportsInterface(type(IERC165).interfaceId));
        assertTrue(i.supportsInterface(OwnableInterfaceId.IERC173_INTERFACE_ID));
        assertTrue(i.supportsInterface(Ownable2StepInterfaceId.IOWNABLE2STEP_INTERFACE_ID));
        assertFalse(i.supportsInterface(type(IAccessControl).interfaceId));
        assertFalse(i.supportsInterface(bytes4(0xdeadbeef)));
    }
}
