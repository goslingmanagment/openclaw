import json, sys
from pathlib import Path
report = json.loads(Path(sys.argv[1]).read_text())
failed = [test for suite in report["testResults"] for test in suite["assertionResults"] if test["status"] == "failed"]
expected = {
    "writes each chunk completely after short writes",
    "fails and closes both descriptors on zero progress after a short write",
    "fails and closes both descriptors on ENOSPC after a short write",
}
actual = {test["title"] for test in failed}
if actual != expected or len(failed) != 3 or report["numFailedTestSuites"] != 1 or report["numFailedTests"] != 3:
    raise SystemExit("Original implementation did not fail exactly the three short-write regressions: " + repr(actual))
for test in failed:
    messages = "\n".join(test.get("failureMessages", []))
    if "AssertionError" not in messages:
        raise SystemExit("Expected assertion failure, got: " + messages)
    fragments = ("1573253", "3146505") if test["title"].startswith("writes each") else ("to throw an error",)
    if not all(fragment in messages for fragment in fragments):
        raise SystemExit("Failure did not demonstrate the original short-write defect: " + messages)
print("RED verified: original implementation fails exactly all three short-write regressions")
for test in failed:
    print(test["title"])
    print("\n".join(test.get("failureMessages", [])))
