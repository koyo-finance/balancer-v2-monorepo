import Task from '../../src/task';
import { TaskRunOptions } from '../../src/types';
import { VaultDeployment } from './input';

export default async (task: Task, { from, force }: TaskRunOptions = {}): Promise<void> => {
  const input = task.input() as VaultDeployment;
  const vaultArgs = [input.Authorizer, input.weth, input.pauseWindowDuration, input.bufferPeriodDuration];
  const vault = await task.deployAndVerify('Vault', vaultArgs, from, force, undefined, 10);
  await vault.deployed();

  // The vault automatically also deploys the protocol fees collector.
  const feeCollector = await vault.getProtocolFeesCollector();
  const feeCollectorArgs = [vault.address]; // See ProtocolFeesCollector constructor
  await task.verify('ProtocolFeesCollector', feeCollector, feeCollectorArgs);
  task.save({ ProtocolFeesCollector: feeCollector });
};
