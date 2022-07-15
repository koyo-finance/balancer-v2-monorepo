import networks from '@koyofinance/exchange-vault-common/hardhat-networks';
import '@koyofinance/exchange-vault-common/setupTests';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import { TASK_VERIFY_GET_LIBRARIES } from '@nomiclabs/hardhat-etherscan/dist/src/constants';
import '@nomiclabs/hardhat-waffle';
import { existsSync, readdirSync, statSync } from 'fs';
import 'hardhat-local-networks-config-plugin';
import { TASK_TEST } from 'hardhat/builtin-tasks/task-names';
import { task, types } from 'hardhat/config';
import { HardhatRuntimeEnvironment, HardhatUserConfig, Libraries } from 'hardhat/types';
import path from 'path';
import { checkArtifact, extractArtifact } from './src/artifact';
import { Logger } from './src/logger';
import Task, { TaskMode } from './src/task';
import test from './src/test';
import Verifier from './src/verifier';

task('deploy', 'Run deployment task')
  .addParam('id', 'Deployment task ID')
  .addFlag('force', 'Ignore previous deployments')
  .addOptionalParam('key', 'Etherscan API key to verify contracts')
  .setAction(
    async (args: { id: string; force?: boolean; key?: string; verbose?: boolean }, hre: HardhatRuntimeEnvironment) => {
      Logger.setDefaults(false, args.verbose || false);

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const apiKey = args.key ?? (hre.config.networks[hre.network.name] as any).verificationAPIKey;
      const verifier = apiKey ? new Verifier(hre.network, apiKey, hre.config.etherscan.customChains) : undefined;
      await new Task(args.id, TaskMode.LIVE, hre.network.name, verifier).run(args);
    }
  );

task('verify-contract', `Verify a task's deployment on a block explorer`)
  .addParam('id', 'Deployment task ID')
  .addParam('name', 'Contract name')
  .addParam('address', 'Contract address')
  .addParam('args', 'ABI-encoded constructor arguments')
  .addOptionalParam('key', 'Etherscan API key to verify contracts')
  .addOptionalParam('libraries', 'KV file of libraries', undefined, types.inputFile)
  .setAction(
    async (
      args: {
        id: string;
        name: string;
        address: string;
        key: string;
        args: string;
        libraries: string;
        verbose?: boolean;
      },
      hre: HardhatRuntimeEnvironment
    ) => {
      Logger.setDefaults(false, args.verbose || false);

      const libraries: Libraries = await hre.run(TASK_VERIFY_GET_LIBRARIES, {
        librariesModule: args.libraries,
      });

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const apiKey = args.key ?? (hre.config.networks[hre.network.name] as any).verificationAPIKey;
      const verifier = apiKey ? new Verifier(hre.network, apiKey, hre.config.etherscan.customChains) : undefined;

      // Contracts can only be verified in Live mode
      await new Task(args.id, TaskMode.LIVE, hre.network.name, verifier).verify(
        args.name,
        args.address,
        args.args,
        libraries
      );
    }
  );

task('extract-artifacts', `Extract contract artifacts from their build-info`)
  .addOptionalParam('id', 'Specific task ID')
  .setAction(async (args: { id?: string; verbose?: boolean }) => {
    Logger.setDefaults(false, args.verbose || false);

    if (args.id) {
      const task = new Task(args.id, TaskMode.READ_ONLY);
      extractArtifact(task);
    } else {
      const taskDirectory = path.resolve(__dirname, './tasks');

      for (const taskID of readdirSync(taskDirectory)) {
        const task = new Task(taskID, TaskMode.READ_ONLY);
        extractArtifact(task);
      }
    }
  });

task('check-deployments', `Check that all tasks' deployments correspond to their build-info and inputs`)
  .addOptionalParam('id', 'Specific task ID')
  .setAction(async (args: { id?: string; force?: boolean; verbose?: boolean }, hre: HardhatRuntimeEnvironment) => {
    // The force argument above is actually not passed (and not required or used in CHECK mode), but it is the easiest
    // way to address type issues.

    Logger.setDefaults(false, args.verbose || false);

    if (args.id) {
      await new Task(args.id, TaskMode.CHECK, hre.network.name).run(args);
    } else {
      const taskDirectory = path.resolve(__dirname, './tasks');

      for (const taskID of readdirSync(taskDirectory)) {
        const outputDir = path.resolve(taskDirectory, taskID, 'output');
        if (existsSync(outputDir) && statSync(outputDir).isDirectory()) {
          const outputFiles = readdirSync(outputDir);
          if (outputFiles.some((outputFile) => outputFile.includes(hre.network.name))) {
            // Not all tasks have outputs for all networks, so we skip those that don't
            await new Task(taskID, TaskMode.CHECK, hre.network.name).run(args);
          }
        }
      }
    }
  });

task('check-artifacts', `check that contract artifacts correspond to their build-info`)
  .addOptionalParam('id', 'Specific task ID')
  .setAction(async (args: { id?: string; verbose?: boolean }) => {
    Logger.setDefaults(false, args.verbose || false);

    if (args.id) {
      const task = new Task(args.id, TaskMode.READ_ONLY);
      checkArtifact(task);
    } else {
      const taskDirectory = path.resolve(__dirname, './tasks');

      for (const taskID of readdirSync(taskDirectory)) {
        const task = new Task(taskID, TaskMode.READ_ONLY);
        checkArtifact(task);
      }
    }
  });

task(TASK_TEST)
  .addOptionalParam('fork', 'Optional network name to be forked block number to fork in case of running fork tests.')
  .addOptionalParam('blockNumber', 'Optional block number to fork in case of running fork tests.', undefined, types.int)
  .setAction(test);

const config: HardhatUserConfig = {
  networks,
  mocha: {
    timeout: 600000,
  },
  etherscan: {
    customChains: [
      {
        network: 'boba',
        chainId: 288,
        urls: {
          browserURL: 'https://bobascan.com',
          apiURL: 'https://api.bobascan.com/api',
        },
      },
      {
        network: 'aurora',
        chainId: 1313161554,
        urls: {
          browserURL: 'https://aurorascan.dev',
          apiURL: 'https://api.aurorascan.dev/api',
        },
      },
      {
        network: 'moonriver',
        chainId: 1285,
        urls: {
          browserURL: 'https://moonriver.moonscan.io',
          apiURL: 'https://api-moonriver.moonscan.io/api',
        },
      },
      {
        network: 'polygon',
        chainId: 137,
        urls: {
          browserURL: 'https://polygonscan.com/',
          apiURL: 'https://api.polygonscan.com/api',
        },
      },
    ],
  },
};

export default config;
