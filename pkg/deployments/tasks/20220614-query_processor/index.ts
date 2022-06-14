import Task from '../../src/task';
import { TaskRunOptions } from '../../src/types';

export default async (task: Task, { from }: TaskRunOptions = {}): Promise<void> => {
  await task.deploy('QueryProcessor', [], from);
};
