import { ethers } from 'hardhat';
import { deploy } from '../../contract';
import { MONTH } from '../../time';
import TypesConverter from '../types/TypesConverter';
import TimelockAuthorizer from './TimelockAuthorizer';
import { TimelockAuthorizerDeployment } from './types';

export default {
  async deploy(deployment: TimelockAuthorizerDeployment): Promise<TimelockAuthorizer> {
    const admin = deployment.admin || deployment.from || (await ethers.getSigners())[0];
    const vault = TypesConverter.toAddress(deployment.vault);
    const rootTransferDelay = deployment.rootTransferDelay || MONTH;
    const args = [TypesConverter.toAddress(admin), vault, rootTransferDelay];
    const instance = await deploy('TimelockAuthorizer', { args });
    return new TimelockAuthorizer(instance, admin);
  },
};
