#!/usr/bin/env python3
"""Audit publishable source files and, optionally, an unpacked app bundle.

A bounded release check, not a guarantee of detecting every possible secret.
Ignored user data and build directories are never opened by the source audit.
"""
import argparse
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--app', type=Path)
parser.add_argument('--forbid', action='append', default=[], help='Additional private text to reject; never printed')
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
patterns = [
    ('personal home path', re.compile(rb'/(?:Users|home)/[^/\s"\x00]{2,}/', re.I)),
    ('private key', re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')),
    ('access token', re.compile(rb'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|AKIA[A-Z0-9]{16})\b')),
]
for value in args.forbid:
    patterns.append(('additional private text', re.compile(re.escape(value.encode()), re.I)))
paths = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=root).split(b'\0')
files = set()
for value in paths:
    if not value:
        continue
    p = root / value.decode()
    if p.is_file() and not p.is_symlink():
        files.add(p)
if args.app:
    files.update(p for p in args.app.rglob('*') if p.is_file() and not p.is_symlink())
failures = []
for p in sorted(files):
    relative = p.relative_to(root).as_posix() if p.is_relative_to(root) else p.relative_to(args.app).as_posix()
    if p.is_relative_to(root) and (p.suffix.lower() in {'.wav', '.mp3', '.m4a', '.p12', '.p8', '.key', '.keychain-db'} or p.name in {'settings.json', 'history.json', '.env'}):
        failures.append((relative, 'private file type'))
    data = p.read_bytes()
    for label, pattern in patterns:
        if pattern.search(data):
            failures.append((relative, label))
if failures:
    for path, label in failures:
        print(f'FAIL: {path}: {label}')
    raise SystemExit(1)
print(f'PASS: {len(files)} source/bundle files checked; no configured privacy or credential pattern found.')
