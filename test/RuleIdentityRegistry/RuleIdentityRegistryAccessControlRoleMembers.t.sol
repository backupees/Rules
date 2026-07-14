// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {
    AccessControlEnumerableTestBase,
    IAccessControlEnumerableLike
} from "../utils/AccessControlEnumerableTestBase.sol";
import {RuleIdentityRegistry} from "src/rules/validation/deployment/RuleIdentityRegistry.sol";

contract RuleIdentityRegistryAccessControlRoleMembers is AccessControlEnumerableTestBase {
    function _deployAccessControl() internal override returns (IAccessControlEnumerableLike, address) {
        address adminAddr = DEFAULT_ADMIN_ADDRESS;
        RuleIdentityRegistry rule = new RuleIdentityRegistry(adminAddr, ADDRESS1, false, false);
        return (IAccessControlEnumerableLike(address(rule)), adminAddr);
    }

    function testRoleMembers() public {
        address[] memory singleAdmin = new address[](1);
        singleAdmin[0] = admin;

        _assertRoleMembers(DEFAULT_ADMIN_ROLE, singleAdmin);
    }
}
