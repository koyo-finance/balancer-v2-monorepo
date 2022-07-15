import Task from '../../src/task';
import { TaskRunOptions } from '../../src/types';
import { WeightedPoolFactoryDeployment } from './input';

export default async (task: Task, { from, force }: TaskRunOptions = {}): Promise<void> => {
  const input = task.input() as WeightedPoolFactoryDeployment;
  const args = [input.Vault];

  await task.deployAndVerify(
    'StablePoolFactory',
    args,
    from,
    force,
    undefined,
    task._network === 'polygon' ? 20 : undefined
  );
};
