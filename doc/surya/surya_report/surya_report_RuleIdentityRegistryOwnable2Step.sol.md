## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/deployment/RuleIdentityRegistryOwnable2Step.sol | 99b6856a407f4a428a54b05ff817868f1d74e909 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleIdentityRegistryOwnable2Step** | Implementation | RuleIdentityRegistryBase, Ownable2Step, Ownable2StepERC165Module |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleIdentityRegistryBase Ownable |
| └ | _authorizeIdentityRegistryManager | Internal 🔒 |   | onlyOwner |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
