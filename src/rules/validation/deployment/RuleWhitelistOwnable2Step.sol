// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Ownable2StepERC165Module} from "../../../modules/Ownable2StepERC165Module.sol";
import {RuleWhitelistBase} from "../abstract/base/RuleWhitelistBase.sol";
import {RuleAddressSet} from "../abstract/RuleAddressSet/RuleAddressSet.sol";

/**
 * @title RuleWhitelistOwnable2Step
 * @notice Ownable2Step variant of RuleWhitelist with owner-based authorization hooks.
 */
contract RuleWhitelistOwnable2Step is RuleWhitelistBase, Ownable2Step, Ownable2StepERC165Module {
    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param owner Contract owner.
     * @param forwarderIrrevocable Address of the ERC-2771 forwarder.
     * @param checkSpender_ Enables spender checks for transferFrom when true.
     * @param allowMintBurn Pre-lists `address(0)` at deployment when true.
     */
    constructor(address owner, address forwarderIrrevocable, bool checkSpender_, bool allowMintBurn)
        RuleWhitelistBase(forwarderIrrevocable, checkSpender_, allowMintBurn)
        Ownable(owner)
    {}

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function _authorizeAddressListAdd() internal view virtual override onlyOwner {}

    function _authorizeAddressListRemove() internal view virtual override onlyOwner {}

    function _authorizeCheckSpenderManager() internal view virtual override onlyOwner {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(RuleWhitelistBase, Ownable2StepERC165Module)
        returns (bool)
    {
        return Ownable2StepERC165Module.supportsInterface(interfaceId)
            || RuleWhitelistBase.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _msgSender() internal view virtual override(Context, RuleAddressSet) returns (address sender) {
        return super._msgSender();
    }

    function _msgData() internal view virtual override(Context, RuleAddressSet) returns (bytes calldata) {
        return super._msgData();
    }

    function _contextSuffixLength() internal view virtual override(Context, RuleAddressSet) returns (uint256) {
        return super._contextSuffixLength();
    }
}
