#!/usr/bin/env bash
set -euo pipefail
proof_dir=/tmp/openclaw-compact-validation
mkdir -p "$proof_dir"
exec > >(tee "$proof_dir/run.log") 2>&1
fixed_commit=f280e98c6963c621d39f2d9124e4c708c9aa2362
original_commit=052cc590865fbeaca9c44abee84a1435936aa6ea
source_path=src/agents/embedded-agent-runner/compact.ts
test_path=src/agents/embedded-agent-runner/compact.native-cli.test.ts
git rev-parse HEAD
git diff --exit-code "$fixed_commit" HEAD -- . \
  ':(exclude).github/workflows/codex-compact-account-validation.yml' \
  ':(exclude).github/diagnostics/compact-validation.sh'
node --version
pnpm --version
/usr/bin/time -v pnpm install --frozen-lockfile
pnpm exec oxfmt --write "$source_path" "$test_path"
pnpm exec oxfmt --check "$source_path" "$test_path"
git diff --binary -- "$source_path" "$test_path" > "$proof_dir/formatting.patch"
cp "$source_path" "$proof_dir/fixed-source.ts"
cp "$test_path" "$proof_dir/formatted-test.ts"
sha256sum "$source_path" "$test_path" > "$proof_dir/tested-source.sha256"
git show "$original_commit:$source_path" > "$source_path"
set +e
/usr/bin/time -v pnpm test "$test_path" --maxWorkers=1 \
  --reporter=json --outputFile="$proof_dir/red.json"
red_status=$?
set -e
cp "$proof_dir/fixed-source.ts" "$source_path"
if [ "$red_status" -ne 1 ]; then
  printf 'Expected an assertion failure from the original implementation; got exit %s\n' "$red_status"
  exit 1
fi
python3 - <<'PY'
import json
from pathlib import Path
report = json.loads(Path('/tmp/openclaw-compact-validation/red.json').read_text())
assert report['numTotalTests'] == 5, report
assert report['numFailedTests'] == 1, report
assert report['numPassedTests'] == 4, report
failed = [a for s in report['testResults'] for a in s['assertionResults'] if a['status'] == 'failed']
assert len(failed) == 1, failed
assert 'channel-account' in failed[0]['fullName'], failed
assert 'retires the matching warm owner through the native command' in failed[0]['fullName'], failed
assert any('spy' in m.lower() or 'compacted' in m.lower() for m in failed[0]['failureMessages']), failed
print('RED VERIFIED: only the account-scoped compaction regression fails on the original source.')
PY
/usr/bin/time -v pnpm test \
  src/agents/cli-runner.spawn.test.ts \
  src/agents/cli-runner/cli-live-session-registry.test.ts \
  "$test_path" --maxWorkers=1 --reporter=json --outputFile="$proof_dir/green.json"
/usr/bin/time -v node scripts/run-oxlint.mjs --tsconfig config/tsconfig/oxlint.core.json \
  "$source_path" "$test_path"
/usr/bin/time -v node scripts/run-tsgo-core-test-shards.mjs \
  --changed-paths-json '["src/agents/embedded-agent-runner/compact.native-cli.test.ts"]'
sha256sum --check "$proof_dir/tested-source.sha256"
git diff --check
printf 'PASS: original-source failure verified; patched tests, format, lint, and test-shard types passed.\n'
