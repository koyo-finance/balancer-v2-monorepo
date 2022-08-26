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
  moonriver: {
    chainId: 1285,
    url: 'https://moonriver.public.blastapi.io',
  },
  optimism: {
    chainId: 10,
    url: 'https://mainnet.optimism.io',
  },
};

export default networks;
