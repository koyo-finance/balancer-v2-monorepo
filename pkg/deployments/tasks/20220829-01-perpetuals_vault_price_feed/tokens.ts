export interface NativeTokenDefinition {
  name: string;
  address: string;
  decimals: number;
}

export interface TokenDefinition extends NativeTokenDefinition {
  priceFeed: string;
  priceDecimals: number;
  fastPricePrecision: number;
  isStrictStable: boolean;
  tokenWeight: number;
  minProfitBps: number;
  maxUsdgAmount: number;
  bufferAmount: number;
  isStable: boolean;
  isShortable: boolean;
  maxGlobalShortSize: number;
}

export interface NetworkTokens {
  nativeToken: NativeTokenDefinition;
  tokens: { [K: string]: TokenDefinition };
}

export const optimism: NetworkTokens = Object.freeze({
  nativeToken: {
    name: 'weth',
    address: '0x4200000000000000000000000000000000000006',
    decimals: 18,
  },
  tokens: {
    eth: {
      name: 'eth',
      address: '0x4200000000000000000000000000000000000006',
      decimals: 18,
      priceFeed: '0x13e3Ee699D1909E989722E753853AE30b17e08c5',
      priceDecimals: 8,
      fastPricePrecision: 1000,
      isStrictStable: false,
      tokenWeight: 28000,
      minProfitBps: 0,
      maxUsdgAmount: 120 * 1000 * 1000,
      bufferAmount: 15000,
      isStable: false,
      isShortable: true,
      maxGlobalShortSize: 30 * 1000 * 1000,
    },
    usdc: {
      name: 'usdc',
      address: '0x7F5c764cBc14f9669B88837ca1490cCa17c31607',
      decimals: 6,
      priceFeed: '0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3',
      priceDecimals: 8,
      fastPricePrecision: 0,
      isStrictStable: true,
      tokenWeight: 32000,
      minProfitBps: 0,
      maxUsdgAmount: 120 * 1000 * 1000,
      bufferAmount: 60 * 1000 * 1000,
      isStable: true,
      isShortable: false,
      maxGlobalShortSize: 0,
    },
  },
});
