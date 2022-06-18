import Task from '../../src/task';
import { TaskRunOptions } from '../../src/types';
import { WeightedPoolFactoryDeployment } from './input';

export default async (task: Task, { from }: TaskRunOptions = {}): Promise<void> => {
  const input = task.input() as WeightedPoolFactoryDeployment;
  const args = [input.Vault];

  await task.deploy('StablePoolFactory', args, from);
};
