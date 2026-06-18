#!/usr/bin/env python3
"""Atomically transition a ticket: move between status dirs and patch script-owned fields.

Usage: transition_ticket.py <team_dir> <id|path> <now_iso> [--to STATUS]
       [--bump-rescue] [--progress-note TEXT]
STATUS: queued|in_progress|in_review|done|cancelled.
Script-owned fields only: status/updated/started/done/last_activity_at/rescue_count/
review_rounds. Agent-owned fields and body are preserved verbatim.
State machine: queued->in_progress->in_review->done; cancelled from any.
Re-entry into in_review is allowed (in_progress->in_review and in_review->in_review)
and bumps review_rounds. done/ is permanent (no transition out of done).
Atomic: write temp, os.replace into dest, then remove the old file (counter.py pattern).
Prints "status=<s>" "dest=<path>" "review_rounds=<n>" "rescue_count=<n>" for the wrapper.
"""
import os
import re
import sys

DIRS = {
    "queued": "queue",
    "in_progress": "in-progress",
    "in_review": "in-review",
    "done": "done",
    "cancelled": "cancelled",
}
# status -> set of statuses reachable from it (cancelled allowed from any).
ALLOWED = {
    "queued": {"in_progress", "cancelled"},
    "in_progress": {"in_review", "cancelled"},
    "in_review": {"done", "in_review", "cancelled"},
    "done": set(),
    "cancelled": set(),
}


def die(msg: str) -> None:
    print(msg, file=sys.stderr)
    sys.exit(1)


def locate(team_dir: str, ref: str) -> str:
    if os.path.isfile(ref):
        return ref
    for sub in DIRS.values():
        d = os.path.join(team_dir, "tickets", sub)
        if not os.path.isdir(d):
            continue
        for name in os.listdir(d):
            if name == f"{ref}.md" or name.startswith(f"{ref}-"):
                return os.path.join(d, name)
    die(f"ticket not found: {ref}")


def main() -> None:
    team_dir, ref, now = sys.argv[1:4]
    to = None
    bump_rescue = False
    note = None
    args = sys.argv[4:]
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--to":
            to = args[i + 1]; i += 2
        elif a == "--bump-rescue":
            bump_rescue = True; i += 1
        elif a == "--progress-note":
            note = args[i + 1]; i += 2
        else:
            die(f"unknown arg: {a}")
    if to is not None and to not in DIRS:
        die(f"invalid status: {to} ({'|'.join(DIRS)})")

    src = locate(team_dir, ref)
    text = open(src).read()
    m = re.match(r"^---\n(.*?)\n---\n?(.*)$", text, re.S)
    fm, body = (m.group(1), m.group(2)) if m else ("", text)
    lines = fm.splitlines()

    def get(k: str):
        for l in lines:
            if ":" in l and not l[:1].isspace() and l.split(":", 1)[0].strip() == k:
                return l.split(":", 1)[1].strip()
        return None

    def set_(k: str, v: str) -> None:
        nonlocal lines
        out, done = [], False
        for l in lines:
            if ":" in l and not l[:1].isspace() and l.split(":", 1)[0].strip() == k:
                if not done:
                    out.append(f"{k}: {v}"); done = True
            else:
                out.append(l)
        if not done:
            out.append(f"{k}: {v}")
        lines = out

    cur = get("status") or "queued"
    review_rounds = int(get("review_rounds") or 0)
    rescue_count = int(get("rescue_count") or 0)

    if to is not None and to != cur:
        if to not in ALLOWED.get(cur, set()):
            die(f"illegal transition: {cur} -> {to}")
    if cur == "done" and to is not None and to != "done":
        die("done/ is permanent; cannot transition out of done")

    if bump_rescue:
        rescue_count += 1
        set_("rescue_count", str(rescue_count))

    if note is not None:
        set_("progress_note", note)

    if to is not None:
        set_("status", to)
        if to == "in_progress" and get("started") is None:
            set_("started", now)
        if to in ("done", "cancelled") and get("done") is None:
            set_("done", now)
        if to == "in_review":
            review_rounds += 1
            set_("review_rounds", str(review_rounds))

    set_("updated", now)
    set_("last_activity_at", now)

    # Destination: same dir for note/rescue-only, target dir for a status change.
    new_status = to if to is not None else cur
    dest_dir = os.path.join(team_dir, "tickets", DIRS[new_status])
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, os.path.basename(src))

    tmp = dest + ".tmp"
    with open(tmp, "w") as f:
        f.write("---\n" + "\n".join(lines) + "\n---\n" + body)
    os.replace(tmp, dest)
    if os.path.abspath(src) != os.path.abspath(dest):
        os.remove(src)

    print(f"status={new_status}")
    print(f"dest={dest}")
    print(f"review_rounds={review_rounds}")
    print(f"rescue_count={rescue_count}")


if __name__ == "__main__":
    main()
