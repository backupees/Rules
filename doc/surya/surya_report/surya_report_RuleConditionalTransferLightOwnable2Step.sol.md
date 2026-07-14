## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/operation/RuleConditionalTransferLightOwnable2Step.sol | e94c0dc5da33a08b1438eed005fffaf59d213def |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleConditionalTransferLightOwnable2Step** | Implementation | RuleConditionalTransferLightBase, Ownable2Step, Ownable2StepERC165Module |||
| └ | <Constructor> | Public ❗️ | 🛑  | Ownable |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _authorizeTransferApproval | Internal 🔒 |   | onlyOwner |
| └ | _onlyComplianceManager | Internal 🔒 | 🛑  | onlyOwner |
| └ | _authorizeComplianceBindingChange | Internal 🔒 |   | onlyOwner |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
