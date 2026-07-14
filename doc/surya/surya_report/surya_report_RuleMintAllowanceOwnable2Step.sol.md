## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/operation/RuleMintAllowanceOwnable2Step.sol | 32837216a0005192e2bfbe7a91ab7bd782a32238 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleMintAllowanceOwnable2Step** | Implementation | RuleMintAllowanceBase, Ownable2Step, Ownable2StepERC165Module |||
| └ | <Constructor> | Public ❗️ | 🛑  | Ownable |
| └ | supportsInterface | Public ❗️ |   |NO❗️ |
| └ | _authorizeSetMintAllowance | Internal 🔒 |   | onlyOwner |
| └ | _onlyComplianceManager | Internal 🔒 | 🛑  | onlyOwner |
| └ | _authorizeComplianceBindingChange | Internal 🔒 |   | onlyOwner |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
