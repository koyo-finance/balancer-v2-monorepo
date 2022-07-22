import { MONTH } from '@koyofinance/exchange-vault-helpers/src/time';
import Task, { TaskMode } from '../../src/task';
import { Network } from '../../src/types';

export interface VaultDeployment {
  Authorizer: string;
  weth: string;
  pauseWindowDuration: number;
  bufferPeriodDuration: number;
}

const Authorizer = new Task('20220612-authorizer', TaskMode.READ_ONLY);

const input: { [network in Network]: VaultDeployment } = {
  boba: {
    Authorizer: Authorizer as unknown as string,
    weth: '0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000',
    pauseWindowDuration: 3 * MONTH,
    bufferPeriodDuration: MONTH,
  },
  aurora: {
    Authorizer: Authorizer as unknown as string,
    weth: '0xC9BdeEd33CD01541e1eeD10f90519d2C06Fe3feB',
    pauseWindowDuration: 3 * MONTH,
    bufferPeriodDuration: MONTH,
  },
  moonriver: {
    Authorizer: Authorizer as unknown as string,
    weth: '0x98878B06940aE243284CA214f92Bb71a2b032B8A',
    pauseWindowDuration: 3 * MONTH,
    bufferPeriodDuration: MONTH,
  },
  polygon: {
    Authorizer: Authorizer as unknown as string,
    weth: '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270',
    pauseWindowDuration: 3 * MONTH,
    bufferPeriodDuration: MONTH,
  },
  moonbeam: {
    Authorizer: Authorizer as unknown as string,
    weth: '0xAcc15dC74880C9944775448304B263D191c6077F',
    pauseWindowDuration: 3 * MONTH,
    bufferPeriodDuration: MONTH,
  },
};

export default input;
