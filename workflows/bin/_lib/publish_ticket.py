#!/usr/bin/env python3
"""Patch frontmatter, derive slug, write ticket to queue/. Print dest then title.

Usage: publish_ticket.py <src.md> <queue_dir> <id> <type> <now_iso>
Auto-fills id/type/status/author + parent_feature/priority/rescue_count/review_rounds
only if absent. created/updated are FORCED (script value always wins).
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

    def force(k: str, v: str) -> None:
        # Strip any existing top-level key line, then append the script value.
        nonlocal lines
        lines = [l for l in lines if not (":" in l and not l[:1].isspace() and l.split(":", 1)[0].strip() == k)]
        lines.append(f"{k}: {v}")

    ensure("id", tid)
    ensure("type", ttype)
    ensure("status", "queued")
    ensure("author", "technoking")
    ensure("parent_feature", "standalone")
    ensure("priority", "medium")
    ensure("rescue_count", "0")
    ensure("review_rounds", "0")
    force("created", now)
    force("updated", now)

    slug = re.sub(r"[^\w가-힣]+", "-", title, flags=re.UNICODE).strip("-").lower()[:40] or "untitled"
    dest = os.path.join(queue, f"{tid}-{slug}.md")
    with open(dest, "w") as f:
        f.write("---\n" + "\n".join(lines) + "\n---\n" + body)
    print(dest)
    print(title)


if __name__ == "__main__":
    main()
