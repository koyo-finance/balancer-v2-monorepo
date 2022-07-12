import Task, { TaskMode } from '../../src/task';
import { Network } from '../../src/types';

export interface OracleWeightedPoolFactoryDeployment {
  Vault: string;
  QueryProcessor: string;
}

const Vault = new Task('20220613-vault', TaskMode.READ_ONLY);
const QueryProcessor = new Task('20220614-query_processor', TaskMode.READ_ONLY);

const input: { [network in Network]: OracleWeightedPoolFactoryDeployment } = {
  boba: {
    Vault: Vault as unknown as string,
    QueryProcessor: QueryProcessor as unknown as string,
  },
  aurora: {
    Vault: Vault as unknown as string,
    QueryProcessor: QueryProcessor as unknown as string,
  },
};

export default input;
