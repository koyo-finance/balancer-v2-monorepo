import { Contract } from 'ethers';

/**
 * @dev Creates an ethers Contract object for a canonical contract deployed on a specific network
 * @param task ID of the task to fetch the deployed contract
 * @param contract Name of the contract to be fetched
 * @param network Name of the network looking the deployment for (e.g. mainnet, rinkeby, ropsten, etc)
 */
export async function getKoyoContract(task: string, contract: string, network: string): Promise<Contract> {
  const address = await getKoyoContractAddress(task, contract, network);
  return getKoyoContractAt(task, contract, address);
}

/**
 * @dev Creates an ethers Contract object from a dynamically created contract at a known address
 * @param task ID of the task to fetch the deployed contract
 * @param contract Name of the contract to be fetched
 * @param address Address of the contract to be fetched
 */
export async function getKoyoContractAt(task: string, contract: string, address: string): Promise<Contract> {
  const abi = await getKoyoContractAbi(task, contract);
  const { ethers } = await import('hardhat');
  return ethers.getContractAt(abi, address);
}

/**
 * @dev Returns the contract's ABI of for a specific task
 * @param task ID of the task to look the ABI of the required contract
 * @param contract Name of the contract to looking the ABI of
 */
export async function getKoyoContractAbi(task: string, contract: string): Promise<unknown[]> {
  return require(getKoyoContractAbiPath(task, contract));
}

/**
 * @dev Returns the contract's creation code of for a specific task
 * @param task ID of the task to look the creation code of the required contract
 * @param contract Name of the contract to looking the creation code of
 */
export async function getKoyoContractBytecode(task: string, contract: string): Promise<string> {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  return require(getKoyoContractBytecodePath(task, contract)).creationCode;
}

/**
 * @dev Returns the contract address of a deployed contract for a specific task on a network
 * @param task ID of the task looking the deployment for
 * @param contract Name of the contract to fetched the address of
 * @param network Name of the network looking the deployment for (e.g. mainnet, rinkeby, ropsten, etc)
 */
export async function getKoyoContractAddress(task: string, contract: string, network: string): Promise<string> {
  const output = await getKoyoDeployment(task, network);
  return output[contract];
}

/**
 * @dev Returns the deployment output for a specific task on a network
 * @param task ID of the task to look the deployment output of the required network
 * @param network Name of the network looking the deployment output for (e.g. mainnet, rinkeby, ropsten, etc)
 */
export async function getKoyoDeployment(task: string, network: string): Promise<{ [key: string]: string }> {
  return require(getKoyoDeploymentPath(task, network));
}

/**
 * @dev Returns the path of a contract's ABI of for a specific task
 * @param task ID of the task to look the path of the ABI of the required contract
 * @param contract Name of the contract to look the path of it's ABI
 */
function getKoyoContractAbiPath(task: string, contract: string): string {
  return `@koyofinance/exchange-vault-deployments/dist/tasks/${task}/abi/${contract}.json`;
}

/**
 * @dev Returns the path of a contract's creation code of for a specific task
 * @param task ID of the task to look the path of the creation code of the required contract
 * @param contract Name of the contract to look the path of it's creation code
 */
function getKoyoContractBytecodePath(task: string, contract: string): string {
  return `@koyofinance/exchange-vault-deployments/dist/tasks/${task}/bytecode/${contract}.json`;
}

/**
 * @dev Returns the deployment path for a specific task on a network
 * @param task ID of the task to look the deployment path for the required network
 * @param network Name of the network looking the deployment path for (e.g. mainnet, rinkeby, ropsten, etc)
 */
function getKoyoDeploymentPath(task: string, network: string): string {
  return `@koyofinance/exchange-vault-deployments/dist/tasks/${task}/output/${network}.json`;
}
