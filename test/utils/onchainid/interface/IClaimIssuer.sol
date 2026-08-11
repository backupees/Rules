// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IIdentity} from "./IIdentity.sol";

/**
 * @title IClaimIssuer — minimal stand-in for ONCHAINID's `IClaimIssuer`.
 * @notice Imported by ERC-3643's trusted-issuers registry interface. Within the compile set it is
 * used **only as a type** — in event parameters, function parameters and return arrays — never
 * called, so no members need declaring beyond those inherited from {IIdentity}.
 *
 * @dev See {IIdentity} for why these stubs exist and the remapping that wires them in.
 *
 * WARNING: not the real ONCHAINID interface. The genuine `IClaimIssuer` adds claim revocation and
 * signature validation. Do not import this outside the ERC-3643 build context.
 */
interface IClaimIssuer is IIdentity {}
