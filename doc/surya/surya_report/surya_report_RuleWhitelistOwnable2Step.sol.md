## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/deployment/RuleWhitelistOwnable2Step.sol | 6c451cec10719b78b486fff1254daaf78d3c3a25 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleWhitelistOwnable2Step** | Implementation | RuleWhitelistBase, Ownable2Step, Ownable2StepERC165Module |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleWhitelistBase Ownable |
| └ | _authorizeAddressListAdd | Internal 🔒 |   | onlyOwner |
| └ | _authorizeAddressListRemove | Internal 🔒 |   | onlyOwner |
| └ | _authorizeCheckSpenderManager | Internal 🔒 |   | onlyOwner |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _msgSender | Internal 🔒 |   | |
| └ | _msgData | Internal 🔒 |   | |
| └ | _contextSuffixLength | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
