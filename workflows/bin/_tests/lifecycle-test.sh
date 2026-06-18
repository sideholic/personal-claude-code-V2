#!/usr/bin/env bash
# lifecycle-test.sh — end-to-end integration test for the ticket lifecycle.
# Drives the REAL scripts (ticket-publish.sh + ticket-transition.sh) through the full
# state machine exactly as the wired call-sites invoke them, against a TEMP team dir.
# Asserts frontmatter + events.jsonl at each step. Prints PASS/FAIL summary.
set -uo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLISH="$BIN_DIR/ticket-publish.sh"
TRANSITION="$BIN_DIR/ticket-transition.sh"

TEAM_DIR="$(mktemp -d)"
export CLAUDE_TEAM_DIR="$TEAM_DIR"
trap 'rm -rf "$TEAM_DIR"' EXIT

EVENTS="$TEAM_DIR/events.jsonl"
FAILS=0
PASSES=0

pass() { PASSES=$((PASSES + 1)); printf '  PASS  %s\n' "$1"; }
fail() { FAILS=$((FAILS + 1)); printf '  FAIL  %s\n' "$1" >&2; }

# assert <description> <condition-exit-code>
check() {
  local desc="$1"; shift
  if "$@"; then pass "$desc"; else fail "$desc"; fi
}

# fm <file> <key> -> prints the value of a top-level frontmatter key
fm() {
  python3 - "$1" "$2" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
m = re.match(r"^---\n(.*?)\n---\n?", text, re.S)
fmtext = m.group(1) if m else ""
key = sys.argv[2]
for l in fmtext.splitlines():
    if ":" in l and not l[:1].isspace() and l.split(":", 1)[0].strip() == key:
        print(l.split(":", 1)[1].strip()); break
PY
}

# body <file> -> prints the markdown body (after frontmatter)
body() {
  python3 - "$1" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
m = re.match(r"^---\n.*?\n---\n?(.*)$", text, re.S)
print(m.group(1) if m else text, end="")
PY
}
# Export helpers so the `bash -c` subshells used by check() can call them.
export -f fm body

# event_count <event> -> number of events.jsonl lines whose "event" == arg
event_count() {
  [ -f "$EVENTS" ] || { echo 0; return; }
  python3 - "$EVENTS" "$1" <<'PY'
import json, sys
n = 0
for line in open(sys.argv[1]):
    line = line.strip()
    if not line:
        continue
    if json.loads(line).get("event") == sys.argv[2]:
        n += 1
print(n)
PY
}

# last_event_data <event> <key> -> data[key] of the last event of that type
last_event_data() {
  python3 - "$EVENTS" "$1" "$2" <<'PY'
import json, sys
val = ""
for line in open(sys.argv[1]):
    line = line.strip()
    if not line:
        continue
    r = json.loads(line)
    if r.get("event") == sys.argv[2]:
        val = r.get("data", {}).get(sys.argv[3], "")
print(val)
PY
}

total_events() { [ -f "$EVENTS" ] && grep -c . "$EVENTS" || echo 0; }

is_full_ts() { [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:[0-9]{2}$ ]]; }

# ---- seed minimal team dir (registry.json must match counter.py expectations) ----
mkdir -p "$TEAM_DIR/workers"
cat > "$TEAM_DIR/workers/registry.json" <<'JSON'
{
  "counters": { "T": 0, "RV": 0, "BL": 0 }
}
JSON

echo "=== ticket lifecycle integration test ==="
echo "TEAM_DIR=$TEAM_DIR"
echo

# ============================================================================
# HAPPY PATH
# ============================================================================
echo "--- happy path ---"

DRAFT="$TEAM_DIR/draft1.md"
cat > "$DRAFT" <<'MD'
---
title: Wire transition call-sites
created: 2026-01-01
agent_owner: persistence-paladin
custom_field: keepme
---
## Body
This body must survive end-to-end.

- line two
MD

ID="$("$PUBLISH" work "$DRAFT" 2>/dev/null)"
check "publish returned a T-id" bash -c "[[ '$ID' =~ ^T-[0-9]{4}$ ]]"

QFILE="$(ls "$TEAM_DIR"/tickets/queue/"$ID"-*.md 2>/dev/null | head -1)"
check "ticket file in queue/" test -n "$QFILE"

# created FORCE-overwritten to a full ISO8601+TZ (not the date-only 2026-01-01)
CREATED="$(fm "$QFILE" created)"
check "created force-overwritten (not date-only)" bash -c "[ '$CREATED' != '2026-01-01' ]"
check "created is full ISO8601+TZ" is_full_ts "$CREATED"
check "updated set (full TS)" is_full_ts "$(fm "$QFILE" updated)"

# defaults injected
check "default parent_feature=standalone" bash -c "[ '$(fm "$QFILE" parent_feature)' = 'standalone' ]"
check "default priority=medium" bash -c "[ '$(fm "$QFILE" priority)' = 'medium' ]"
check "default rescue_count=0" bash -c "[ '$(fm "$QFILE" rescue_count)' = '0' ]"
check "default review_rounds=0" bash -c "[ '$(fm "$QFILE" review_rounds)' = '0' ]"

# agent field + title preserved
check "custom agent field preserved" bash -c "[ '$(fm "$QFILE" custom_field)' = 'keepme' ]"
check "agent_owner preserved" bash -c "[ '$(fm "$QFILE" agent_owner)' = 'persistence-paladin' ]"
check "title preserved" bash -c "[ '$(fm "$QFILE" title)' = 'Wire transition call-sites' ]"
check "body preserved at publish" bash -c "body '$QFILE' | grep -q 'This body must survive end-to-end.'"

# event ticket.published
check "event ticket.published x1" bash -c "[ '$(event_count ticket.published)' = '1' ]"

# 2) --to in_progress
"$TRANSITION" "$ID" --to in_progress >/dev/null 2>&1
IPFILE="$(ls "$TEAM_DIR"/tickets/in-progress/"$ID"-*.md 2>/dev/null | head -1)"
check "moved to in-progress/" test -n "$IPFILE"
check "queue/ entry gone" bash -c "[ -z \"\$(ls "$TEAM_DIR"/tickets/queue/"$ID"-*.md 2>/dev/null)\" ]"
check "status=in_progress" bash -c "[ '$(fm "$IPFILE" status)' = 'in_progress' ]"
check "started injected (full TS)" is_full_ts "$(fm "$IPFILE" started)"
check "last_activity_at set (full TS)" is_full_ts "$(fm "$IPFILE" last_activity_at)"
check "event ticket.claimed x1" bash -c "[ '$(event_count ticket.claimed)' = '1' ]"

# 3) --progress-note (note-only: no event, no move, status unchanged)
PREV_LAST="$(fm "$IPFILE" last_activity_at)"
PREV_EVENTS="$(total_events)"
sleep 1  # ensure a distinct timestamp so last_activity_at can be observed to bump
"$TRANSITION" "$ID" --progress-note "step 1 done" >/dev/null 2>&1
IPFILE="$(ls "$TEAM_DIR"/tickets/in-progress/"$ID"-*.md 2>/dev/null | head -1)"
check "still in in-progress/" test -n "$IPFILE"
check "progress_note set" bash -c "[ '$(fm "$IPFILE" progress_note)' = 'step 1 done' ]"
check "status unchanged (in_progress)" bash -c "[ '$(fm "$IPFILE" status)' = 'in_progress' ]"
check "last_activity_at bumped" bash -c "[ '$(fm "$IPFILE" last_activity_at)' != '$PREV_LAST' ]"
check "note-only added NO event line" bash -c "[ '$(total_events)' = '$PREV_EVENTS' ]"

# 4) --to in_review
"$TRANSITION" "$ID" --to in_review >/dev/null 2>&1
IRFILE="$(ls "$TEAM_DIR"/tickets/in-review/"$ID"-*.md 2>/dev/null | head -1)"
check "moved to in-review/" test -n "$IRFILE"
check "review_rounds=1" bash -c "[ '$(fm "$IRFILE" review_rounds)' = '1' ]"
check "event ticket.review x1" bash -c "[ '$(event_count ticket.review)' = '1' ]"
check "ticket.review carries round=1" bash -c "[ '$(last_event_data ticket.review round)' = '1' ]"

# 5) --bump-rescue (no status change)
"$TRANSITION" "$ID" --bump-rescue >/dev/null 2>&1
IRFILE="$(ls "$TEAM_DIR"/tickets/in-review/"$ID"-*.md 2>/dev/null | head -1)"
check "rescue_count=1" bash -c "[ '$(fm "$IRFILE" rescue_count)' = '1' ]"
check "event rescue.triggered x1" bash -c "[ '$(event_count rescue.triggered)' = '1' ]"
check "status still in_review after rescue" bash -c "[ '$(fm "$IRFILE" status)' = 'in_review' ]"

# 6) --to in_review again (re-entry -> round bump)
"$TRANSITION" "$ID" --to in_review >/dev/null 2>&1
IRFILE="$(ls "$TEAM_DIR"/tickets/in-review/"$ID"-*.md 2>/dev/null | head -1)"
check "review_rounds=2 on re-entry" bash -c "[ '$(fm "$IRFILE" review_rounds)' = '2' ]"
check "event ticket.review x2" bash -c "[ '$(event_count ticket.review)' = '2' ]"
check "ticket.review carries round=2" bash -c "[ '$(last_event_data ticket.review round)' = '2' ]"

# 7) --to done
"$TRANSITION" "$ID" --to done >/dev/null 2>&1
DONEFILE="$(ls "$TEAM_DIR"/tickets/done/"$ID"-*.md 2>/dev/null | head -1)"
check "moved to done/" test -n "$DONEFILE"
check "status=done" bash -c "[ '$(fm "$DONEFILE" status)' = 'done' ]"
check "done injected (full TS)" is_full_ts "$(fm "$DONEFILE" done)"
check "event ticket.done x1" bash -c "[ '$(event_count ticket.done)' = '1' ]"
# end-to-end integrity
check "agent field intact end-to-end" bash -c "[ '$(fm "$DONEFILE" custom_field)' = 'keepme' ]"
check "agent_owner intact end-to-end" bash -c "[ '$(fm "$DONEFILE" agent_owner)' = 'persistence-paladin' ]"
check "title intact end-to-end" bash -c "[ '$(fm "$DONEFILE" title)' = 'Wire transition call-sites' ]"
check "body intact end-to-end" bash -c "body '$DONEFILE' | grep -q 'This body must survive end-to-end.'"

echo

# ============================================================================
# CANCEL PATH
# ============================================================================
echo "--- cancel path ---"

DRAFT2="$TEAM_DIR/draft2.md"
cat > "$DRAFT2" <<'MD'
---
title: Cancel me
---
## Body
cancel path body
MD

ID2="$("$PUBLISH" work "$DRAFT2" 2>/dev/null)"
"$TRANSITION" "$ID2" --to in_progress >/dev/null 2>&1
"$TRANSITION" "$ID2" --to cancelled >/dev/null 2>&1
CFILE="$(ls "$TEAM_DIR"/tickets/cancelled/"$ID2"-*.md 2>/dev/null | head -1)"
check "cancelled ticket in cancelled/" test -n "$CFILE"
check "status=cancelled" bash -c "[ '$(fm "$CFILE" status)' = 'cancelled' ]"
check "done injected on cancel (full TS)" is_full_ts "$(fm "$CFILE" done)"
check "event ticket.cancelled x1" bash -c "[ '$(event_count ticket.cancelled)' = '1' ]"

echo

# ============================================================================
# STATE-MACHINE GUARDS
# ============================================================================
echo "--- state-machine guards ---"

# Publish the queue-guard ticket up front so its (legitimate) publish event does
# not fall inside the "illegal transitions emit nothing" window captured below.
DRAFT3="$TEAM_DIR/draft3.md"
cat > "$DRAFT3" <<'MD'
---
title: Queue guard
---
body
MD
ID3="$("$PUBLISH" work "$DRAFT3" 2>/dev/null)"

# Snapshot the event count: every illegal transition below must add zero events.
EV_BEFORE="$(total_events)"

# illegal: in_progress on a done ticket -> non-zero, file not moved/corrupted
if "$TRANSITION" "$ID" --to in_progress >/dev/null 2>&1; then
  fail "illegal in_progress-on-done should exit non-zero"
else
  pass "illegal in_progress-on-done exits non-zero"
fi
check "done ticket still in done/" bash -c "[ -n \"\$(ls "$TEAM_DIR"/tickets/done/"$ID"-*.md 2>/dev/null)\" ]"
check "done ticket status still done" bash -c "[ '$(fm "$DONEFILE" status)' = 'done' ]"
check "no in-progress re-creation for done id" bash -c "[ -z \"\$(ls "$TEAM_DIR"/tickets/in-progress/"$ID"-*.md 2>/dev/null)\" ]"

# illegal: done directly from queue -> non-zero, file stays in queue
if "$TRANSITION" "$ID3" --to done >/dev/null 2>&1; then
  fail "illegal queue->done should exit non-zero"
else
  pass "illegal queue->done exits non-zero"
fi
check "guarded ticket still in queue/" bash -c "[ -n \"\$(ls "$TEAM_DIR"/tickets/queue/"$ID3"-*.md 2>/dev/null)\" ]"
check "guarded ticket not in done/" bash -c "[ -z \"\$(ls "$TEAM_DIR"/tickets/done/"$ID3"-*.md 2>/dev/null)\" ]"
check "illegal transitions emitted no events" bash -c "[ '$(total_events)' = '$EV_BEFORE' ]"

echo

# ============================================================================
# EVENT ORDERING
# ============================================================================
echo "--- event ordering ---"

# seq strictly monotonic 1..N
check "events.jsonl seq is monotonic 1..N" python3 - "$EVENTS" <<'PY'
import json, sys
seqs = [json.loads(l)["seq"] for l in open(sys.argv[1]) if l.strip()]
sys.exit(0 if seqs == list(range(1, len(seqs) + 1)) else 1)
PY

# event sequence matches the actions performed (in order)
EXPECTED="ticket.published
ticket.claimed
ticket.review
rescue.triggered
ticket.review
ticket.done
ticket.published
ticket.claimed
ticket.cancelled
ticket.published"
ACTUAL="$(python3 - "$EVENTS" <<'PY'
import json, sys
for l in open(sys.argv[1]):
    if l.strip():
        print(json.loads(l)["event"])
PY
)"
if [ "$ACTUAL" = "$EXPECTED" ]; then
  pass "event sequence matches actions"
else
  fail "event sequence matches actions"
  echo "  expected:"; printf '%s\n' "$EXPECTED" | sed 's/^/    /'
  echo "  actual:";   printf '%s\n' "$ACTUAL"   | sed 's/^/    /'
fi

echo
echo "=== summary: $PASSES passed, $FAILS failed ==="
if [ "$FAILS" -ne 0 ]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
