### Build the project

Run:

```
$ yarn
$ cp .envrc.example .envrc
$ source .envrc
$ yarn compile
```

### Deploy to Ganache
```
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
