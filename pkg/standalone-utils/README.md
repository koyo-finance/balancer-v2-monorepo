# <img src="../../logo.svg" alt="Balancer" height="128px">

# Balancer V2 Standalone Utilities

[![NPM Package](https://img.shields.io/npm/v/@koyofinance/exchange-vault-standalone-utils.svg)](https://www.npmjs.org/package/@koyofinance/exchange-vault-standalone-utils)

This package contains standalone Solidity utilities that can be used to perform advanced actions in the Balancer V2 protocol.

- [`BalancerHelpers`](./contracts/BalancerHelpers.sol) can be used by off-chain clients to simulate Pool joins and exits, computing the expected result of these operations.

## Overview

### Installation

```console
$ npm install @koyofinance/exchange-vault-standalone-utils
```

### Usage

The contracts in this package are meant to be deployed as-is, and in most cases canonical deployments already exist in both mainnet and various test networks. To get their addresses and ABIs, see [`v2-deployments`](../deployments).

## Licensing

[GNU General Public License Version 3 (GPL v3)](../../LICENSE).
