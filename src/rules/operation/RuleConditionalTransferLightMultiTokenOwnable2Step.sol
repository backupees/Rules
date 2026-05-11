// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {RuleInterfaceId} from "RuleEngine/modules/library/RuleInterfaceId.sol";
import {ERC1404ExtendInterfaceId} from "CMTAT/library/ERC1404ExtendInterfaceId.sol";
import {RuleEngineInterfaceId} from "CMTAT/library/RuleEngineInterfaceId.sol";
import {IERC7551Compliance} from "CMTAT/interfaces/tokenization/draft-IERC7551.sol";
import {IERC3643ComplianceFull} from "../../mocks/IERC3643ComplianceFull.sol";
import {RuleConditionalTransferLightMultiTokenBase} from "./abstract/RuleConditionalTransferLightMultiTokenBase.sol";
import {Ownable2StepERC165Module} from "../../modules/Ownable2StepERC165Module.sol";

contract RuleConditionalTransferLightMultiTokenOwnable2Step is
    RuleConditionalTransferLightMultiTokenBase,
    Ownable2Step,
    Ownable2StepERC165Module
{
    constructor(address owner) Ownable(owner) {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Ownable2StepERC165Module, IERC165)
        returns (bool)
    {
        return Ownable2StepERC165Module.supportsInterface(interfaceId)
            || interfaceId == RuleEngineInterfaceId.RULE_ENGINE_INTERFACE_ID
            || interfaceId == ERC1404ExtendInterfaceId.ERC1404EXTEND_INTERFACE_ID
            || interfaceId == RuleInterfaceId.IRULE_INTERFACE_ID
            || interfaceId == type(IERC7551Compliance).interfaceId
            || interfaceId == type(IERC3643ComplianceFull).interfaceId;
    }

    function _authorizeTransferApproval() internal view virtual override onlyOwner {}

    function _onlyComplianceManager() internal virtual override onlyOwner {}
}
