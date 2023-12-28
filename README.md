## [REDACTED] contracts

**This respository uses Foundry as development enviroment.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Install Foundry

https://book.getfoundry.sh/getting-started/installation

```shell
$ curl -L https://foundry.paradigm.xyz | bash
```

### Build the project

https://book.getfoundry.sh/reference/forge/build-commands

```shell
$ forge build
```

### Test

https://book.getfoundry.sh/reference/forge/forge-test

```shell
$ forge test
```

### Coverage

https://book.getfoundry.sh/reference/forge/forge-coverage?highlight=coverage#forge-coverage

```shell
$ forge coverage
```

Create a lcov.info file

```shell
$ forge coverage --report lcov
```

### Format

Run to format the files following the parameters in foundry.toml

```shell
$ forge fmt
```

### Deploy

https://book.getfoundry.sh/reference/forge/deploy-commands

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Gas Reporting

Produce a gas report of the files specified on `foundry.toml`.

```shell
$ forge test --gas-report
```

### Slither

https://github.com/crytic/slither/wiki/Usage

To install:
```shell
$ pip3 install slither-analyzer
```
To run slither on the repository:
```shell
$ slither .
```

To hide warnings; It will create a `slither.db.json` file. It is ignored by Git.

```shell
$ slither . --triage-mode
```

### VS Code Extensions used

- [Solidity](https://marketplace.visualstudio.com/items?itemName=NomicFoundation.hardhat-solidity) by Nomic Foundation. Solidity support and utils for VS Code.
- [Even Better TOML](https://marketplace.visualstudio.com/items?itemName=tamasfe.even-better-toml) by tamasfe. For .toml formatting.
- [Coverage Gutters](https://marketplace.visualstudio.com/items?itemName=ryanluker.vscode-coverage-gutters) by ryanluker. For displaying test coverage on files.

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
