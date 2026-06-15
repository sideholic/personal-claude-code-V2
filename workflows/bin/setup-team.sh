#!/usr/bin/env bash
# setup-team.sh — v2 워크스페이스 부트스트랩
#   1) .claude-team/ 준비 (idempotent — 기존 registry/config/events 보존)
#   2) 대시보드 백그라운드 기동 + URL
#   3) claude-team tmux 세션(독립): Technoking pane 0/1/2 (세로 33%씩), pane 0 = welcome
# env: CLAUDE_TEAM_KINGS(기본 3) · DASH_PORT(4317) · DASHBOARD_DIR · CLAUDE_TEAM_SESSION(claude-team)
set -uo pipefail

TEAM_DIR="${CLAUDE_TEAM_DIR:-.claude-team}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$PWD"
SESSION="${CLAUDE_TEAM_SESSION:-${CLAUDE_TEAM_WINDOW:-claude-team}}"   # 독립 tmux 세션명 (구 CLAUDE_TEAM_WINDOW 호환)
DASH_PORT="${DASH_PORT:-4317}"
KINGS="${CLAUDE_TEAM_KINGS:-3}"

echo "▶ setup-team — $PROJECT_DIR"

# 1) .claude-team/ (기존 보존 — registry/config/events 는 있으면 안 덮음)
mkdir -p "$TEAM_DIR"/tickets/{queue,in-progress,in-review,done,cancelled} \
         "$TEAM_DIR"/{reviews,rescues,backlog,handoff,archive,workers}
[ -f "$TEAM_DIR/workers/registry.json" ] || cp "$PLUGIN_DIR/templates/registry.json" "$TEAM_DIR/workers/registry.json"
[ -f "$TEAM_DIR/config.yml" ]            || cp "$PLUGIN_DIR/templates/config.yml" "$TEAM_DIR/config.yml"
[ -f "$TEAM_DIR/events.jsonl" ]          || : > "$TEAM_DIR/events.jsonl"
echo "  ✓ .claude-team/ 준비 (기존 registry/config 보존)"

# claude 기동 플래그 — model/effort 는 config.yml(SSOT)에서, perms 는 bypass (L5 모델 불일치 제거)
KING_FLAGS="$("$SCRIPT_DIR/launch-flags.sh" "$TEAM_DIR")"
echo "  ✓ king flags: $KING_FLAGS"

# events.jsonl 절대경로 (대시보드 EVENTS_LOG)
case "$TEAM_DIR" in /*) EVENTS_ABS="$TEAM_DIR/events.jsonl";; *) EVENTS_ABS="$PROJECT_DIR/$TEAM_DIR/events.jsonl";; esac

# 2) 대시보드 — 백그라운드 기동 + URL
DASH_DIR="${DASHBOARD_DIR:-$(cd "$PROJECT_DIR/.." 2>/dev/null && pwd)/personal-claude-code-dashboard}"
DASH_URL="http://localhost:$DASH_PORT"
if curl -fs -o /dev/null "$DASH_URL/" 2>/dev/null; then
  echo "  ✓ 대시보드 이미 실행 중: $DASH_URL"
elif [ -d "$DASH_DIR" ] && [ -x "$DASH_DIR/node_modules/.bin/next" ]; then
  ( cd "$DASH_DIR" && EVENTS_LOG="$EVENTS_ABS" \
      nohup node_modules/.bin/next dev -p "$DASH_PORT" >"/tmp/claude-board-$DASH_PORT.log" 2>&1 & )
  echo "  ✓ 대시보드 기동: $DASH_URL  (events: $TEAM_DIR/events.jsonl · log: /tmp/claude-board-$DASH_PORT.log)"
elif [ -d "$DASH_DIR" ]; then
  echo "  ℹ 대시보드 node_modules 없음 — '$DASH_DIR' 에서 'pnpm install' 후 재시도"
else
  echo "  ℹ 대시보드 repo 없음 ($DASH_DIR) — DASHBOARD_DIR 로 경로 지정 가능"
fi

# 3) tmux — Technoking pane 3개 (세로 33%씩)
if ! command -v tmux >/dev/null; then
  echo "  ⚠ tmux 없음 — pane 부트스트랩 생략 (메인 세션에서 그대로 /feat 사용 가능)"
  echo "✅ setup 완료 — 대시보드 $DASH_URL"; exit 0
fi

WELCOME=/tmp/claude-team-welcome.txt
cat > "$WELCOME" <<EOF
👑  Technoking — pane 0 (메인)
────────────────────────────────────────────────
  /feat <요청>    전체 기능 (분류→설계→구현→리뷰→머지)
  /task <변경>    소규모 단일 변경 (1–2 파일)
  /status         티켓 보드      /codex:status   리뷰어 확인
  · 모든 작업은 백그라운드 워크플로우/서브에이전트로 — 이 창은 안 막힙니다.
  · pane 1·2 = 추가 Technoking(독립 작업 병렬). 티켓 ID atomic 공유, 머지는 merge-gate 직렬화.
  · 대시보드: $DASH_URL
  · 시작 시 이전 핸드오프 자동 복원 (/workflows:handoff --resume)
────────────────────────────────────────────────
EOF

# 항상 독립 세션 생성 (현재 tmux 세션에 윈도우 추가가 아니라 별도 세션). 기존 동명 세션은 교체.
tmux kill-session -t "$SESSION" 2>/dev/null || true
tmux new-session -d -s "$SESSION" -n "$SESSION" -c "$PROJECT_DIR"
for _ in $(seq 2 "$KINGS"); do tmux split-window -h -t "$SESSION:" -c "$PROJECT_DIR"; done
tmux select-layout -t "$SESSION:" even-horizontal     # 동일 폭 세로 분할
# pane id 로 타깃 — 인덱스/이름·base-index 무관, 현재 세션의 stale 'claude-team' 윈도우와 충돌 안 함
PANES=(); while IFS= read -r p; do PANES+=("$p"); done < <(tmux list-panes -t "$SESSION:" -F '#{pane_id}')
# pane 0 = 메인 킹: welcome + 로드 시 이전 핸드오프 자동 복원
tmux send-keys -t "${PANES[0]}" "clear; cat $WELCOME; claude $KING_FLAGS \"/workflows:handoff --resume\"" Enter
for i in $(seq 1 $((KINGS-1))); do
  tmux send-keys -t "${PANES[$i]}" "clear; printf 'Technoking — pane %s (추가 킹)\n\n' $i; claude $KING_FLAGS" Enter
done
tmux select-pane -t "${PANES[0]}"
echo "  ✓ tmux 세션 '$SESSION' (독립) — Technoking pane 0..$((KINGS-1)) (${KINGS}개, 세로 33%씩)"
if [ -n "${TMUX:-}" ]; then
  tmux switch-client -t "$SESSION" 2>/dev/null && echo "  → 세션 '$SESSION' 로 전환됨" || echo "  → 전환: tmux switch-client -t $SESSION"
else
  echo "  → 접속: tmux attach -t $SESSION"
fi
echo "✅ setup 완료 — 대시보드 $DASH_URL · pane 0 에서 /feat 시작"
