## Sūrya's Description Report

### Files Description Table


|  File Name  |  SHA-1 Hash  |
|-------------|--------------|
| ./mocks/harness/VirtualHookOverrideHarnesses.sol | 6854c56840f080b9c00452015062e74992314b8b |


### Contracts Description Table


|  Contract  |         Type        |       Bases      |                  |                 |
|:----------:|:-------------------:|:----------------:|:----------------:|:---------------:|
|     └      |  **Function Name**  |  **Visibility**  |  **Mutability**  |  **Modifiers**  |
||||||
| **ConditionalTransferLightCustomExecutorHarness** | Implementation | RuleConditionalTransferLight |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleConditionalTransferLight |
| └ | _authorizeTransferExecution | Internal 🔒 |   | |
| └ | approveTransfer | Public ❗️ | 🛑  |NO❗️ |
| └ | transferred | Public ❗️ | 🛑  |NO❗️ |
||||||
| **MaxTotalSupplyCappedSetterHarness** | Implementation | RuleMaxTotalSupply |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleMaxTotalSupply |
| └ | setMaxTotalSupply | Public ❗️ | 🛑  |NO❗️ |
||||||
| **IdentityRegistryPinnedHarness** | Implementation | RuleIdentityRegistry |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleIdentityRegistry |
| └ | setIdentityRegistry | Public ❗️ | 🛑  |NO❗️ |
||||||
| **ERC2980SelfWhitelistBlockHarness** | Implementation | RuleERC2980 |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleERC2980 |
| └ | addWhitelistAddress | Public ❗️ | 🛑  |NO❗️ |
||||||
| **BlacklistQuarantineHarness** | Implementation | RuleBlacklist |||
| └ | <Constructor> | Public ❗️ | 🛑  | RuleBlacklist |
| └ | _detectTransferRestriction | Internal 🔒 |   | |
| └ | _detectTransferRestrictionFrom | Internal 🔒 |   | |
| └ | canTransfer | Public ❗️ |   |NO❗️ |
| └ | canTransfer | Public ❗️ |   |NO❗️ |
| └ | addAddress | Public ❗️ | 🛑  |NO❗️ |


### Legend

|  Symbol  |  Meaning  |
|:--------:|-----------|
|    🛑    | Function can modify state |
|    💵    | Function is payable |
