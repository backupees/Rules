## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/abstract/core/ChainlinkPoRFeedManager.sol | 4c296843d471b9cc60a86ef8253205dabbc45558 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **ChainlinkPoRFeedManager** | Implementation | TokenSupplyReader, RuleChainlinkPoRInvariantStorage |||
| └ | setReservesFeed | Public ❗️ | 🛑  | onlyChainlinkPoRManager |
| └ | setTokenMetadata | Public ❗️ | 🛑  | onlyChainlinkPoRManager |
| └ | setMaxStalenessSeconds | Public ❗️ | 🛑  | onlyChainlinkPoRManager |
| └ | feedDecimals | Public ❗️ |   |NO❗️ |
| └ | maxBackedSupply | Public ❗️ |   |NO❗️ |
| └ | _setReservesFeed | Internal 🔒 | 🛑  | |
| └ | _setTokenMetadata | Internal 🔒 | 🛑  | |
| └ | _setMaxStalenessSeconds | Internal 🔒 | 🛑  | |
| └ | _authorizeChainlinkPoRManager | Internal 🔒 |   | |
| └ | _maxBackedSupply | Internal 🔒 |   | |
| └ | _supplyToken | Internal 🔒 |   | |
| └ | _scaleReserve | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
