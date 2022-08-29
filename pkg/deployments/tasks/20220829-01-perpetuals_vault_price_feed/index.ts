import Task from '../../src/task';
import { TaskRunOptions } from '../../src/types';
import { PerpetualsVaultPriceFeedDeployment } from './input';
import { actionId } from '@koyofinance/exchange-vault-helpers/src/models/misc/actions';
import { getSigner } from '../../src/signers';
import { expandDecimals } from '@koyofinance/exchange-vault-helpers/src/models/priceFeed/expand';

export default async (task: Task, { from, force }: TaskRunOptions = {}): Promise<void> => {
  const input = task.input() as PerpetualsVaultPriceFeedDeployment;
  const deployer = await getSigner(0);

  const vault = await task.instanceAt('Vault', input.Vault);
  const authorizer = await task.instanceAt('Authorizer', await vault.getAuthorizer());

  const { eth, usdc } = input.tokens.tokens;
  const tokenArr = [eth, usdc];

  const perpetualsVaultOptimismPriceFeedArgs = [input.Vault, input.chainlinkSequencerUptimeOracleAddress];
  const perpetualsVaultOptimismPriceFeed = await task.deployAndVerify(
    'PerptualsVaultOptimismPriceFeed',
    perpetualsVaultOptimismPriceFeedArgs,
    from,
    force,
    undefined,
    10
  );
  await perpetualsVaultOptimismPriceFeed.deployed();

  await authorizer.grantRoles(
    [
      await actionId(perpetualsVaultOptimismPriceFeed, 'setMaxStrictPriceDeviation'),
      await actionId(perpetualsVaultOptimismPriceFeed, 'setPriceSampleSpace'),
      await actionId(perpetualsVaultOptimismPriceFeed, 'setIsAmmEnabled'),
      await actionId(perpetualsVaultOptimismPriceFeed, 'setTokenConfig'),
      await actionId(perpetualsVaultOptimismPriceFeed, 'setIsSecondaryPriceEnabled'),
    ],
    deployer.address
  );

  await perpetualsVaultOptimismPriceFeed.setMaxStrictPriceDeviation(expandDecimals(5, 28)); // 0.05 USD
  await perpetualsVaultOptimismPriceFeed.setPriceSampleSpace(1);
  await perpetualsVaultOptimismPriceFeed.setIsAmmEnabled(false);
  await perpetualsVaultOptimismPriceFeed.setIsSecondaryPriceEnabled(false);

  for (const token of tokenArr) {
    await perpetualsVaultOptimismPriceFeed.setTokenConfig(
      token.address, // _token
      token.priceFeed, // _priceFeed
      token.priceDecimals, // _priceDecimals
      token.isStrictStable // _isStrictStable
    );
  }
};
