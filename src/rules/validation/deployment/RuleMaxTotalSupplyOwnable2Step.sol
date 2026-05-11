// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable2StepERC165Module} from "../../../modules/Ownable2StepERC165Module.sol";
import {RuleTransferValidation} from "../abstract/core/RuleTransferValidation.sol";
import {RuleMaxTotalSupplyBase} from "../abstract/base/RuleMaxTotalSupplyBase.sol";

/**
 * @title RuleMaxTotalSupplyOwnable2Step
 * @notice Ownable2Step variant of RuleMaxTotalSupply.
 */
contract RuleMaxTotalSupplyOwnable2Step is RuleMaxTotalSupplyBase, Ownable2Step, Ownable2StepERC165Module {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address owner, address tokenContract_, uint256 maxTotalSupply_)
        RuleMaxTotalSupplyBase(tokenContract_, maxTotalSupply_)
        Ownable(owner)
    {}

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function _authorizeMaxTotalSupplyManager() internal view virtual override onlyOwner {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(RuleTransferValidation, Ownable2StepERC165Module)
        returns (bool)
    {
        return Ownable2StepERC165Module.supportsInterface(interfaceId)
            || RuleTransferValidation.supportsInterface(interfaceId);
    }
}
