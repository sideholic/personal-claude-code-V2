#!/usr/bin/env python3
"""Patch frontmatter, derive slug, write ticket to queue/. Print dest then title.

Usage: publish_ticket.py <src.md> <queue_dir> <id> <type> <now_iso>
Auto-fills id/type/status/created/updated/author only if absent.
"""
import os
import re
import sys


def main() -> None:
    src, queue, tid, ttype, now = sys.argv[1:6]
    text = open(src).read()
    m = re.match(r"^---\n(.*?)\n---\n?(.*)$", text, re.S)
    fm, body = (m.group(1), m.group(2)) if m else ("", text)
    lines = fm.splitlines()
    present = {
        l.split(":", 1)[0].strip(): l.split(":", 1)[1].strip()
        for l in lines
        if ":" in l and not l[:1].isspace()
    }
    title = (present.get("title", "") or "untitled").strip().strip('"').strip("'")

    def ensure(k: str, v: str) -> None:
        if k not in present:
            lines.append(f"{k}: {v}")

    ensure("id", tid)
    ensure("type", ttype)
    ensure("status", "queued")
    ensure("created", now)
    ensure("updated", now)
    ensure("author", "technoking")

    slug = re.sub(r"[^\w가-힣]+", "-", title, flags=re.UNICODE).strip("-").lower()[:40] or "untitled"
    dest = os.path.join(queue, f"{tid}-{slug}.md")
    with open(dest, "w") as f:
        f.write("---\n" + "\n".join(lines) + "\n---\n" + body)
    print(dest)
    print(title)


if __name__ == "__main__":
    main()
