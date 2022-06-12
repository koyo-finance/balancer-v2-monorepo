import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';

import { hardhatBaseConfig } from '@koyofinance/exchange-vault-common';
import { name } from './package.json';

import { task } from 'hardhat/config';
import { TASK_COMPILE } from 'hardhat/builtin-tasks/task-names';
import overrideQueryFunctions from '@koyofinance/exchange-vault-helpers/plugins/overrideQueryFunctions';

task(TASK_COMPILE).setAction(overrideQueryFunctions);

export default {
  solidity: {
    compilers: hardhatBaseConfig.compilers,
    overrides: { ...hardhatBaseConfig.overrides(name) },
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
    },
  },
};
