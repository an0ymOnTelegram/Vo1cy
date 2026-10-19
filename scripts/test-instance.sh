#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/.build"
swiftc -O "$ROOT/Sources/Vo1cy/InstanceLease.swift" "$ROOT/Tests/InstanceLeaseProbe.swift" -o "$ROOT/.build/instance-probe"
python3 - "$ROOT/.build/instance-probe" <<'PY'
import pathlib, subprocess, sys, tempfile
binary = sys.argv[1]
children = []
def start(path):
    p = subprocess.Popen([binary, str(path)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    children.append(p)
    return p
try:
    with tempfile.TemporaryDirectory(prefix='vo1cy-instance-test-') as folder:
        lock = pathlib.Path(folder) / 'instance.lock'
        # Race real processes; all contenders remain alive until we release them.
        group = [start(lock) for _ in range(12)]
        replies = [p.stdout.readline().strip() for p in group]
        assert replies.count('owned') == 1 and replies.count('busy') == 11, replies
        winner = group[replies.index('owned')]
        for p, reply in zip(group, replies):
            if reply == 'busy': assert p.wait(timeout=5) == 3
        # Abrupt death releases the kernel lock without deleting/replacing inode.
        inode = lock.stat().st_ino
        winner.kill(); winner.wait(timeout=5)
        recovered = start(lock); assert recovered.stdout.readline().strip() == 'owned'
        assert lock.stat().st_ino == inode
        recovered.stdin.close(); assert recovered.wait(timeout=5) == 0
        # A leftover file/PID is not treated as a running instance.
        lock.write_text('123456 stale PID')
        fresh = start(lock); assert fresh.stdout.readline().strip() == 'owned'
        fresh.stdin.close(); assert fresh.wait(timeout=5) == 0
        link = pathlib.Path(folder) / 'symlink.lock'; link.symlink_to(lock)
        refused = start(link); assert refused.stdout.readline().strip() == 'error'
        assert refused.wait(timeout=5) == 4
    print('PASS: 12-process race, duplicate rejection, crash recovery, clean release, stale file, symlink refusal')
finally:
    for p in children:
        if p.poll() is None: p.kill()
        p.wait(timeout=5)
PY
