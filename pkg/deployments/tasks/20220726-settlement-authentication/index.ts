import { ethers } from 'ethers';
import Task from '../../src/task';
import { TaskRunOptions } from '../../src/types';
import { AllowListAuthenticationDeployment } from './input';

export default async (task: Task, { from, force }: TaskRunOptions = {}): Promise<void> => {
  const input = task.input() as AllowListAuthenticationDeployment;
  const implementationInitInterface = new ethers.utils.Interface([
    {
      inputs: [
        {
          internalType: 'address',
          name: 'manager_',
          type: 'address',
        },
      ],
      name: 'initializeManager',
      outputs: [],
      stateMutability: 'nonpayable',
      type: 'function',
    },
  ]);

  const implementation = await task.deployAndVerify(
    'GPv2AllowListAuthentication',
    [],
    from,
    force,
    undefined,
    task._network === 'polygon' ? 20 : 3
  );

  const initializerArgs = [input.proxyAdmin];
  const initializerCalldata = implementationInitInterface.encodeFunctionData('initializeManager', initializerArgs);
  const proxyArgs = [implementation.address, input.proxyAdmin, initializerCalldata];
  await task.deployAndVerify('EIP173Proxy', proxyArgs, from, force, undefined, task._network === 'polygon' ? 20 : 3);
};
