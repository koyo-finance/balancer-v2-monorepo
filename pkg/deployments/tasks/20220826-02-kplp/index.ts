import Task from '../../src/task';
import { TaskRunOptions } from '../../src/types';
import { PerpetualsKPLPDeployment } from './input';
import { actionId } from '@koyofinance/exchange-vault-helpers/src/models/misc/actions';
import { getSigner } from '../../src/signers';

export default async (task: Task, { from, force }: TaskRunOptions = {}): Promise<void> => {
  const input = task.input() as PerpetualsKPLPDeployment;
  const deployer = await getSigner(0);

  const vault = await task.instanceAt('Vault', input.Vault);
  const perpetualsVault = await task.instanceAt('PerpetualsVault', input.PerpetualsVault);
  const usdk = await task.instanceAt('USDK', input.USDK);
  const authorizer = await task.instanceAt('Authorizer', await vault.getAuthorizer());

  const kplpArgs: string[] = [];
  const kplp = await task.deployAndVerify('KPLP', kplpArgs, from, force, undefined, 10);
  await kplp.deployed();

  await kplp.setInPrivateTransferMode(true);

  const kplpManagerArgs = [input.Vault, input.PerpetualsVault, input.USDK, kplp.address, 15 * 60];
  const kplpManager = await task.deployAndVerify('KPLPManager', kplpManagerArgs, from, force, undefined, 10);
  await kplpManager.deployed();

  await authorizer.grantRole(await actionId(kplpManager, 'setInPrivateMode'), deployer.address);
  await kplpManager.setInPrivateMode(true);

  await kplp.setMinter(kplpManager.address, true);
  await usdk.addVault(kplpManager.address);

  await perpetualsVault.setInManagerMode(true);
  await perpetualsVault.setManager(kplpManager.address, true);
};
