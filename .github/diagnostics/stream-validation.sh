#!/usr/bin/env bash
set -euo pipefail
mkdir -p /tmp/openclaw-stream-validation
exec > >(tee /tmp/openclaw-stream-validation/run.log) 2>&1
printf 'PR base: 7e6e65ee71cbd1a82450c661f420eae5223a3665\n'
git rev-parse HEAD
git diff --exit-code 731d1556d38b382898acedd4a43d109a3e1b5228 HEAD -- . ':(exclude).github/workflows/codex-stream-memory-validation.yml' ':(exclude).github/diagnostics/stream-validation.sh' ':(exclude).github/diagnostics/check-short-write-red.py' ':(exclude).github/diagnostics/record-tested-tree.py'
node --version
pnpm --version
/usr/bin/time -v pnpm install --frozen-lockfile
pnpm exec oxfmt --write src/plugins/plugin-source-stream-capture.ts src/plugins/plugin-package-metadata-capture.test.ts
pnpm exec oxfmt --check src/plugins/plugin-source-stream-capture.ts src/plugins/plugin-package-metadata-capture.test.ts
git diff --binary -- src/plugins/plugin-source-stream-capture.ts src/plugins/plugin-package-metadata-capture.test.ts > /tmp/openclaw-stream-validation/formatting.patch
cp src/plugins/plugin-package-metadata-capture.test.ts /tmp/openclaw-stream-validation/formatted-test.ts
cp src/plugins/plugin-source-stream-capture.ts /tmp/openclaw-stream-validation/formatted-helper.ts
python3 .github/diagnostics/record-tested-tree.py
cp /tmp/openclaw-stream-validation/tested-source.json /tmp/openclaw-stream-validation/initial-tested-source.json
/usr/bin/time -v node scripts/run-node.mjs --version
cp src/plugins/plugin-source-stream-capture.ts /tmp/openclaw-stream-validation/fixed-source.ts
git show 7e6e65ee71cbd1a82450c661f420eae5223a3665:src/plugins/plugin-source-stream-capture.ts > src/plugins/plugin-source-stream-capture.ts
set +e
/usr/bin/time -v pnpm test src/plugins/plugin-package-metadata-capture.test.ts --maxWorkers=1 -t 'short write' --reporter=json --outputFile=/tmp/openclaw-stream-validation/red.json
red_status=$?
set -e
cp /tmp/openclaw-stream-validation/fixed-source.ts src/plugins/plugin-source-stream-capture.ts
if [ "$red_status" -ne 1 ]; then
  printf 'Expected assertion failure from original implementation; got exit %s\n' "$red_status"
  exit 1
fi
/usr/bin/time -v pnpm test src/plugins/plugin-package-metadata-capture.test.ts src/plugins/plugin-generation-artifact.test.ts src/plugins/plugin-generation-artifact.ownership.test.ts --maxWorkers=1 --reporter=json --outputFile=/tmp/openclaw-stream-validation/green.json
/usr/bin/time -v node scripts/run-oxlint.mjs --tsconfig config/tsconfig/oxlint.core.json src/plugins/plugin-source-stream-capture.ts src/plugins/plugin-package-metadata-capture.test.ts
/usr/bin/time -v node scripts/run-tsgo-core-test-shards.mjs --changed-paths-json '["src/plugins/plugin-package-metadata-capture.test.ts"]'
python3 .github/diagnostics/record-tested-tree.py
cmp /tmp/openclaw-stream-validation/initial-tested-source.json /tmp/openclaw-stream-validation/tested-source.json
python3 .github/diagnostics/check-short-write-red.py /tmp/openclaw-stream-validation/red.json
