// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

/**
 * @title AddressListInterfaceId
 * @dev ERC-165 interface ID for the full {IAddressList} hierarchy (XOR of all function selectors).
 *
 *      `type(IAddressList).interfaceId` CANNOT be used: it XORs only the selectors declared directly
 *      on `IAddressList` and omits `contains(address)`, inherited from `IIdentityRegistryContains`.
 *      This constant is computed from the flattened `IAddressListAllFunctions` interface instead.
 *
 *      See src/mocks/IAddressListInterfaceIdHelper.sol; the value is asserted by
 *      test/InterfaceId/AddressListInterfaceId.t.sol.
 */
library AddressListInterfaceId {
    /**
     * @notice ERC-165 interface ID of the full {IAddressList} hierarchy.
     */
    bytes4 public constant IADDRESS_LIST_INTERFACE_ID = 0x5d10e182;
}
