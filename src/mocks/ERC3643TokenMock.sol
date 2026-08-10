// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IERC734KeyHasPurpose, IIdentityRegistryERC3643} from "../registry/interfaces/IIdentityRegistryERC3643.sol";

/**
 * @title ERC3643TokenMock — a minimal ERC-3643 token reproducing the identity-registry call
 * sequences of the reference implementation.
 * @notice The registry-facing logic of `transfer`, `transferFrom`, `forcedTransfer`, `mint`, `burn`
 * and `recoveryAddress` is transcribed from ERC-3643's `Token.sol` (vendored at `lib/ERC-3643/`),
 * including the order of calls and the revert strings, so a registry that satisfies this mock
 * satisfies the real token.
 *
 * @dev Why a mock rather than the real `Token.sol`: the reference implementation imports
 * the ONCHAINID Solidity package (not vendored) and targets OpenZeppelin v4 upgradeable contracts, while
 * this repository vendors OZ v5 -- `Token.sol` does not compile in this build. The mock keeps the
 * registry interaction faithful and drops everything orthogonal to it: the compliance module,
 * pausing, and partial-freeze accounting. Balances and the agent role are real so the transfers
 * actually move value.
 *
 * WARNING: test scaffolding only. Not a compliant ERC-3643 token and not for production use.
 *
 * NOTE: the linter suppressions below are deliberate. This file's value is that it mirrors
 * `Token.sol` closely enough to review side by side, so it keeps the reference parameter names and
 * the plain `keccak256(abi.encode(...))` key derivation. That last point is load-bearing:
 * {IdentityRegistryWhitelistBase} derives the same key in assembly, and the integration tests only
 * prove the two agree because this side computes it the ordinary way. Rewriting it here would make
 * the cross-check circular.
 */
contract ERC3643TokenMock {
    IIdentityRegistryERC3643 public identityRegistry;

    mapping(address account => uint256 balance) public balanceOf;
    mapping(address account => bool isAgent) public isAgent;
    uint256 public totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event RecoverySuccess(address indexed lostWallet, address indexed newWallet, address indexed investorOnchainId);

    error ERC3643TokenMock_OnlyAgent();

    /**
     * @param identityRegistry_ The registry this token consults.
     * @param agent The address granted the agent role.
     */
    constructor(IIdentityRegistryERC3643 identityRegistry_, address agent) {
        identityRegistry = identityRegistry_;
        isAgent[agent] = true;
    }

    // forge-lint: disable-next-line(unwrapped-modifier-logic)
    modifier onlyAgent() {
        require(isAgent[msg.sender], ERC3643TokenMock_OnlyAgent());
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the identity registry, mirroring `Token.setIdentityRegistry`.
     * @param identityRegistry_ The new registry.
     */
    function setIdentityRegistry(IIdentityRegistryERC3643 identityRegistry_) external {
        identityRegistry = identityRegistry_;
    }

    /**
     * @notice Grants or revokes the agent role.
     * @param account The account to update.
     * @param status True to grant.
     */
    function setAgent(address account, bool status) external {
        isAgent[account] = status;
    }

    /**
     * @notice Transfers tokens; the recipient must be verified.
     * @dev `Token.transfer`: `if (isVerified(_to) && compliance.canTransfer(...))`. The compliance
     * leg is omitted here; the registry leg is identical.
     * @param _to Recipient.
     * @param _amount Amount to transfer.
     * @return True on success.
     */
    function transfer(address _to, uint256 _amount) external returns (bool) {
        require(_amount <= balanceOf[msg.sender], "Insufficient Balance");
        if (identityRegistry.isVerified(_to)) {
            _transfer(msg.sender, _to, _amount);
            return true;
        }
        revert("Transfer not possible");
    }

    /**
     * @notice Transfers tokens on behalf of `_from`; the recipient must be verified.
     * @dev `Token.transferFrom`. Allowance handling is omitted; the registry leg is identical.
     * @param _from Sender.
     * @param _to Recipient.
     * @param _amount Amount to transfer.
     * @return True on success.
     */
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool) {
        require(_amount <= balanceOf[_from], "Insufficient Balance");
        if (identityRegistry.isVerified(_to)) {
            _transfer(_from, _to, _amount);
            return true;
        }
        revert("Transfer not possible");
    }

    /**
     * @notice Agent-forced transfer; the recipient must still be verified.
     * @dev `Token.forcedTransfer`: bypasses freezes but NOT the registry check on `_to`.
     * @param _from Sender.
     * @param _to Recipient.
     * @param _amount Amount to transfer.
     * @return True on success.
     */
    function forcedTransfer(address _from, address _to, uint256 _amount) public onlyAgent returns (bool) {
        require(balanceOf[_from] >= _amount, "sender balance too low");
        if (identityRegistry.isVerified(_to)) {
            _transfer(_from, _to, _amount);
            return true;
        }
        revert("Transfer not possible");
    }

    /**
     * @notice Mints tokens; the recipient must be verified.
     * @dev `Token.mint`: `require(isVerified(_to), "Identity is not verified.")`.
     * @param _to Recipient.
     * @param _amount Amount to mint.
     */
    function mint(address _to, uint256 _amount) external onlyAgent {
        require(identityRegistry.isVerified(_to), "Identity is not verified.");
        balanceOf[_to] += _amount;
        totalSupply += _amount;
        emit Transfer(address(0), _to, _amount);
    }

    /**
     * @notice Burns tokens.
     * @dev `Token.burn` makes **no** registry call: a de-listed holder can still be burned out.
     * @param _userAddress Holder to burn from.
     * @param _amount Amount to burn.
     */
    function burn(address _userAddress, uint256 _amount) external onlyAgent {
        require(balanceOf[_userAddress] >= _amount, "cannot burn more than balance");
        balanceOf[_userAddress] -= _amount;
        totalSupply -= _amount;
        emit Transfer(_userAddress, address(0), _amount);
    }

    /**
     * @notice Moves an investor's position to a replacement wallet.
     * @dev Transcribed from `Token.recoveryAddress`, preserving the order that matters:
     *      1. `keyHasPurpose(keccak256(abi.encode(_newWallet)), 1)` on the **caller-supplied**
     *         `_investorOnchainID` -- reverts "Recovery not possible" when false;
     *      2. `investorCountry(_lostWallet)` read from the registry;
     *      3. `registerIdentity(_newWallet, _investorOnchainID, country)` -- called BY THE TOKEN;
     *      4. `forcedTransfer(_lostWallet, _newWallet, balance)`;
     *      5. `deleteIdentity(_lostWallet)` -- also called BY THE TOKEN.
     * @param _lostWallet The wallet to recover from.
     * @param _newWallet The replacement wallet.
     * @param _investorOnchainID The contract answering `keyHasPurpose`.
     * @return True on success.
     */
    // forge-lint: disable-next-line(mixed-case-variable)
    function recoveryAddress(address _lostWallet, address _newWallet, address _investorOnchainID)
        external
        onlyAgent
        returns (bool)
    {
        require(balanceOf[_lostWallet] != 0, "no tokens to recover");
        // forge-lint: disable-next-line(asm-keccak256)
        bytes32 _key = keccak256(abi.encode(_newWallet));
        if (IERC734KeyHasPurpose(_investorOnchainID).keyHasPurpose(_key, 1)) {
            uint256 investorTokens = balanceOf[_lostWallet];
            identityRegistry.registerIdentity(
                _newWallet, _investorOnchainID, identityRegistry.investorCountry(_lostWallet)
            );
            forcedTransfer(_lostWallet, _newWallet, investorTokens);
            identityRegistry.deleteIdentity(_lostWallet);
            emit RecoverySuccess(_lostWallet, _newWallet, _investorOnchainID);
            return true;
        }
        revert("Recovery not possible");
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Moves value between two balances.
     * @param from Sender.
     * @param to Recipient.
     * @param amount Amount to move.
     */
    function _transfer(address from, address to, uint256 amount) internal {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}
