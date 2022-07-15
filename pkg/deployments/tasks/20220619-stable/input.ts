import Task, { TaskMode } from '../../src/task';
import { Network } from '../../src/types';

export interface WeightedPoolFactoryDeployment {
  Vault: string;
}

const Vault = new Task('20220613-vault', TaskMode.READ_ONLY);

const input: { [network in Network]: WeightedPoolFactoryDeployment } = {
  boba: {
    Vault: Vault as unknown as string,
  },
  aurora: {
    Vault: Vault as unknown as string,
  },
  moonriver: {
    Vault: Vault as unknown as string,
  },
  polygon: {
    Vault: Vault as unknown as string,
  },
};

export default input;
