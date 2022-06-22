import { Contract } from 'ethers';
import { deploy, deployedAt } from '../../../contract';
import * as expectEvent from '../../../test/expectEvent';
import TypesConverter from '../../types/TypesConverter';
import Vault from '../../vault/Vault';
import VaultDeployer from '../../vault/VaultDeployer';
import { RawWeightedPoolDeployment, WeightedPoolDeployment, WeightedPoolType } from './types';
import WeightedPool from './WeightedPool';

const NAME = 'Balancer Pool Token';
const SYMBOL = 'BPT';

export default {
  async deploy(params: RawWeightedPoolDeployment): Promise<WeightedPool> {
    const deployment = TypesConverter.toWeightedPoolDeployment(params);
    const vault = params?.vault ?? (await VaultDeployer.deploy(TypesConverter.toRawVaultDeployment(params)));
    const pool = await (params.fromFactory ? this._deployFromFactory : this._deployStandalone)(deployment, vault);

    const {
      tokens,
      weights,
      assetManagers,
      swapFeePercentage,
      poolType,
      swapEnabledOnStart,
      mustAllowlistLPs,
      protocolSwapFeePercentage,
      managementSwapFeePercentage,
      managementAumFeePercentage,
      aumProtocolFeesCollector,
    } = deployment;

    const poolId = await pool.getPoolId();
    return new WeightedPool(
      pool,
      poolId,
      vault,
      tokens,
      weights,
      assetManagers,
      swapFeePercentage,
      poolType,
      swapEnabledOnStart,
      mustAllowlistLPs,
      protocolSwapFeePercentage,
      managementSwapFeePercentage,
      managementAumFeePercentage,
      aumProtocolFeesCollector
    );
  },

  async _deployStandalone(params: WeightedPoolDeployment, vault: Vault): Promise<Contract> {
    const {
      tokens,
      weights,
      assetManagers,
      swapFeePercentage,
      pauseWindowDuration,
      bufferPeriodDuration,
      oracleEnabled,
      poolType,
      owner,
      from,
    } = params;

    let result: Promise<Contract>;

    switch (poolType) {
      case WeightedPoolType.ORACLE_WEIGHTED_POOL: {
        result = deploy('exchange-vault-pool-oracle/MockOracleWeightedPool', {
          args: [
            {
              vault: vault.address,
              name: NAME,
              symbol: SYMBOL,
              tokens: tokens.addresses,
              normalizedWeight0: weights[0],
              normalizedWeight1: weights[1],
              swapFeePercentage: swapFeePercentage,
              pauseWindowDuration: pauseWindowDuration,
              bufferPeriodDuration: bufferPeriodDuration,
              oracleEnabled: oracleEnabled,
              owner: owner,
            },
          ],
          from,
          libraries: { QueryProcessor: (await deploy('QueryProcessor')).address },
        });
        break;
      }
      default: {
        result = deploy('exchange-vault-pool-weighted/WeightedPool', {
          args: [
            vault.address,
            NAME,
            SYMBOL,
            tokens.addresses,
            weights,
            assetManagers,
            swapFeePercentage,
            pauseWindowDuration,
            bufferPeriodDuration,
            owner,
          ],
          from,
        });
      }
    }

    return result;
  },

  async _deployFromFactory(params: WeightedPoolDeployment, vault: Vault): Promise<Contract> {
    const { tokens, weights, assetManagers, swapFeePercentage, oracleEnabled, poolType, owner, from } = params;

    let result: Promise<Contract>;

    switch (poolType) {
      case WeightedPoolType.ORACLE_WEIGHTED_POOL: {
        const factory = await deploy('exchange-vault-pool-oracle/OracleWeightedPoolFactory', {
          args: [vault.address],
          from,
          libraries: { QueryProcessor: await (await deploy('QueryProcessor')).address },
        });
        const tx = await factory.create(
          NAME,
          SYMBOL,
          tokens.addresses,
          weights,
          swapFeePercentage,
          oracleEnabled,
          owner
        );
        const receipt = await tx.wait();
        const event = expectEvent.inReceipt(receipt, 'PoolCreated');
        result = deployedAt('exchange-vault-pool-oracle/OracleWeightedPool', event.args.pool);
        break;
      }
      default: {
        const factory = await deploy('exchange-vault-pool-weighted/WeightedPoolFactory', {
          args: [vault.address],
          from,
        });
        const tx = await factory.create(
          NAME,
          SYMBOL,
          tokens.addresses,
          weights,
          assetManagers,
          swapFeePercentage,
          owner
        );
        const receipt = await tx.wait();
        const event = expectEvent.inReceipt(receipt, 'PoolCreated');
        result = deployedAt('exchange-vault-pool-weighted/WeightedPool', event.args.pool);
      }
    }

    return result;
  },
};
