// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

/* ==== OpenZeppelin === */
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
/* ==== Abstract contracts === */
import {RuleWhitelistWrapperBase} from "../abstract/base/RuleWhitelistWrapperBase.sol";

/**
 * @title Wrapper to call several different whitelist rules (Ownable2Step)
 */
contract RuleWhitelistWrapperOwnable2Step is RuleWhitelistWrapperBase, Ownable2Step {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @param owner Address of the contract owner
     * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
     */
    constructor(address owner, address forwarderIrrevocable, bool checkSpender_)
        RuleWhitelistWrapperBase(forwarderIrrevocable, checkSpender_)
        Ownable(owner)
    {}

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    function _authorizeCheckSpenderManager() internal view virtual override onlyOwner {}

    /**
     * @dev Restrict rules management to the owner.
     */
    function _onlyRulesManager() internal view virtual override onlyOwner {}

    function _onlyRulesLimitManager() internal view virtual override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _msgSender() internal view virtual override(RuleWhitelistWrapperBase, Context) returns (address sender) {
        return RuleWhitelistWrapperBase._msgSender();
    }

    function _msgData() internal view virtual override(RuleWhitelistWrapperBase, Context) returns (bytes calldata) {
        return RuleWhitelistWrapperBase._msgData();
    }

    function _contextSuffixLength()
        internal
        view
        virtual
        override(RuleWhitelistWrapperBase, Context)
        returns (uint256)
    {
        return RuleWhitelistWrapperBase._contextSuffixLength();
    }
}
