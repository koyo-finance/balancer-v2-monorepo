import Task from '../../src/task';
import { TaskRunOptions } from '../../src/types';
import { HelpersDeployment } from './input';

export default async (task: Task, { from, force }: TaskRunOptions = {}): Promise<void> => {
  const input = task.input() as HelpersDeployment;

  const helpersArgs = [input.Vault];
  await task.deployAndVerify(
    'KoyoHelpers',
    helpersArgs,
    from,
    force,
    undefined,
    task._network === 'polygon' ? 20 : undefined
  );
};
