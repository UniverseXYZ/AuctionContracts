require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-etherscan');

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: '0.7.3',
  networks: {
    ganache: {
      url: 'HTTP://127.0.0.1:7545',
      accounts: ['$PRIVATE_KEY'],
    },
    ropsten: {
      chainId: 3,
      url: '$INFURA_API_KEY',
      accounts: ['$PRIVATE_KEY'],
    },
  },
  etherscan: {
    apiKey: '$ETHERSCAN_API_KEY',
  },
};
