## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/deployment/RuleSanctionsListOwnable2Step.sol | 0885c8f3fd637c7131ce04cc5a736b9acb60c616 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleSanctionsListOwnable2Step** | Implementation | RuleSanctionsListBase, Ownable2Step, Ownable2StepERC165Module |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleSanctionsListBase Ownable |
| └ | _authorizeSanctionListManager | Internal 🔒 |   | onlyOwner |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _msgSender | Internal 🔒 |   | |
| └ | _msgData | Internal 🔒 |   | |
| └ | _contextSuffixLength | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
