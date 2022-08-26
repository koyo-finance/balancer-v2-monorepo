import Task from '../../src/task';
import { TaskRunOptions } from '../../src/types';
import { PerpetualsVaultDeployment } from './input';

export default async (task: Task, { from, force }: TaskRunOptions = {}): Promise<void> => {
  const input = task.input() as PerpetualsVaultDeployment;

  const perpetualsVaultArgs: string[] = [];
  const perpetualsVault = await task.deployAndVerify(
    'PerpetualsVault',
    perpetualsVaultArgs,
    from,
    force,
    undefined,
    10
  );
  await perpetualsVault.deployed();

  const usdkArgs = [perpetualsVault.address];
  const usdk = await task.deployAndVerify('USDK', usdkArgs, from, force, undefined, 10);
  await usdk.deployed();

  const perpetualsRouterArgs = [input.Vault, perpetualsVault.address, usdk.address, input.weth];
  const perpetualsRouter = await task.deployAndVerify(
    'PerpetualsRouter',
    perpetualsRouterArgs,
    from,
    force,
    undefined,
    10
  );
  await perpetualsRouter.deployed();
};
