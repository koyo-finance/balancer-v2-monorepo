import { hardhatBaseConfig } from '@koyofinance/exchange-vault-common';
import overrideQueryFunctions from '@koyofinance/exchange-vault-helpers/plugins/overrideQueryFunctions';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import { TASK_COMPILE } from 'hardhat/builtin-tasks/task-names';
import { task } from 'hardhat/config';
import { name } from './package.json';

task(TASK_COMPILE).setAction(overrideQueryFunctions);

export default {
  solidity: {
    compilers: hardhatBaseConfig.compilers,
    overrides: { ...hardhatBaseConfig.overrides(name) },
  },
};
