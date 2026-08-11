## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/operation/abstract/RuleConditionalTransferLightMultiTokenBase.sol | 4c0a662b90c8970466b03455b1f71be2b3f22a2f |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleConditionalTransferLightMultiTokenBase** | Implementation | VersionModule, ERC3643ComplianceModule, RuleConditionalTransferLightMultiTokenInvariantStorage, IRule |||
| └ | created | External ❗️ | 🛑  | onlyBoundToken |
| └ | destroyed | External ❗️ | 🛑  | onlyBoundToken |
| └ | transferred | External ❗️ | 🛑  | onlyTransferExecutor |
| └ | canReturnTransferRestrictionCode | External ❗️ |   |NO❗️ |
| └ | messageForTransferRestriction | External ❗️ |   |NO❗️ |
| └ | approveTransfer | Public ❗️ | 🛑  | onlyTransferApprover |
| └ | cancelTransferApproval | Public ❗️ | 🛑  | onlyTransferApprover |
| └ | approveAndTransferIfAllowed | Public ❗️ | 🛑  | onlyTransferApprover |
| └ | transferred | Public ❗️ | 🛑  | onlyTransferExecutor |
| └ | transferred | Public ❗️ | 🛑  | onlyTransferExecutor |
| └ | resetApproval | Public ❗️ | 🛑  | onlyTransferApprover |
| └ | approvedCount | Public ❗️ |   |NO❗️ |
| └ | detectTransferRestriction | Public ❗️ |   |NO❗️ |
| └ | detectTransferRestrictionForToken | Public ❗️ |   |NO❗️ |
| └ | canTransferForToken | Public ❗️ |   |NO❗️ |
| └ | detectTransferRestrictionFrom | Public ❗️ |   |NO❗️ |
| └ | canTransfer | Public ❗️ |   |NO❗️ |
| └ | canTransferFrom | Public ❗️ |   |NO❗️ |
| └ | _authorizeComplianceBindingChange | Internal 🔒 | 🛑  | |
| └ | _approveTransfer | Internal 🔒 | 🛑  | |
| └ | _cancelTransferApproval | Internal 🔒 | 🛑  | |
| └ | _transferred | Internal 🔒 | 🛑  | |
| └ | _detectTransferRestrictionForToken | Internal 🔒 |   | |
| └ | _authorizeTransferExecution | Internal 🔒 |   | |
| └ | _authorizeTransferApproval | Internal 🔒 |   | |
| └ | _transferHash | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
