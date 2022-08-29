import Task, { TaskMode } from '../../src/task';
import { Network } from '../../src/types';

export interface PerpetualsVaultUtilsDeployment {
  Vault: string;
  PerpetualsVault: string;
}

const Vault = new Task('20220613-vault', TaskMode.READ_ONLY);
const PerpetualsVault = new Task('20220826-01-perpetuals_vault', TaskMode.READ_ONLY);

const input: { [network in Network]: PerpetualsVaultUtilsDeployment } = {
  optimism: {
    Vault: Vault as unknown as string,
    PerpetualsVault: PerpetualsVault as unknown as string,
  },
};

export default input;
