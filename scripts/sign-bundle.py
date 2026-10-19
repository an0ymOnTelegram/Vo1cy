#!/usr/bin/env python3
"""Sign nested code before the app; no private key material is read or exported."""
import pathlib
import subprocess
import sys

app = pathlib.Path(sys.argv[1]).resolve()
identity = sys.argv[2]
def sign(path):
    args = ["codesign", "--force", "--sign", identity, "--options", "runtime", "--timestamp", "--preserve-metadata=entitlements"]
    if path == app:
        args += ["--entitlements", str(pathlib.Path(__file__).resolve().parent.parent / "Resources" / "Vo1cy.entitlements")]
    subprocess.run(args + [str(path)], check=True)

for path in sorted(app.rglob("*"), key=lambda p: len(p.parts), reverse=True):
    if path.is_symlink() or not path.is_file():
        continue
    kind = subprocess.check_output(["file", "-b", str(path)], text=True)
    if "Mach-O" in kind:
        sign(path)
for path in sorted(app.rglob("*"), key=lambda p: len(p.parts), reverse=True):
    if path.is_dir() and not path.is_symlink() and path.suffix in {".framework", ".xpc", ".app"}:
        sign(path)
sign(app)
