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
