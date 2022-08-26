type ContractSettings = Record<
  string,
  {
    version: string;
    runs: number;
  }
>;

const contractSettings: ContractSettings = {
  '@koyofinance/exchange-vault/contracts/Vault.sol': {
    version: '0.7.1',
    runs: 1500,
  },
  '@koyofinance/exchange-vault-pool-oracle/contracts/oracle/OracleWeightedPoolFactory.sol': {
    version: '0.7.1',
    runs: 200,
  },
  '@koyofinance/exchange-vault-pool-metas/contracts/stable/MetaStablePoolFactory.sol': {
    version: '0.7.1',
    runs: 1,
  },
  '@koyofinance/exchange-vault-pool-metas/contracts/stable/MetaStablePool.sol': {
    version: '0.7.1',
    runs: 1,
  },
  '@koyofinance/exchange-vault-pool-weighted/contracts/weighted/WeightedPoolFactory.sol': {
    version: '0.7.1',
    runs: 1,
  },
  '@koyofinance/exchange-vault-pool-weighted/contracts/weighted/WeightedPool.sol': {
    version: '0.7.1',
    runs: 1,
  },
  '@koyofinance/exchange-vault-pool-stable/contracts/phantom-stable/StablePhantomPoolFactory.sol': {
    version: '0.7.1',
    runs: 1,
  },
  '@koyofinance/exchange-vault-pool-stable/contracts/phantom-stable/StablePhantomPool.sol': {
    version: '0.7.1',
    runs: 1,
  },
  '@koyofinance/perpetual-swaps-core/contracts/PerpetualsVault.sol': {
    version: '0.7.1',
    runs: 1,
  },
};

type SolcConfig = {
  version: string;
  settings: {
    optimizer: {
      enabled: boolean;
      runs?: number;
    };
  };
};

export const compilers: [SolcConfig, SolcConfig, SolcConfig, SolcConfig] = [
  {
    version: '0.7.1',
    settings: {
      optimizer: {
        enabled: true,
        runs: 9999,
      },
    },
  },
  {
    version: '0.7.6',
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000000,
      },
    },
  },
  {
    version: '0.8.4',
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000000,
      },
    },
  },
  {
    version: '0.6.12',
    settings: {
      optimizer: {
        enabled: true,
        runs: 1,
      },
    },
  },
];

export const overrides = (packageName: string): Record<string, SolcConfig> => {
  const overrides: Record<string, SolcConfig> = {};

  for (const contract of Object.keys(contractSettings)) {
    overrides[contract.replace(`${packageName}/`, '')] = {
      version: contractSettings[contract].version,
      settings: {
        optimizer: {
          enabled: true,
          runs: contractSettings[contract].runs,
        },
      },
    };
  }

  return overrides;
};

export const abiExporter = {
  path: './abis',
  runOnCompile: false,
  clear: true,
  flat: true,
  except: ['test/'],
};
