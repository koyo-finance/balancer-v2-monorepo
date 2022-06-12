import { deploy } from '@koyofinance/exchange-vault-helpers/src/contract';
import { BigNumberish, bn } from '@koyofinance/exchange-vault-helpers/src/numbers';
import { Account } from '@koyofinance/exchange-vault-helpers/src/models/types/types';
import TypesConverter from '@koyofinance/exchange-vault-helpers/src/models/types/TypesConverter';

export async function forceSendEth(recipient: Account, amount: BigNumberish): Promise<void> {
  await deploy('EthForceSender', { args: [TypesConverter.toAddress(recipient), { value: bn(amount) }] });
}
