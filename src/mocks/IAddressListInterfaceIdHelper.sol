// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IAddressList} from "../rules/interfaces/IAddressList.sol";
import {IIdentityRegistryContains} from "../rules/interfaces/IIdentityRegistry.sol";
import {AddressListInterfaceId} from "../rules/interfaces/library/AddressListInterfaceId.sol";

/**
 * @title IAddressListAllFunctions
 * @dev Flattened interface containing ALL functions from the {IAddressList} hierarchy.
 *      Used to compute the full ERC-165 interface ID (XOR of all selectors).
 *
 *      `type(IAddressList).interfaceId` only covers the functions declared directly on
 *      `IAddressList` and OMITS `contains(address)`, which is inherited from
 *      `IIdentityRegistryContains`. `type(IAddressListAllFunctions).interfaceId` covers
 *      the full hierarchy and is the value stored in {AddressListInterfaceId}.
 */
interface IAddressListAllFunctions {
    /* ==== From IAddressList ==== */
    function addAddresses(address[] calldata targetAddresses) external;
    function removeAddresses(address[] calldata targetAddresses) external;
    function addAddress(address targetAddress) external;
    function removeAddress(address targetAddress) external;
    function listedAddressCount() external view returns (uint256 count);
    function isAddressListed(address targetAddress) external view returns (bool isListed);
    function areAddressesListed(address[] memory targetAddresses) external view returns (bool[] memory results);
    /* ==== From IIdentityRegistryContains ==== */
    function contains(address _userAddress) external view returns (bool);
}

/**
 * @title IAddressListInterfaceIdHelper
 * @dev Helper contract exposing the {IAddressList} interface IDs so the pre-computed constant
 *      can be verified in tests.
 */
contract IAddressListInterfaceIdHelper {
    /**
     * @notice Returns `type(IAddressList).interfaceId` — INCOMPLETE, omits inherited selectors.
     */
    function getIAddressListInterfaceId() external pure returns (bytes4) {
        return type(IAddressList).interfaceId;
    }

    /**
     * @notice Returns the XOR of ALL selectors in the {IAddressList} hierarchy (flattened).
     */
    function getIAddressListAllFunctionsInterfaceId() external pure returns (bytes4) {
        return type(IAddressListAllFunctions).interfaceId;
    }

    /**
     * @notice Returns the constant defined in the {AddressListInterfaceId} library.
     */
    function getAddressListInterfaceIdConstant() external pure returns (bytes4) {
        return AddressListInterfaceId.IADDRESS_LIST_INTERFACE_ID;
    }

    /**
     * @notice Returns the interface ID of the inherited parent interface.
     */
    function getIIdentityRegistryContainsInterfaceId() external pure returns (bytes4) {
        return type(IIdentityRegistryContains).interfaceId;
    }
}
