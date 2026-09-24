#!/usr/bin/env bash
set -euo pipefail
mkdir -p /tmp/openclaw-catalog-validation
exec > >(tee /tmp/openclaw-catalog-validation/run.log) 2>&1
printf 'Source base: 2f2d7aa81289ae954f6ff1c270114bae0ad36c82\n'
git rev-parse HEAD
git diff --exit-code 2f2d7aa81289ae954f6ff1c270114bae0ad36c82 HEAD -- . ':(exclude).github/workflows/codex-catalog-memory-validation.yml' ':(exclude).github/diagnostics/catalog-validation.sh' ':(exclude).github/diagnostics/augment-native-renewal.py'
node --version
pnpm --version
/usr/bin/time -v pnpm install --frozen-lockfile
/usr/bin/time -v node scripts/run-node.mjs --version
/usr/bin/time -v pnpm test \
  src/agents/prepared-model-catalog-worker.native-renewal.integration.test.ts \
  src/agents/prepared-model-catalog-worker.scope.integration.test.ts \
  src/agents/prepared-model-catalog-worker.pool.integration.test.ts \
  src/agents/prepared-model-catalog-worker.directory.test.ts \
  src/agents/prepared-model-catalog-worker.secrets.test.ts \
  src/agents/prepared-model-catalog-worker.mismatch.integration.test.ts \
  --maxWorkers=1
python3 .github/diagnostics/augment-native-renewal.py src/agents/prepared-model-catalog-worker.native-renewal.integration.test.ts
/usr/bin/time -v pnpm test src/agents/prepared-model-catalog-worker.native-renewal.integration.test.ts --maxWorkers=1
