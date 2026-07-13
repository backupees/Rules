// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

/* ==== Abstract contracts === */
import {MetaTxModuleStandalone, ERC2771Context} from "../../../../modules/MetaTxModuleStandalone.sol";
import {RuleWhitelistShared} from "../core/RuleWhitelistShared.sol";
import {RuleTransferValidation} from "../core/RuleTransferValidation.sol";
/* ==== RuleEngine === */
import {RulesManagementModule} from "RuleEngine/modules/RulesManagementModule.sol";
/* ==== Interfaces === */
import {IAddressList} from "../../../interfaces/IAddressList.sol";
import {IIdentityRegistryVerified} from "../../../interfaces/IIdentityRegistry.sol";

/**
 * @title Wrapper to call several different whitelist rules (base)
 * @dev Child rules must implement {IAddressList}.
 */
abstract contract RuleWhitelistWrapperBase is
    RulesManagementModule,
    MetaTxModuleStandalone,
    RuleWhitelistShared,
    IIdentityRegistryVerified
{
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Deploys the whitelist wrapper base.
     * @param forwarderIrrevocable Address of the forwarder, required for the gasless support
     * @param checkSpender_ Whether to also verify the spender on delegated transfers.
     */
    constructor(address forwarderIrrevocable, bool checkSpender_) MetaTxModuleStandalone(forwarderIrrevocable) {
        checkSpender = checkSpender_;
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyCheckSpenderManager() {
        _authorizeCheckSpenderManager();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets whether the rule should enforce spender-based checks.
     * @dev
     *  - Restricted to holders of the manager role.
     *  - Updates the internal `checkSpender` flag.
     *  - Emits a {CheckSpenderUpdated} event.
     * @param value The new state of the `checkSpender` flag.
     */
    function setCheckSpender(bool value) public virtual onlyCheckSpenderManager {
        _setCheckSpender(value);
        emit CheckSpenderUpdated(value);
    }

    /**
     * @inheritdoc RuleTransferValidation
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(RuleTransferValidation) returns (bool) {
        return RuleTransferValidation.supportsInterface(interfaceId);
    }

    /**
     * @notice Returns true if the address is listed in at least one child whitelist rule.
     * @dev Delegates to the same child-rule scan used by transfer restriction checks.
     * @param targetAddress The address to check across all child whitelist rules.
     * @return True if the address is listed in at least one child rule.
     */
    function isVerified(address targetAddress) public view virtual override(IIdentityRegistryVerified) returns (bool) {
        address[] memory targets = new address[](1);
        targets[0] = targetAddress;
        bool[] memory result = _detectTransferRestrictionForTargets(targets);
        return result[0];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Authorizes the caller as check-spender manager; reverts otherwise.
     * @dev Implemented by concrete subclasses with the desired access-control policy.
     */
    function _authorizeCheckSpenderManager() internal virtual;

    /**
     * @notice Internal helper to update the `checkSpender` flag.
     * @param value New flag value.
     */
    function _setCheckSpender(bool value) internal virtual {
        checkSpender = value;
    }

    /**
     * @notice Go through all the whitelist rules to know if a restriction exists on the transfer
     * @param from the origin address
     * @param to the destination address
     * @return The restricion code or REJECTED_CODE_BASE.TRANSFER_OK
     *
     */
    function _detectTransferRestriction(
        address from,
        address to,
        uint256 /* value */
    )
        internal
        view
        virtual
        override
        returns (uint8)
    {
        address[] memory targetAddress = new address[](2);
        targetAddress[0] = from;
        targetAddress[1] = to;

        bool[] memory result = _detectTransferRestrictionForTargets(targetAddress);
        if (!result[0]) {
            return CODE_ADDRESS_FROM_NOT_WHITELISTED;
        } else if (!result[1]) {
            return CODE_ADDRESS_TO_NOT_WHITELISTED;
        } else {
            return uint8(REJECTED_CODE_BASE.TRANSFER_OK);
        }
    }

    /**
     * @notice Go through all the whitelist rules to know if a delegated transfer is restricted.
     * @param spender The delegated spender address.
     * @param from The origin address.
     * @param to The destination address.
     * @param value The amount transferred.
     * @return The restriction code or REJECTED_CODE_BASE.TRANSFER_OK.
     */
    function _detectTransferRestrictionFrom(address spender, address from, address to, uint256 value)
        internal
        view
        virtual
        override
        returns (uint8)
    {
        // Mint (from == address(0)) and burn (to == address(0)) are exempt from the spender check:
        // the minter/burner acts on its own authority, not as a delegated ERC-20 spender.
        if (!checkSpender || from == address(0) || to == address(0)) {
            return _detectTransferRestriction(from, to, value);
        }

        address[] memory targetAddress = new address[](3);
        targetAddress[0] = from;
        targetAddress[1] = to;
        targetAddress[2] = spender;

        bool[] memory result = _detectTransferRestrictionForTargets(targetAddress);

        if (!result[0]) {
            return CODE_ADDRESS_FROM_NOT_WHITELISTED;
        } else if (!result[1]) {
            return CODE_ADDRESS_TO_NOT_WHITELISTED;
        } else if (!result[2]) {
            return CODE_ADDRESS_SPENDER_NOT_WHITELISTED;
        } else {
            return uint8(REJECTED_CODE_BASE.TRANSFER_OK);
        }
    }

    // ERC-7943 tokenId overloads are provided by {RuleNFTAdapter} via RuleWhitelistShared.

    /**
     * @notice Reverts if a direct transfer is blocked by any child whitelist rule.
     * @param from The sender address.
     * @param to The recipient address.
     * @param value The amount transferred.
     */
    function _transferred(address from, address to, uint256 value)
        internal
        view
        virtual
        override(RulesManagementModule, RuleWhitelistShared)
    {
        RuleWhitelistShared._transferred(from, to, value);
    }

    /**
     * @notice Reverts if a delegated transfer is blocked by any child whitelist rule.
     * @param spender The delegated spender address.
     * @param from The sender address.
     * @param to The recipient address.
     * @param value The amount transferred.
     */
    function _transferred(address spender, address from, address to, uint256 value)
        internal
        view
        virtual
        override(RulesManagementModule)
    {
        RuleWhitelistShared._transferredFrom(spender, from, to, value);
    }

    /**
     * @notice Evaluates target addresses across all child rules.
     * @param targetAddress Addresses to validate (from/to[/spender]).
     * @return result Boolean array aligned with targetAddress indicating if each address is listed.
     */
    function _detectTransferRestrictionForTargets(address[] memory targetAddress)
        internal
        view
        virtual
        returns (bool[] memory)
    {
        uint256 rulesLength = rulesCount();
        bool[] memory result = new bool[](targetAddress.length);
        for (uint256 i = 0; i < rulesLength; ++i) {
            // Call the whitelist rules
            // Gas cost grows with the number of rules. Keep the wrapper list bounded.
            bool[] memory isListed = IAddressList(rule(i)).areAddressesListed(targetAddress);
            for (uint256 j = 0; j < targetAddress.length; ++j) {
                if (isListed[j]) {
                    result[j] = true;
                }
            }

            // Break early if all listed
            bool allListed = true;
            for (uint256 k = 0; k < result.length; ++k) {
                if (!result[k]) {
                    allListed = false;
                    break;
                }
            }
            if (allListed) {
                break;
            }
        }
        return result;
    }

    /*//////////////////////////////////////////////////////////////
                           ERC-2771
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev This surcharge is not necessary if you do not use the MetaTxModule
     * @return sender The effective message sender, unwrapped from the meta-transaction if present.
     */
    function _msgSender() internal view virtual override(ERC2771Context) returns (address sender) {
        return ERC2771Context._msgSender();
    }

    /**
     * @dev This surcharge is not necessary if you do not use the MetaTxModule
     * @return The effective calldata, unwrapped from the meta-transaction if present.
     */
    function _msgData() internal view virtual override(ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /**
     * @dev This surcharge is not necessary if you do not use the MetaTxModule
     * @return The length of the ERC-2771 context suffix appended to calldata.
     */
    function _contextSuffixLength() internal view virtual override(ERC2771Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
}
