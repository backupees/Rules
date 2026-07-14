// SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

/**
 * @title AddressListInterfaceId
 * @dev ERC-165 interface ID for the full {IAddressList} hierarchy (XOR of all function selectors).
 *
 *      `type(IAddressList).interfaceId` CANNOT be used: it only XORs the selectors declared directly
 *      on `IAddressList` and omits `contains(address)`, inherited from `IIdentityRegistryContains`.
 *      This constant is computed from the flattened `IAddressListAllFunctions` interface instead.
 *
 *      Selectors XOR-ed:
 *        addAddresses(address[])        0x3628731c
 *        removeAddresses(address[])     0xa84eb999
 *        addAddress(address)            0x38eada1c
 *        removeAddress(address)         0x4ba79dfe
 *        listedAddressCount()           0x2ea5461d
 *        isAddressListed(address)       0xe3c88c6a
 *        areAddressesListed(address[])  0x20e8e17a
 *        contains(address)              0x5dbe47e8   <- inherited
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
