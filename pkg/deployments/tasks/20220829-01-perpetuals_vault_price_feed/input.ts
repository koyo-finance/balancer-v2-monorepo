import Task, { TaskMode } from '../../src/task';
import { Network } from '../../src/types';
import { NetworkTokens, optimism } from './tokens';

export interface PerpetualsVaultPriceFeedDeployment {
  Vault: string;
  PerpetualsVault: string;
  tokens: NetworkTokens;
  chainlinkSequencerUptimeOracleAddress: string;
}

const Vault = new Task('20220613-vault', TaskMode.READ_ONLY);
const PerpetualsVault = new Task('20220826-01-perpetuals_vault', TaskMode.READ_ONLY);

const input: { [network in Network]: PerpetualsVaultPriceFeedDeployment } = {
  optimism: {
    Vault: Vault as unknown as string,
    PerpetualsVault: PerpetualsVault as unknown as string,
    tokens: optimism,
    chainlinkSequencerUptimeOracleAddress: '0x371EAD81c9102C9BF4874A9075FFFf170F2Ee389',
  },
};

export default input;
