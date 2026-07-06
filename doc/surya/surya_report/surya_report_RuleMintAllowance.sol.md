## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/operation/RuleMintAllowance.sol | 20af9da8f7f75bbedd817de955e768f9a716b54c |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleMintAllowance** | Implementation | AccessControlModuleStandalone, RuleMintAllowanceBase, ERC3643ComplianceRolesStorage |||
| └ | <Constructor> | Public ❗️ | 🛑  | AccessControlModuleStandalone |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _authorizeSetMintAllowance | Internal 🔒 |   | onlyRole |
| └ | _onlyComplianceManager | Internal 🔒 | 🛑  | onlyRole |
| └ | _authorizeComplianceBindingChange | Internal 🔒 |   | onlyRole |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
