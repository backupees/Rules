## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/abstract/base/RuleMaxTotalSupplyBase.sol | 845a7ae5da778000d497759311cada4d802ff887 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleMaxTotalSupplyBase** | Implementation | RuleTransferValidation, RuleMaxTotalSupplyInvariantStorage |||
| └ | <Constructor> | Public ❗️ | 🛑  |NO❗️ |
| └ | canReturnTransferRestrictionCode | External ❗️ |   |NO❗️ |
| └ | setMaxTotalSupply | Public ❗️ | 🛑  | onlyMaxTotalSupplyManager |
| └ | setTokenContract | Public ❗️ | 🛑  | onlyMaxTotalSupplyManager |
| └ | transferred | Public ❗️ |   |NO❗️ |
| └ | transferred | Public ❗️ |   |NO❗️ |
| └ | messageForTransferRestriction | Public ❗️ |   |NO❗️ |
| └ | _authorizeMaxTotalSupplyManager | Internal 🔒 |   | |
| └ | _validateTokenContract | Internal 🔒 |   | |
| └ | _currentSupply | Internal 🔒 |   | |
| └ | _detectTransferRestriction | Internal 🔒 |   | |
| └ | _detectTransferRestrictionFrom | Internal 🔒 |   | |
| └ | _transferred | Internal 🔒 |   | |
| └ | _transferredFrom | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
