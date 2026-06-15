#!/usr/bin/env python3
"""Atomically increment a registry counter; print the zero-padded ID (e.g. T-0007).

Usage: counter.py <registry.json> <lockfile> <key>
Lock is an exclusive fcntl advisory lock (macOS-safe, auto-released on process death).
"""
import json
import os
import sys
import fcntl


def main() -> None:
    registry, lock, key = sys.argv[1], sys.argv[2], sys.argv[3]
    with open(lock, "w") as lf:
        fcntl.flock(lf, fcntl.LOCK_EX)
        with open(registry) as f:
            reg = json.load(f)
        counters = reg.setdefault("counters", {})
        counters[key] = int(counters.get(key, 0)) + 1
        n = counters[key]
        tmp = registry + ".tmp"
        with open(tmp, "w") as f:
            json.dump(reg, f, indent=2, ensure_ascii=False)
            f.write("\n")
        os.replace(tmp, registry)
        # advisory lock released when lf closes
    print(f"{key}-{n:04d}")


if __name__ == "__main__":
    main()
