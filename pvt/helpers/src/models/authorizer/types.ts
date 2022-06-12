import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';
import { BigNumberish } from '../../numbers';
import { Account } from '../types/types';

export type TimelockAuthorizerDeployment = {
  vault?: Account;
  admin?: SignerWithAddress;
  rootTransferDelay?: BigNumberish;
  from?: SignerWithAddress;
};
