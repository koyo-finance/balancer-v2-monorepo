import Task, { TaskMode } from '../../src/task';
import { Network } from '../../src/types';

export interface PerpetualsVaultDeployment {
  Vault: string;
  weth: string;
}

const Vault = new Task('20220613-vault', TaskMode.READ_ONLY);

const input: { [network in Network]: PerpetualsVaultDeployment } = {
  optimism: {
    Vault: Vault as unknown as string,
    weth: '0x4200000000000000000000000000000000000006',
  },
};

export default input;
