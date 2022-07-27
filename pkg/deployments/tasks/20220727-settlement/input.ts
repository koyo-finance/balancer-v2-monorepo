import Task, { TaskMode } from '../../src/task';
import { Network } from '../../src/types';

export interface SettlementDeployment {
  Vault: string;
  EIP173Proxy: string;
}

const Vault = new Task('20220613-vault', TaskMode.READ_ONLY);
const EIP173Proxy = new Task('20220726-settlement-authentication', TaskMode.READ_ONLY);

const input: { [network in Network]: SettlementDeployment } = {
  boba: {
    Vault: Vault as unknown as string,
    EIP173Proxy: EIP173Proxy as unknown as string,
  },
};

export default input;
