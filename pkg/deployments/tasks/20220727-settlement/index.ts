import Task from '../../src/task';
import { TaskRunOptions } from '../../src/types';
import { SettlementDeployment } from './input';

export default async (task: Task, { from, force }: TaskRunOptions = {}): Promise<void> => {
  const input = task.input() as SettlementDeployment;
  const settlementArgs = [input.EIP173Proxy, input.Vault];

  const settlement = await task.deployAndVerify(
    'GPv2Settlement',
    settlementArgs,
    from,
    force,
    undefined,
    task._network === 'polygon' ? 20 : 3
  );

  const vaultRelayer = await settlement.vaultRelayer();
  const vaultRelayerArgs = [input.Vault]; // See GPv2VaultRelayer constructor
  await task.verify('GPv2VaultRelayer', vaultRelayer, vaultRelayerArgs);
  task.save({ GPv2VaultRelayer: vaultRelayer });
};
