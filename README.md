# Goat Protocol

[![Tests](https://github.com/goatfi/contracts/actions/workflows/test.yml/badge.svg)](https://github.com/goatfi/contracts/actions/workflows/test.yml)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)


The Goat Protocol is a decentralized yield optimizer. It allows users, DAOs and other protocols earn the  yield on their digital assets by auto compounding the rewards into more of what they've deposited.

## Documentation

**This respository uses Foundry as development enviroment.**

To compile the source code, run [`forge build`](https://book.getfoundry.sh/reference/forge/forge-build). The repository already has a remappings.txt file, so it should pick up the dependencies.

```shell
forge build
```

To run the unit and invariant tests, run [`forge test`](https://book.getfoundry.sh/forge/tests).

```shell
forge test
```

To learn bore about the Goat Protocol visit [`docs.goat.fi`](https://docs.goat.fi/).

## Repository Structure

[`/src`](./src/) contains the source code of the core contract of the Goat Protocol.

[`/src/interfaces/infra`](./src/interfaces/infra) contains the interfaces of the Goat Protocol.

[`/script`](./script) contains deployment and configuration scripts.

[`/test`](./test) contains unit and invariant tests.

## Licences

The primary license for the Goat Protocol is the MIT License (`MIT`), see [`LICENSE`](./LICENSE).