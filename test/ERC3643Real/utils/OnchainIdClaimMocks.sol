// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IIdentity} from "test/utils/onchainid/interface/IIdentity.sol";
import {IClaimIssuer} from "test/utils/onchainid/interface/IClaimIssuer.sol";

/**
 * @title OnchainIdClaimMocks
 * @notice Minimal ONCHAINID doubles, enough to drive the **real** ERC-3643 `IdentityRegistry`
 *         through its full `isVerified` path including claim validation.
 * @dev ONCHAINID is an npm package rather than a submodule, so it is not vendored (see
 *      `test/utils/onchainid/`). These mocks implement only what `IdentityRegistry.isVerified`
 *      actually calls: `getClaim` on the investor's identity, and `isClaimValid` on the trusted
 *      issuer of each required claim topic.
 *
 *      WARNING: these are NOT ONCHAINID. There is no key management, no signature verification and
 *      no revocation. They exist so the registry's *own* logic — identity lookup, claim-topic
 *      iteration, trusted-issuer resolution — runs for real; they are not a model of ONCHAINID
 *      behaviour and must not be used to reason about it.
 */

/**
 * @notice A claim issuer that accepts or rejects claims on command.
 */
contract ClaimIssuerMock is IClaimIssuer {
    /**
     * @notice When false, every claim this issuer signed is treated as invalid.
     */
    bool public claimsValid = true;

    function setClaimsValid(bool value) external {
        claimsValid = value;
    }

    /**
     * @inheritdoc IClaimIssuer
     */
    function isClaimValid(IIdentity, uint256, bytes calldata, bytes calldata) external view override returns (bool) {
        return claimsValid;
    }

    /**
     * @inheritdoc IIdentity
     */
    function keyHasPurpose(bytes32, uint256) external pure override returns (bool) {
        return true;
    }

    /**
     * @inheritdoc IIdentity
     */
    function getClaim(bytes32)
        external
        pure
        override
        returns (uint256, uint256, address, bytes memory, bytes memory, string memory)
    {
        return (0, 0, address(0), "", "", "");
    }
}

/**
 * @notice An investor identity holding one claim per topic, all from the same issuer.
 * @dev `IdentityRegistry.isVerified` looks a claim up by `keccak256(abi.encode(issuer, topic))`, so
 *      the mock stores claims under that key and returns topic `0` for anything it does not hold —
 *      which is what makes the registry treat the identity as failing that topic.
 */
contract OnchainIdClaimMock is IIdentity {
    struct Claim {
        uint256 topic;
        address issuer;
    }

    mapping(bytes32 claimId => Claim) private _claims;

    /**
     * @notice Grants this identity a claim on `topic` issued by `issuer`.
     */
    function addClaim(uint256 topic, address issuer) external {
        _claims[keccak256(abi.encode(issuer, topic))] = Claim({topic: topic, issuer: issuer});
    }

    /**
     * @notice Removes a claim, so the identity stops satisfying that topic.
     */
    function removeClaim(uint256 topic, address issuer) external {
        delete _claims[keccak256(abi.encode(issuer, topic))];
    }

    /**
     * @inheritdoc IIdentity
     */
    function getClaim(bytes32 claimId)
        external
        view
        override
        returns (uint256, uint256, address, bytes memory, bytes memory, string memory)
    {
        Claim memory c = _claims[claimId];
        return (c.topic, 1, c.issuer, "", "", "");
    }

    /**
     * @inheritdoc IIdentity
     */
    function keyHasPurpose(bytes32, uint256) external pure override returns (bool) {
        return true;
    }
}
