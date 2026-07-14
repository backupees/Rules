## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/operation/RuleConditionalTransferLightMultiTokenOwnable2Step.sol | 3da3c69fd927f5e21b6881156369ff3c7957af38 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleConditionalTransferLightMultiTokenOwnable2Step** | Implementation | RuleConditionalTransferLightMultiTokenBase, Ownable2Step, Ownable2StepERC165Module |||
| └ | <Constructor> | Public ❗️ | 🛑  | Ownable |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _authorizeTransferApproval | Internal 🔒 |   | onlyOwner |
| └ | _onlyComplianceManager | Internal 🔒 | 🛑  | onlyOwner |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
