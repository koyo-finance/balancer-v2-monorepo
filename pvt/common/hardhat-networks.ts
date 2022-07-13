interface HttpNetworkUserConfig {
  chainId?: number;
  from?: string;
  gas?: 'auto' | number;
  gasPrice?: 'auto' | number;
  gasMultiplier?: number;
  url?: string;
  timeout?: number;
  httpHeaders?: { [name: string]: string };
  accounts?: string[];
}

interface NetworksUserConfig {
  [networkName: string]: HttpNetworkUserConfig | undefined;
}

const networks: NetworksUserConfig = {
  boba: {
    chainId: 288,
    url: 'https://mainnet.boba.network',
  },
  aurora: {
    chainId: 1313161554,
    url: 'https://mainnet.aurora.dev/6WoudEf5WzicBP8H7XP2yBZbTRGAwFGbmm4S62b5hAu',
  },
  moonriver: {
    chainId: 1285,
    url: 'https://moonriver.public.blastapi.io',
  },
};

export default networks;
