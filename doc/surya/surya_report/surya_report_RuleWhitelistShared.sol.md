## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/abstract/core/RuleWhitelistShared.sol | fb4d9b88fef733bf885a246ba9e4d13d65134dfd |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleWhitelistShared** | Implementation | RuleNFTAdapter, RuleWhitelistInvariantStorage |||
| └ | canReturnTransferRestrictionCode | External ❗️ |   |NO❗️ |
| └ | messageForTransferRestriction | External ❗️ |   |NO❗️ |
| └ | setAllowMint | Public ❗️ | 🛑  | onlyMintBurnManager |
| └ | setAllowBurn | Public ❗️ | 🛑  | onlyMintBurnManager |
| └ | transferred | Public ❗️ |   |NO❗️ |
| └ | transferred | Public ❗️ |   |NO❗️ |
| └ | _setAllowMintBurn | Internal 🔒 | 🛑  | |
| └ | _detectMintBurnRestriction | Internal 🔒 |   | |
| └ | _authorizeMintBurnManager | Internal 🔒 |   | |
| └ | _transferred | Internal 🔒 |   | |
| └ | _transferredFrom | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
