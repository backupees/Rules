I want to have a rule which can be plugged directly to an erc-3643 token as a registry identity rule.

Only the required interface to be plugged to an erc-343 token must be implemented.

isVerified

registerIdentity

deleteIdentity

and _onchainID.keyHasPurpose(_key, 1) which will just return the result of isVerified

Under the hood, I want a whitelist system where register identity whitlist an anddress and delete identity remove from the whitelist

In the rule, talk about limitation notably regarding recoveryAddress and _onchainID.keyHasPurpose

Create test with the erc-3643 token with at least the function recoveryAddress, transfer, forcedTransfer burn and mint.

In the rule doc, explain also which erc-3643 function call the registry identity contract and how (summary tab)