#!/usr/bin/env python3
"""Run a command while holding an exclusive fcntl lock (macOS-safe, auto-released on death).

Usage: with_lock.py <lockfile> <cmd> [args...]
Exits with the wrapped command's exit code.
"""
import fcntl
import subprocess
import sys


def main() -> None:
    if len(sys.argv) < 3:
        print("usage: with_lock.py <lockfile> <cmd...>", file=sys.stderr)
        sys.exit(2)
    lock, cmd = sys.argv[1], sys.argv[2:]
    with open(lock, "w") as lf:
        fcntl.flock(lf, fcntl.LOCK_EX)
        sys.exit(subprocess.call(cmd))


if __name__ == "__main__":
    main()
