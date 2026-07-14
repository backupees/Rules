## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/deployment/RuleBlacklistOwnable2Step.sol | d1d803fa9f1f3db0a21ef8cde1b9a96e910cd728 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleBlacklistOwnable2Step** | Implementation | RuleBlacklistBase, Ownable2Step, Ownable2StepERC165Module |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleBlacklistBase Ownable |
| └ | _authorizeAddressListAdd | Internal 🔒 |   | onlyOwner |
| └ | _authorizeAddressListRemove | Internal 🔒 |   | onlyOwner |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _msgSender | Internal 🔒 |   | |
| └ | _msgData | Internal 🔒 |   | |
| └ | _contextSuffixLength | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
