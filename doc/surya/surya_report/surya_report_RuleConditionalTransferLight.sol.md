## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/operation/RuleConditionalTransferLight.sol | 62dd5be103c29fa0ad3ec6ee371468a8e0edc01f |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleConditionalTransferLight** | Implementation | AccessControlModuleStandalone, RuleConditionalTransferLightBase, ERC3643ComplianceRolesStorage |||
| └ | <Constructor> | Public ❗️ | 🛑  | AccessControlModuleStandalone |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _authorizeTransferApproval | Internal 🔒 |   | onlyRole |
| └ | _onlyComplianceManager | Internal 🔒 | 🛑  | onlyRole |
| └ | _authorizeComplianceBindingChange | Internal 🔒 |   | onlyRole |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
