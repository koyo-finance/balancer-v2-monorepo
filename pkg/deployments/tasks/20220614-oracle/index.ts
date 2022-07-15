import Task from '../../src/task';
import { TaskRunOptions } from '../../src/types';
import { OracleWeightedPoolFactoryDeployment } from './input';

export default async (task: Task, { from, force }: TaskRunOptions = {}): Promise<void> => {
  const input = task.input() as OracleWeightedPoolFactoryDeployment;
  const args = [input.Vault];

  await task.deployAndVerify(
    'OracleWeightedPoolFactory',
    args,
    from,
    force,
    { QueryProcessor: input.QueryProcessor },
    task._network === 'polygon' ? 20 : undefined
  );
};
