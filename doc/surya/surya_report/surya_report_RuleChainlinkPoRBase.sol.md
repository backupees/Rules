## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/abstract/base/RuleChainlinkPoRBase.sol | 7191fb609d8e2b6551f97bf80c24c3afc91bf268 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleChainlinkPoRBase** | Implementation | RuleTransferValidation, RuleChainlinkPoRInvariantStorage |||
| └ | <Constructor> | Public ❗️ | 🛑  |NO❗️ |
| └ | canReturnTransferRestrictionCode | External ❗️ |   |NO❗️ |
| └ | setReservesFeed | Public ❗️ | 🛑  | onlyChainlinkPoRManager |
| └ | setTokenMetadata | Public ❗️ | 🛑  | onlyChainlinkPoRManager |
| └ | setMaxStalenessSeconds | Public ❗️ | 🛑  | onlyChainlinkPoRManager |
| └ | feedDecimals | Public ❗️ |   |NO❗️ |
| └ | maxBackedSupply | Public ❗️ |   |NO❗️ |
| └ | transferred | Public ❗️ |   |NO❗️ |
| └ | transferred | Public ❗️ |   |NO❗️ |
| └ | messageForTransferRestriction | Public ❗️ |   |NO❗️ |
| └ | _setReservesFeed | Internal 🔒 | 🛑  | |
| └ | _setTokenMetadata | Internal 🔒 | 🛑  | |
| └ | _setMaxStalenessSeconds | Internal 🔒 | 🛑  | |
| └ | _authorizeChainlinkPoRManager | Internal 🔒 |   | |
| └ | _maxBackedSupply | Internal 🔒 |   | |
| └ | _currentSupply | Internal 🔒 |   | |
| └ | _scaleReserve | Internal 🔒 |   | |
| └ | _detectTransferRestriction | Internal 🔒 |   | |
| └ | _detectTransferRestrictionFrom | Internal 🔒 |   | |
| └ | _transferred | Internal 🔒 |   | |
| └ | _transferredFrom | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
