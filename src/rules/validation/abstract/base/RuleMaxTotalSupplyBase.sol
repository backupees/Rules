// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {RuleMaxTotalSupplyInvariantStorage} from "../invariant/RuleMaxTotalSupplyInvariantStorage.sol";
import {IERC1404, IERC1404Extend} from "CMTAT/interfaces/tokenization/draft-IERC1404.sol";
import {ITotalSupply} from "../../../interfaces/ITotalSupply.sol";
import {IERC3643IComplianceContract} from "CMTAT/interfaces/tokenization/IERC3643Partial.sol";
import {IRuleEngine} from "CMTAT/interfaces/engine/IRuleEngine.sol";
import {RuleTransferValidation} from "../core/RuleTransferValidation.sol";

/**
 * @title RuleMaxTotalSupplyBase
 * @notice Restricts minting so that total supply never exceeds a maximum value.
 */
abstract contract RuleMaxTotalSupplyBase is RuleTransferValidation, RuleMaxTotalSupplyInvariantStorage {
    /**
     * @dev tokenContract is trusted to report an *accurate* totalSupply -- nothing on-chain can
     * verify that -- but it is NOT trusted to stay callable: a reverting or codeless token yields
     * {CODE_SUPPLY_ORACLE_UNAVAILABLE} instead of reverting the MUST-NOT-revert views.
     */
    ITotalSupply public tokenContract;
    /**
     * @notice Maximum total supply; minting that would exceed this value is rejected.
     */
    uint256 public maxTotalSupply;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the rule with the token to observe and the supply cap.
     * @param tokenContract_ Address of the token whose `totalSupply` is checked; must not be the zero address.
     * @param maxTotalSupply_ Maximum total supply allowed.
     */
    constructor(address tokenContract_, uint256 maxTotalSupply_) {
        _validateTokenContract(tokenContract_);
        tokenContract = ITotalSupply(tokenContract_);
        maxTotalSupply = maxTotalSupply_;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether this rule can produce the given restriction code.
     * @param restrictionCode Restriction code to test.
     * @return True if `restrictionCode` is the max-total-supply-exceeded code.
     */
    function canReturnTransferRestrictionCode(uint8 restrictionCode) external pure override returns (bool) {
        return restrictionCode == CODE_MAX_TOTAL_SUPPLY_EXCEEDED || restrictionCode == CODE_SUPPLY_ORACLE_UNAVAILABLE;
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the maximum total supply.
     * @param newMaxTotalSupply New maximum total supply value.
     */
    function setMaxTotalSupply(uint256 newMaxTotalSupply) public onlyMaxTotalSupplyManager {
        maxTotalSupply = newMaxTotalSupply;
        emit MaxTotalSupplyUpdated(newMaxTotalSupply);
    }

    /**
     * @notice Updates the token contract whose total supply is checked.
     * @param newTokenContract New token contract address; must not be the zero address.
     */
    function setTokenContract(address newTokenContract) public onlyMaxTotalSupplyManager {
        _validateTokenContract(newTokenContract);
        tokenContract = ITotalSupply(newTokenContract);
        emit TokenContractUpdated(newTokenContract);
    }

    /**
     * @inheritdoc IERC3643IComplianceContract
     */
    function transferred(address from, address to, uint256 value) public view override(IERC3643IComplianceContract) {
        _transferred(from, to, value);
    }

    /**
     * @inheritdoc IRuleEngine
     */
    function transferred(address spender, address from, address to, uint256 value) public view override(IRuleEngine) {
        _transferredFrom(spender, from, to, value);
    }

    /**
     * @inheritdoc IERC1404
     */
    function messageForTransferRestriction(uint8 restrictionCode)
        public
        pure
        override(IERC1404)
        returns (string memory)
    {
        if (restrictionCode == CODE_MAX_TOTAL_SUPPLY_EXCEEDED) {
            return TEXT_MAX_TOTAL_SUPPLY_EXCEEDED;
        } else if (restrictionCode == CODE_SUPPLY_ORACLE_UNAVAILABLE) {
            return TEXT_SUPPLY_ORACLE_UNAVAILABLE;
        }
        return TEXT_CODE_NOT_FOUND;
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    modifier onlyMaxTotalSupplyManager() {
        _authorizeMaxTotalSupplyManager();
        _;
    }

    /**
     * @notice Authorization hook invoked before updating the max total supply or token contract.
     */
    function _authorizeMaxTotalSupplyManager() internal view virtual;

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates a candidate token contract before it is stored.
     * @dev `totalSupply()` is mandatory -- the cap check cannot work without it -- so it is probed
     * here, turning what would otherwise be a silent read-path failure into a named configuration
     * error. The code-length check is explicit rather than relying on the uncatchable extcodesize
     * revert that the probe would incidentally produce.
     * @param candidate The token contract to validate.
     */
    function _validateTokenContract(address candidate) internal view virtual {
        require(candidate != address(0), RuleMaxTotalSupply_TokenAddressZeroNotAllowed());
        require(candidate.code.length != 0, RuleMaxTotalSupply_TokenIsNotAContract(candidate));
        try ITotalSupply(candidate).totalSupply() returns (uint256) {}
        catch {
            revert RuleMaxTotalSupply_TokenTotalSupplyUnavailable(candidate);
        }
    }

    /**
     * @notice Reads the tracked token's current total supply.
     * @dev Wrapped in `try/catch` so the ERC-1404 read path stays revert-free if the token breaks
     * after configuration -- a proxy upgraded to something that reverts, or a pausable
     * implementation that reverts while paused. Configuration already probes `totalSupply()`, so
     * reaching the failure branch means the token changed behaviour since.
     *
     * No code-length check here: `_validateTokenContract` requires code, and EIP-6780 (Cancun)
     * makes that permanent, so the token cannot become codeless afterwards. A `try` to a codeless
     * address would revert *uncatchably*, so this reasoning assumes a Cancun-or-later chain.
     * @return available True when the supply could be read.
     * @return supply The total supply; meaningless when `available` is false.
     */
    function _currentSupply() internal view virtual returns (bool available, uint256 supply) {
        ITotalSupply token = tokenContract;
        try token.totalSupply() returns (uint256 totalSupply_) {
            return (true, totalSupply_);
        } catch {
            return (false, 0);
        }
    }

    /**
     * @inheritdoc RuleTransferValidation
     */
    function _detectTransferRestriction(
        address from,
        address,
        /* to */
        uint256 value
    )
        internal
        view
        virtual
        override
        returns (uint8)
    {
        if (from == address(0)) {
            (bool supplyAvailable, uint256 currentSupply) = _currentSupply();
            if (!supplyAvailable) {
                return CODE_SUPPLY_ORACLE_UNAVAILABLE;
            }
            // Overflow-safe: `currentSupply + value` could exceed uint256 and this is a
            // MUST-NOT-revert ERC-1404/ERC-3643 view, so compare against the remaining headroom.
            if (currentSupply > maxTotalSupply || value > maxTotalSupply - currentSupply) {
                return CODE_MAX_TOTAL_SUPPLY_EXCEEDED;
            }
        }
        return uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK);
    }

    /**
     * @inheritdoc RuleTransferValidation
     */
    function _detectTransferRestrictionFrom(address, address from, address to, uint256 value)
        internal
        view
        virtual
        override
        returns (uint8)
    {
        return _detectTransferRestriction(from, to, value);
    }

    /**
     * @notice Enforces the max-total-supply restriction for a direct transfer, reverting on violation.
     * @param from Sender address; the zero address denotes a mint whose supply is checked.
     * @param to Recipient address.
     * @param value Transfer amount.
     */
    function _transferred(address from, address to, uint256 value) internal view virtual {
        uint8 code = _detectTransferRestriction(from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleMaxTotalSupply_InvalidTransfer(address(this), from, to, value, code)
        );
    }

    /**
     * @notice Enforces the max-total-supply restriction for a `transferFrom`, reverting on violation.
     * @param spender Approved spender initiating the transfer.
     * @param from Sender address; the zero address denotes a mint whose supply is checked.
     * @param to Recipient address.
     * @param value Transfer amount.
     */
    function _transferredFrom(address spender, address from, address to, uint256 value) internal view virtual {
        uint8 code = _detectTransferRestrictionFrom(spender, from, to, value);
        require(
            code == uint8(IERC1404Extend.REJECTED_CODE_BASE.TRANSFER_OK),
            RuleMaxTotalSupply_InvalidTransferFrom(address(this), spender, from, to, value, code)
        );
    }
}
