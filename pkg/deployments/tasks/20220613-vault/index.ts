import Task from '../../src/task';
import { TaskRunOptions } from '../../src/types';
import { VaultDeployment } from './input';

export default async (task: Task, { from }: TaskRunOptions = {}): Promise<void> => {
  const input = task.input() as VaultDeployment;
  const vaultArgs = [input.Authorizer, input.weth, input.pauseWindowDuration, input.bufferPeriodDuration];
  const vault = await task.deploy('Vault', vaultArgs, from);
  await vault.deployed();

  // The vault automatically also deploys the protocol fees collector.
  const feeCollector = await vault.getProtocolFeesCollector();
  task.save({ ProtocolFeesCollector: feeCollector });
};
