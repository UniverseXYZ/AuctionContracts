Setup dev envoirment

1. Open hardhat.config.js and look for networks object
2. Replace private_key in the array with your own private key
3. In package.json we have a script which is used to deploy the smart contract execute: yarn deploy
4. To change the network where contract will be deployed we need to edit the script: "deploy": "npx hardhat run scripts/deploy.js --network ganache" we need to replace "ganache" with "ropsten" or whatever we have in the networks object located in the hardhat.config.js
