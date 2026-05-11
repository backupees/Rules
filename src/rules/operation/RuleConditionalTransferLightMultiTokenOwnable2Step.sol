// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {RuleInterfaceId} from "RuleEngine/modules/library/RuleInterfaceId.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC1404ExtendInterfaceId} from "CMTAT/library/ERC1404ExtendInterfaceId.sol";
import {RuleEngineInterfaceId} from "CMTAT/library/RuleEngineInterfaceId.sol";
import {IERC7551Compliance} from "CMTAT/interfaces/tokenization/draft-IERC7551.sol";
import {IERC3643ComplianceFull} from "../../mocks/IERC3643ComplianceFull.sol";
import {RuleConditionalTransferLightMultiTokenBase} from "./abstract/RuleConditionalTransferLightMultiTokenBase.sol";

contract RuleConditionalTransferLightMultiTokenOwnable2Step is RuleConditionalTransferLightMultiTokenBase, Ownable2Step {
    constructor(address owner) Ownable(owner) {}

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IERC165).interfaceId
            || interfaceId == RuleEngineInterfaceId.RULE_ENGINE_INTERFACE_ID
            || interfaceId == ERC1404ExtendInterfaceId.ERC1404EXTEND_INTERFACE_ID
            || interfaceId == RuleInterfaceId.IRULE_INTERFACE_ID
            || interfaceId == type(IERC7551Compliance).interfaceId
            || interfaceId == type(IERC3643ComplianceFull).interfaceId;
    }

    function _authorizeTransferApproval() internal view virtual override onlyOwner {}

    function _onlyComplianceManager() internal virtual override onlyOwner {}
}
