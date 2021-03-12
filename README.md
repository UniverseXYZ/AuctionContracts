### Setup dev envoirment

1. Open hardhat.config.js find out module.exports and inside look for networks object

2. Replace $PRIVATE_KEY in the array with your own private key

3. If network is different than ganache we need to replace $INFURA_API_KEY with our own

4. In package.json look for the deploy script and replace $NETWORK

5. Run: yarn deploy

### Verify smart contract

1. Open package.json and in etherscan-verify replace $NETWORK and $CONTRACT_ADDRESS

2. In hardhat.config.js go to etherscan in module.exports and replace $ETHERSCAN_API_KEY with your own
