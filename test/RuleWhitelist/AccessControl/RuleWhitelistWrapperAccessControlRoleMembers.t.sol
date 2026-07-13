// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {
    AccessControlEnumerableTestBase,
    IAccessControlEnumerableLike
} from "../../utils/AccessControlEnumerableTestBase.sol";
import {RuleWhitelistWrapper} from "src/rules/validation/deployment/RuleWhitelistWrapper.sol";

contract RuleWhitelistWrapperAccessControlRoleMembers is AccessControlEnumerableTestBase {
    function _deployAccessControl() internal override returns (IAccessControlEnumerableLike, address) {
        address adminAddr = DEFAULT_ADMIN_ADDRESS;
        RuleWhitelistWrapper rule = new RuleWhitelistWrapper(adminAddr, ZERO_ADDRESS, true, true);
        return (IAccessControlEnumerableLike(address(rule)), adminAddr);
    }

    function testRoleMembers() public {
        address[] memory singleAdmin = new address[](1);
        singleAdmin[0] = admin;

        _assertRoleMembers(DEFAULT_ADMIN_ROLE, singleAdmin);
        _assertRoleMembers(RULES_MANAGEMENT_ROLE, new address[](0));
    }
}
