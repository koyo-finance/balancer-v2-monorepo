import Task from '../../src/task';
import { TaskRunOptions } from '../../src/types';
import { HelpersDeployment } from './input';

export default async (task: Task, { from }: TaskRunOptions = {}): Promise<void> => {
  const input = task.input() as HelpersDeployment;

  const helpersArgs = [input.Vault];
  await task.deploy('KoyoHelpers', helpersArgs, from);
};
