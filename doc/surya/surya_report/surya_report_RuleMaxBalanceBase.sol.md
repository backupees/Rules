## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/abstract/base/RuleMaxBalanceBase.sol | 4d9fdf01c4e28f0d9b58d2005b88269d91ebd3f6 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleMaxBalanceBase** | Implementation | RuleTransferValidation, RuleAddressSetInternal, RuleMaxBalanceInvariantStorage |||
| └ | <Constructor> | Public ❗️ | 🛑  |NO❗️ |
| └ | canReturnTransferRestrictionCode | External ❗️ |   |NO❗️ |
| └ | setMaxBalance | Public ❗️ | 🛑  | onlyMaxBalanceManager |
| └ | setBalanceToken | Public ❗️ | 🛑  | onlyMaxBalanceManager |
| └ | addExemptAddress | Public ❗️ | 🛑  | onlyMaxBalanceManager |
| └ | removeExemptAddress | Public ❗️ | 🛑  | onlyMaxBalanceManager |
| └ | addExemptAddresses | Public ❗️ | 🛑  | onlyMaxBalanceManager |
| └ | removeExemptAddresses | Public ❗️ | 🛑  | onlyMaxBalanceManager |
| └ | isExemptAddress | Public ❗️ |   |NO❗️ |
| └ | exemptAddressCount | Public ❗️ |   |NO❗️ |
| └ | remainingCapacity | Public ❗️ |   |NO❗️ |
| └ | transferred | Public ❗️ |   |NO❗️ |
| └ | transferred | Public ❗️ |   |NO❗️ |
| └ | messageForTransferRestriction | Public ❗️ |   |NO❗️ |
| └ | _addExemptAddress | Internal 🔒 | 🛑  | |
| └ | _removeExemptAddress | Internal 🔒 | 🛑  | |
| └ | _setMaxBalance | Internal 🔒 | 🛑  | |
| └ | _setBalanceToken | Internal 🔒 | 🛑  | |
| └ | _authorizeMaxBalanceManager | Internal 🔒 |   | |
| └ | _balanceOf | Internal 🔒 |   | |
| └ | _detectTransferRestriction | Internal 🔒 |   | |
| └ | _detectTransferRestrictionFrom | Internal 🔒 |   | |
| └ | _transferred | Internal 🔒 |   | |
| └ | _transferredFrom | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
