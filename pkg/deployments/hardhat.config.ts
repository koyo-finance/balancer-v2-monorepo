import '@balancer-labs/v2-common/setupTests';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import { existsSync, readdirSync, statSync } from 'fs';
import 'hardhat-local-networks-config-plugin';
import { TASK_TEST } from 'hardhat/builtin-tasks/task-names';
import { task, types } from 'hardhat/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import path from 'path';
import { checkArtifact, extractArtifact } from './src/artifact';
import { Logger } from './src/logger';
import Task, { TaskMode } from './src/task';
import test from './src/test';

task('deploy', 'Run deployment task')
  .addParam('id', 'Deployment task ID')
  .addFlag('force', 'Ignore previous deployments')
  .addOptionalParam('key', 'Etherscan API key to verify contracts')
  .setAction(
    async (args: { id: string; force?: boolean; key?: string; verbose?: boolean }, hre: HardhatRuntimeEnvironment) => {
      Logger.setDefaults(false, args.verbose || false);

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      await new Task(args.id, TaskMode.LIVE, hre.network.name).run(args);
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

export default {
  mocha: {
    timeout: 600000,
  },
};
