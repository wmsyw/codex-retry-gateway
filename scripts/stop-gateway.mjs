#!/usr/bin/env node

import {
  DEFAULT_STATE_ROOT,
  parseOptions,
  stopGateway,
} from "./admin-lib.mjs";

async function main() {
  const options = parseOptions(process.argv, { booleanFlags: ["quiet", "skip-restore"] });
  const message = await stopGateway({
    stateRoot: options.stateRoot || DEFAULT_STATE_ROOT,
    quiet: Boolean(options.quiet),
    restoreBackup: !options.skipRestore,
  });

  if (message) {
    process.stdout.write(`${message}\n`);
  }
}

main().catch((error) => {
  process.stderr.write(`${error?.stack || error}\n`);
  process.exit(1);
});
