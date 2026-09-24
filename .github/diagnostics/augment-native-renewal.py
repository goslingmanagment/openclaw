#!/usr/bin/env python3
"""Add diagnostic assertions to one fixture; never change production source."""
from pathlib import Path
import hashlib
import sys

target = Path(sys.argv[1])
source = target.read_text()
original = source
expected_sha256 = "88da617a9fee29a086dedd1e47f627f5a2af9d178cbfb676056319d61a90b1b7"
if hashlib.sha256(source.encode()).hexdigest() != expected_sha256:
    raise SystemExit("Fixture bytes differ from verified PR head 2f2d7aa81289ae954f6ff1c270114bae0ad36c82")

def replace_once(before: str, after: str) -> None:
    global source
    if source.count(before) != 1:
        raise SystemExit(f"Expected exactly one immutable-head fixture anchor: {before[:100]!r}")
    source = source.replace(before, after)

replace_once('import { performance } from "node:perf_hooks";\n',
             'import { performance } from "node:perf_hooks";\nimport { threadId } from "node:worker_threads";\n')
replace_once('  const admissionMs: number[] = [];\n', '''  const admissionMs: number[] = [];
  const captureProof: Array<{
    revision: number;
    registrations: number;
    workerRegistrations: number;
    captures: Array<{ thread: number; filename: string; realpath: string; dev: number; ino: number; bytes: number }>;
  }> = [];
''')
replace_once('JSON.stringify({ thread: require("node:worker_threads").threadId })',
             'JSON.stringify({ thread: require("node:worker_threads").threadId, filename: __filename })')
replace_once('    const preparedRegistrations = fs.readFileSync(registrations, "utf8");\n', '''    const preparedRegistrations = fs.readFileSync(registrations, "utf8");
    const inspectCaptures = () => fs.readFileSync(registrations, "utf8").trim().split("\\n").filter(Boolean).map((line) => {
      const registration = JSON.parse(line) as { thread: number; filename: string };
      const stat = fs.statSync(registration.filename);
      return { ...registration, realpath: fs.realpathSync(registration.filename), dev: stat.dev, ino: stat.ino, bytes: stat.size };
    });
    const preparedCaptures = inspectCaptures();
    expect(preparedCaptures.some((entry) => entry.thread !== threadId), "positive control: actual catalog Worker registered the plugin").toBe(true);
    for (const entry of preparedCaptures.filter((candidate) => candidate.thread !== threadId)) {
      expect(entry.filename, "positive control: worker code came from a captured generation").toContain("openclaw-plugin-build-");
    }
    const recordCaptureProof = (cycle: number) => {
      const captures = inspectCaptures();
      expect(captures, "renewal must preserve registration paths, realpaths and file identities").toEqual(preparedCaptures);
      captureProof.push({ revision: cycle, registrations: captures.length, workerRegistrations: captures.filter((entry) => entry.thread !== threadId).length, captures });
    };
    recordCaptureProof(0);
''')
replace_once('      for (const [index, snapshot] of snapshots.entries()) {\n',
             '      recordCaptureProof(revision);\n      for (const [index, snapshot] of snapshots.entries()) {\n')
replace_once('        taskMetrics,\n', '        taskMetrics,\n        captureProof,\n')

target.write_text(source)
print("Diagnostic test-only overlay applied")
print("original_sha256=" + hashlib.sha256(original.encode()).hexdigest())
print("instrumented_sha256=" + hashlib.sha256(source.encode()).hexdigest())
print("target=" + str(target))
