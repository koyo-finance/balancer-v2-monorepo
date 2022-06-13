import Task, { TaskMode } from '../../src/task';
import { Network } from '../../src/types';

export interface HelpersDeployment {
  Vault: string;
}

const Vault = new Task('20220613-vault', TaskMode.READ_ONLY);

const input: { [network in Network]: HelpersDeployment } = {
  boba: {
    Vault: Vault as unknown as string,
  },
};

export default input;
