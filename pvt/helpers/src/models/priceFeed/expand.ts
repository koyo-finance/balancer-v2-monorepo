import { BigNumber } from 'ethers';

export function bigNumberify(n: number) {
  return BigNumber.from(n);
}

export function expandDecimals(n: number, decimals: number) {
  return bigNumberify(n).mul(bigNumberify(10).pow(decimals));
}
