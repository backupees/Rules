// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Ownable2StepERC165Module} from "../../../modules/Ownable2StepERC165Module.sol";
import {RuleERC2980Base} from "../abstract/base/RuleERC2980Base.sol";

/**
 * @title RuleERC2980Ownable2Step
 * @notice Ownable2Step variant of RuleERC2980 with owner-based authorization hooks.
 * @dev All whitelist and frozenlist management functions are restricted to the contract owner.
 */
contract RuleERC2980Ownable2Step is RuleERC2980Base, Ownable2Step, Ownable2StepERC165Module {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param owner Contract owner.
     * @param forwarderIrrevocable Address of the ERC-2771 forwarder for meta-transactions.
     * @param allowBurn If true, whitelists `address(0)` at deployment to allow burn/redemption flows.
     */
    constructor(address owner, address forwarderIrrevocable, bool allowBurn)
        RuleERC2980Base(forwarderIrrevocable, allowBurn)
        Ownable(owner)
    {}

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function _authorizeWhitelistAdd() internal view virtual override onlyOwner {}

    function _authorizeWhitelistRemove() internal view virtual override onlyOwner {}

    function _authorizeFrozenlistAdd() internal view virtual override onlyOwner {}

    function _authorizeFrozenlistRemove() internal view virtual override onlyOwner {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(RuleERC2980Base, Ownable2StepERC165Module)
        returns (bool)
    {
        return Ownable2StepERC165Module.supportsInterface(interfaceId)
            || RuleERC2980Base.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _msgSender() internal view virtual override(Context, RuleERC2980Base) returns (address sender) {
        return super._msgSender();
    }

    function _msgData() internal view virtual override(Context, RuleERC2980Base) returns (bytes calldata) {
        return super._msgData();
    }

    function _contextSuffixLength() internal view virtual override(Context, RuleERC2980Base) returns (uint256) {
        return super._contextSuffixLength();
    }
}
