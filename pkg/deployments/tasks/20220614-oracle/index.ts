import Task from '../../src/task';
import { TaskRunOptions } from '../../src/types';
import { OracleWeightedPoolFactoryDeployment } from './input';

export default async (task: Task, { from }: TaskRunOptions = {}): Promise<void> => {
  const input = task.input() as OracleWeightedPoolFactoryDeployment;
  const args = [input.Vault];

  await task.deploy('OracleWeightedPoolFactory', args, from, { QueryProcessor: input.QueryProcessor });
};
