## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/operation/abstract/RuleMintAllowanceBase.sol | 1676c17359978a8e901da2f022762462a44a7968 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleMintAllowanceBase** | Implementation | VersionModule, ERC3643ComplianceModule, RuleMintAllowanceInvariantStorage, IRule |||
| └ | _authorizeSetMintAllowance | Internal 🔒 |   | |
| └ | canReturnTransferRestrictionCode | External ❗️ |   |NO❗️ |
| └ | created | External ❗️ | 🛑  | onlyBoundToken |
| └ | destroyed | External ❗️ | 🛑  | onlyBoundToken |
| └ | setMintAllowance | Public ❗️ | 🛑  | onlyAllowanceOperator |
| └ | increaseMintAllowance | Public ❗️ | 🛑  | onlyAllowanceOperator |
| └ | decreaseMintAllowance | Public ❗️ | 🛑  | onlyAllowanceOperator |
| └ | bindToken | Public ❗️ | 🛑  | onlyComplianceManager |
| └ | messageForTransferRestriction | Public ❗️ |   |NO❗️ |
| └ | transferred | Public ❗️ | 🛑  | onlyBoundToken |
| └ | transferred | Public ❗️ | 🛑  | onlyBoundToken |
| └ | detectTransferRestriction | Public ❗️ |   |NO❗️ |
| └ | detectTransferRestrictionFrom | Public ❗️ |   |NO❗️ |
| └ | canTransfer | Public ❗️ |   |NO❗️ |
| └ | canTransferFrom | Public ❗️ |   |NO❗️ |
| └ | _detectTransferRestrictionFrom | Internal 🔒 |   | |
| └ | _transferred | Internal 🔒 | 🛑  | |
| └ | _transferredFrom | Internal 🔒 | 🛑  | |
| └ | _setMintAllowance | Internal 🔒 | 🛑  | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
