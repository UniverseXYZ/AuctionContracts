### Build the project

Run:

```
$ yarn
$ cp .envrc.example .envrc
$ source .envrc
$ yarn compile
```

### Run Tests

```
$ npx hardhat test
```

### Deploy to Ganache

```
$ ./start_ganache.sh
$ yarn deploy ganache
```

### Deploy to live networks

Edit .envrc.example then copy it to .envrc

```
$ cp .envrc.example .envrc
$ source .envrc
```

Make sure to update the enviroment variables with suitable values.

Now enable the env vars using [direnv](https://direnv.net/docs/installation.html)

```
$ eval "$(direnv hook bash)"
$ direnv allow
```

Deploy to a network:

```
$ yarn deploy rinkeby
```

### Verify smart contract on etherscan

To verify the deployed contract run:

```
$ yarn etherscan-verify rinkeby --address
```

### Gas cost estimation

To get a gas estimation for deployment of contracts and functions calls, the `REPORT_GAS` env variable must be set to true. To estimate with certaing gas price update the hardhat.config.js file. Gas estimation happens during test, only functions specified in tests will get an estimation. run with:

```
$ yarn test
```

### Rinkeby deployments

UniverseAuctionHouse - https://rinkeby.etherscan.io/address/0x3d90D27a60A797b03fCb1EB880A561d0a6824131
UniverseERC721Factory - https://rinkeby.etherscan.io/address/0x8FA0DE9247540765A34151d15afDfb1eAE7C6083
UniverseERC721 - https://rinkeby.etherscan.io/address/0x84Df341f24728535c9559523E03a62F5c49C6415
UniverseERC721Core - https://rinkeby.etherscan.io/address/0x1eb634A2719781a33686E6AeBAc05F240Ef2a3ae