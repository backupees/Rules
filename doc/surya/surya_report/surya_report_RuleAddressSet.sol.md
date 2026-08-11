## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/abstract/RuleAddressSet/RuleAddressSet.sol | c2543c2c217b102c9570518c3da2b96e4205d100 |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleAddressSet** | Implementation | MetaTxModuleStandalone, RuleAddressSetInvariantStorage, RuleAddressSetInternal, IAddressList |||
| └ | <Constructor> | Public ❗️ | 🛑  | MetaTxModuleStandalone |
| └ | addAddresses | Public ❗️ | 🛑  | onlyAddressListAdd |
| └ | removeAddresses | Public ❗️ | 🛑  | onlyAddressListRemove |
| └ | addAddress | Public ❗️ | 🛑  | onlyAddressListAdd |
| └ | removeAddress | Public ❗️ | 🛑  | onlyAddressListRemove |
| └ | listedAddressCount | Public ❗️ |   |NO❗️ |
| └ | contains | Public ❗️ |   |NO❗️ |
| └ | isAddressListed | Public ❗️ |   |NO❗️ |
| └ | areAddressesListed | Public ❗️ |   |NO❗️ |
| └ | _authorizeAddressListAdd | Internal 🔒 |   | |
| └ | _authorizeAddressListRemove | Internal 🔒 |   | |
| └ | _msgSender | Internal 🔒 |   | |
| └ | _msgData | Internal 🔒 |   | |
| └ | _contextSuffixLength | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
