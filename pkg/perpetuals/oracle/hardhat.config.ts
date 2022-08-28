import { hardhatBaseConfig } from '@koyofinance/exchange-vault-common';
import overrideQueryFunctions from '@koyofinance/exchange-vault-helpers/plugins/overrideQueryFunctions';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import 'hardhat-abi-exporter';
import { TASK_COMPILE } from 'hardhat/builtin-tasks/task-names';
import { task } from 'hardhat/config';
import { HardhatUserConfig } from 'hardhat/types';
import { name } from './package.json';

task(TASK_COMPILE).setAction(overrideQueryFunctions);

const config: HardhatUserConfig = {
  solidity: {
    compilers: hardhatBaseConfig.compilers,
    overrides: { ...hardhatBaseConfig.overrides(name) },
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
    },
  },
  abiExporter: hardhatBaseConfig.abiExporter,
};

export default config;
