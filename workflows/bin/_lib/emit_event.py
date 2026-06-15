#!/usr/bin/env python3
"""Append one event line to events.jsonl.

Usage: emit_event.py <log> <event> <seq> <ts> <actor> <ticket> <feature> <data_json>
Empty ticket/feature become null. Invalid data_json is wrapped as {"_raw": ...}.
"""
import json
import sys


def main() -> None:
    log, event, seq, ts, actor, ticket, feature, data = sys.argv[1:9]
    try:
        d = json.loads(data) if data else {}
    except Exception:
        d = {"_raw": data}
    rec = {
        "v": 1,
        "seq": int(seq),
        "ts": ts,
        "event": event,
        "feature": feature or None,
        "ticket": ticket or None,
        "actor": actor,
        "data": d,
    }
    with open(log, "a") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
