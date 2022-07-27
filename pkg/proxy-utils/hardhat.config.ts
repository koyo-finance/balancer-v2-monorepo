import { hardhatBaseConfig } from '@koyofinance/exchange-vault-common';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import 'hardhat-abi-exporter';
import { HardhatUserConfig } from 'hardhat/types';
import { name } from './package.json';

const config: HardhatUserConfig = {
  solidity: {
    compilers: hardhatBaseConfig.compilers,
    overrides: { ...hardhatBaseConfig.overrides(name) },
  },
  abiExporter: hardhatBaseConfig.abiExporter,
};

export default config;
