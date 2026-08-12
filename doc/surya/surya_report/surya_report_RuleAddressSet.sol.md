## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./rules/validation/abstract/RuleAddressSet/RuleAddressSet.sol | 873e7ec6aa710f67defc0d61794233df402867ea |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **RuleAddressSet** | Implementation | MetaTxModuleStandalone, RuleAddressSetInvariantStorage, RuleAddressSetRolesStorage, RuleAddressSetInternal, IAddressList |||
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
