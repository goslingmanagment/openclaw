import hashlib, json, os, subprocess
from pathlib import Path
files = ["src/plugins/plugin-source-stream-capture.ts", "src/plugins/plugin-package-metadata-capture.test.ts"]
subprocess.run(["git", "diff", "--exit-code", "HEAD", "--", ".", *[":(exclude)" + name for name in files]], check=True)
env = dict(os.environ, GIT_INDEX_FILE="/tmp/openclaw-stream-validation/product.index")
subprocess.run(["git", "read-tree", "9ba1f0bab890b871710c0b025775b9a1f106cb47"], env=env, check=True)
subprocess.run(["git", "add", "--", *files], env=env, check=True)
tree = subprocess.check_output(["git", "write-tree"], env=env, text=True).strip()
proof = {"product_tree": tree, "files": {name: hashlib.sha256(Path(name).read_bytes()).hexdigest() for name in files}}
Path("/tmp/openclaw-stream-validation/tested-source.json").write_text(json.dumps(proof, indent=2) + "\n")
print(json.dumps(proof, indent=2))
