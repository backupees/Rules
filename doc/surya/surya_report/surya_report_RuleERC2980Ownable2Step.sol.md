## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/deployment/RuleERC2980Ownable2Step.sol | 059ea6668baf03d1ac9f3c7f3c85e2b09c01306f |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleERC2980Ownable2Step** | Implementation | RuleERC2980Base, Ownable2Step, Ownable2StepERC165Module |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleERC2980Base Ownable |
| └ | _authorizeWhitelistAdd | Internal 🔒 |   | onlyOwner |
| └ | _authorizeWhitelistRemove | Internal 🔒 |   | onlyOwner |
| └ | _authorizeFrozenlistAdd | Internal 🔒 |   | onlyOwner |
| └ | _authorizeFrozenlistRemove | Internal 🔒 |   | onlyOwner |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _msgSender | Internal 🔒 |   | |
| └ | _msgData | Internal 🔒 |   | |
| └ | _contextSuffixLength | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
