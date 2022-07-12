import Task from '../../src/task';
import { TaskRunOptions } from '../../src/types';

export default async (task: Task, { from, force }: TaskRunOptions = {}): Promise<void> => {
  await task.deployAndVerify('QueryProcessor', [], from, force);
};
