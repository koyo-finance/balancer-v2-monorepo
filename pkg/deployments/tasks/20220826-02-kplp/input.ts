import Task, { TaskMode } from '../../src/task';
import { Network } from '../../src/types';

export interface PerpetualsKPLPDeployment {
  Vault: string;
  PerpetualsVault: string;
  USDK: string;
}

const Vault = new Task('20220613-vault', TaskMode.READ_ONLY);
const PerpetualsVault = new Task('20220826-01-perpetuals_vault', TaskMode.READ_ONLY);
const USDK = new Task('20220826-01-perpetuals_vault', TaskMode.READ_ONLY);

const input: { [network in Network]: PerpetualsKPLPDeployment } = {
  optimism: {
    Vault: Vault as unknown as string,
    PerpetualsVault: PerpetualsVault as unknown as string,
    USDK: USDK as unknown as string,
  },
};

export default input;
