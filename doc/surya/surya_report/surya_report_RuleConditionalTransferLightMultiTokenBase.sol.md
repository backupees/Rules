## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol | 005bde36fdb674f7b60284457c9206700fe85387 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleConditionalTransferLightMultiTokenBase** | Implementation | VersionModule, ERC3643ComplianceModule, RuleConditionalTransferLightMultiTokenInvariantStorage, IRule |||
| └ | _authorizeTransferApproval | Internal 🔒 |   | |
| └ | canReturnTransferRestrictionCode | External ❗️ |   |NO❗️ |
| └ | messageForTransferRestriction | External ❗️ |   |NO❗️ |
| └ | created | External ❗️ | 🛑  | onlyBoundToken |
| └ | destroyed | External ❗️ | 🛑  | onlyBoundToken |
| └ | approveTransfer | Public ❗️ | 🛑  | onlyTransferApprover |
| └ | cancelTransferApproval | Public ❗️ | 🛑  | onlyTransferApprover |
| └ | approvedCount | Public ❗️ |   |NO❗️ |
| └ | approveAndTransferIfAllowed | Public ❗️ | 🛑  | onlyTransferApprover |
| └ | transferred | Public ❗️ | 🛑  | onlyTransferExecutor |
| └ | transferred | Public ❗️ | 🛑  | onlyTransferExecutor |
| └ | transferred | External ❗️ | 🛑  | onlyTransferExecutor |
| └ | detectTransferRestriction | Public ❗️ |   |NO❗️ |
| └ | detectTransferRestrictionFrom | Public ❗️ |   |NO❗️ |
| └ | canTransfer | Public ❗️ |   |NO❗️ |
| └ | canTransferFrom | Public ❗️ |   |NO❗️ |
| └ | _authorizeTransferExecution | Internal 🔒 |   | |
| └ | _authorizeComplianceBindingChange | Internal 🔒 | 🛑  | |
| └ | _approveTransfer | Internal 🔒 | 🛑  | |
| └ | _cancelTransferApproval | Internal 🔒 | 🛑  | |
| └ | _transferred | Internal 🔒 | 🛑  | |
| └ | _transferHash | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
