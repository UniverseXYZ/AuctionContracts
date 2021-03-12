require('@nomiclabs/hardhat-waffle');

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
            accounts: ['private_key'],
        },
        ropsten: {
            chainId: 3,
            url:
                'https://ropsten.infura.io/v3/e49086a14af041ee82be935ea2da4d12',
            accounts: ['private_key'],
        },
    },
};
