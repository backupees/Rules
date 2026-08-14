## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/abstract/core/TotalSupplyCapManager.sol | 2ccec17348c8be7669d4241186fb870cc4069d8a |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **TotalSupplyCapManager** | Implementation | TokenSupplyReader, RuleMaxTotalSupplyInvariantStorage |||
| └ | setMaxTotalSupply | Public ❗️ | 🛑  | onlyMaxTotalSupplyManager |
| └ | setTokenContract | Public ❗️ | 🛑  | onlyMaxTotalSupplyManager |
| └ | _setMaxTotalSupply | Internal 🔒 | 🛑  | |
| └ | _setTokenContract | Internal 🔒 | 🛑  | |
| └ | _validateTokenContract | Internal 🔒 |   | |
| └ | _authorizeMaxTotalSupplyManager | Internal 🔒 |   | |
| └ | _supplyToken | Internal 🔒 |   | |
| └ | _capExceeded | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
