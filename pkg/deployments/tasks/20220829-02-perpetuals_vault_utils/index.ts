import Task from '../../src/task';
import { TaskRunOptions } from '../../src/types';
import type { PerpetualsVaultUtilsDeployment } from './input';

export default async (task: Task, { from, force }: TaskRunOptions = {}): Promise<void> => {
  const input = task.input() as PerpetualsVaultUtilsDeployment;

  const perpetualsVault = await task.instanceAt('PerpetualsVault', input.PerpetualsVault);

  const perpetualsVaultUtilsArgs = [input.Vault, input.PerpetualsVault];
  const perpetualsVaultUtils = await task.deployAndVerify(
    'PerpetualsVaultUtils',
    perpetualsVaultUtilsArgs,
    from,
    force,
    undefined,
    10
  );
  await perpetualsVaultUtils.deployed();

  await perpetualsVault.setVaultUtils(perpetualsVaultUtils.address);
};
