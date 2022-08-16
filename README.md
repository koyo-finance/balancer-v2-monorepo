# <img src="logo.svg" alt="Kōyō Finance" height="128px">

# Kōyō Labs contracts Monorepo

[![Docs](https://img.shields.io/badge/docs-%F0%9F%93%84-blue)](https://docs.koyo.finance/)
[![License](https://img.shields.io/badge/License-GPLv3-green.svg)](https://www.gnu.org/licenses/gpl-3.0)

This repository contains the Balancer Protocol V2 core smart contracts, including the `Vault` and standard Pools, along with their tests, configuration, and deployment information.

For high-level intructions of the included projects, see:
 - [Introducing Balancer V2: Generalized AMMs](https://medium.com/balancer-protocol/balancer-v2-generalizing-amms-16343c4563ff)
 - [GMX Contracts](https://gmxio.gitbook.io/gmx/contracts)
 - [GMX Technical Overview](https://gmx-io.notion.site/gmx-io/GMX-Technical-Overview-47fc5ed832e243afb9e97e8a4a036353)
 - [CoW Protocol Smart Contracts](https://github.com/cowprotocol/contracts/blob/main/docs/index.md)

## Structure

This is a Yarn 2 monorepo, with the packages meant to be published in the [`pkg`](./pkg) directory. Newly developed packages may not be published yet.
Active development occurs in this repository, which means some contracts in it might not be production-ready. Proceed with caution.

### Packages

- [`v2-deployments`](./pkg/deployments): addresses and ABIs of all Balancer V2 deployed contracts, for mainnet and various test networks.
- [`v2-interfaces`](./pkg/interfaces): Solidity interfaces for all contracts.
- [`v2-vault`](./pkg/vault): the [`Vault`](./pkg/vault/contracts/Vault.sol) contract and all core interfaces, including [`IVault`](./pkg/vault/contracts/interfaces/IVault.sol) and the Pool interfaces: [`IBasePool`](./pkg/vault/contracts/interfaces/IBasePool.sol), [`IGeneralPool`](./pkg/vault/contracts/interfaces/IGeneralPool.sol) and [`IMinimalSwapInfoPool`](./pkg/vault/contracts/interfaces/IMinimalSwapInfoPool.sol).
- [`v2-pool-weighted`](./pkg/pool-weighted): the [`WeightedPool`](./pkg/pool-weighted/contracts/WeightedPool.sol), [`WeightedPool2Tokens`](./pkg/pool-weighted/contracts/WeightedPool2Tokens.sol) and [`LiquidityBootstrappingPool`](./pkg/pool-weighted/contracts/smart/LiquidityBootstrappingPool.sol) contracts, along with their associated factories.
- [`v2-pool-stable`](./pkg/pool-stable): the [`StablePool`](./pkg/pool-weighted/contracts/StablePool.sol) and [`MetaStablePool`](./pkg/pool-weighted/contracts/meta/MetaStablePool.sol) contracts, along with their associated factories.
- [`v2-pool-linear`](./pkg/pool-linear): the [`AaveLinearPool`](./pkg/pool-linear/contracts/aave/AaveLinearPool.sol) and [`ERC4626LinearPool`](./pkg/pool-linear/contracts/erc4626/ERC4626LinearPool.sol) contracts, along with their associated factories.
- [`v2-pool-utils`](./pkg/pool-utils): Solidity utilities used to develop Pool contracts.
- [`v2-solidity-utils`](./pkg/solidity-utils): miscellaneous Solidity helpers and utilities used in many different contracts.
- [`v2-standalone-utils`](./pkg/standalone-utils): miscellaneous standalone utility contracts.
- [`v2-liquidity-mining`](./pkg/liquidity-mining): contracts that compose the liquidity mining (veBAL) system.
- [`v2-governance-scripts`](./pkg/governance-scripts): contracts that execute complex governance actions.

## Build and Test

Before any tests can be run, the repository needs to be prepared:

```bash
$ yarn # install all dependencies
$ yarn build # compile all contracts
```

Most tests are standalone and simply require installation of dependencies and compilation. Some packages however have extra requirements. Notably, the [`deployments`](./pkg/deployments) package must have access to network archive nodes in order to perform fork tests. For more details, head to [its readme file](./pkg/deployments/README.md).

In order to run all tests (including those with extra dependencies), run:

```bash
$ yarn test # run all tests
```

To instead run a single package's tests, run:

```bash
$ cd pkg/<package> # e.g. cd pkg/v2-vault
$ yarn test
```

## Licensing

Most of the Solidity source code is licensed under the GNU General Public License Version 3 by Balancer Labs (GPL v3): see [`LICENSE`](./LICENSE-GPL).

### Exceptions

- All files in the `openzeppelin` directory of the [`v2-solidity-utils`](./pkg/solidity-utils) package are based on the [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) library, and as such are licensed under the MIT License: see [LICENSE](./pkg/solidity-utils/contracts/openzeppelin/LICENSE).
- All sub-packages in the [`perpetuals`](./pkg/perpetuals) directory are based on [GMX Contracts](https://github.com/gmx-io/gmx-contracts), and as such are licensed under the MIT License: see [LICENSE](./LICENSE-GMX-MIT).
- The `LogExpMath` contract from the [`v2-solidity-utils`](./pkg/solidity-utils) package is licensed under the MIT License.
- All other files, including tests and the [`pvt`](./pvt) directory are unlicensed.
