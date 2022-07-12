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
};

export default networks;
