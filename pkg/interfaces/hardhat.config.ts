import { hardhatBaseConfig } from '@koyofinance/exchange-vault-common';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import { name } from './package.json';

export default {
  solidity: {
    compilers: hardhatBaseConfig.compilers,
    overrides: { ...hardhatBaseConfig.overrides(name) },
  },
};
