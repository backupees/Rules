## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./registry/abstract/IdentityRegistryWhitelistBase.sol | 7d8ecb5618c360d59487a59c4e8bff48743b8ebe |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **IdentityRegistryWhitelistBase** | Implementation | RuleAddressSetInternal, VersionModule, IIdentityRegistryERC3643, IdentityRegistryWhitelistInvariantStorage |||
| └ | registerIdentity | External ❗️ | 🛑  | onlyIdentityRegistrar |
| └ | deleteIdentity | External ❗️ | 🛑  | onlyIdentityRegistrar |
| └ | registeredIdentityCount | External ❗️ |   |NO❗️ |
| └ | isVerified | Public ❗️ |   |NO❗️ |
| └ | investorCountry | Public ❗️ |   |NO❗️ |
| └ | _authorizeIdentityRegistrar | Internal 🔒 |   | |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
