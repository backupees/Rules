// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

/**
 * @title TotalSupplyDecimalsMock — test double exposing a settable total supply and fixed decimals.
 * @notice Same as {TotalSupplyMock} but it also implements `decimals()`, so the decimals
 * cross-check performed when configuring a rule can be exercised.
 */
contract TotalSupplyDecimalsMock {
    uint256 private _totalSupply;
    uint8 private immutable _DECIMALS;

    /**
     * @notice Deploys the mock with the given decimals and a zero total supply.
     * @param decimals_ Decimals reported by the token.
     */
    constructor(uint8 decimals_) {
        _DECIMALS = decimals_;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the total supply value.
     * @param newTotalSupply The new total supply to store.
     */
    function setTotalSupply(uint256 newTotalSupply) external {
        _totalSupply = newTotalSupply;
    }

    /**
     * @notice Returns the stored total supply.
     * @return The current total supply value.
     */
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @notice Returns the stored decimals.
     * @return The current decimals value.
     */
    function decimals() external view returns (uint8) {
        return _DECIMALS;
    }
}
