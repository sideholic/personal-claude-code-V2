#!/usr/bin/env bash
# setup-team.sh — v2 워크스페이스 부트스트랩 (프로젝트 1개 = tmux 세션 1개)
#   1) .claude-team/ 준비 (idempotent — 기존 registry/config/events 보존)
#   2) 대시보드 확인 (기동은 launchd 소유 — 여기선 살아있는지 보고 URL 만 안내)
#   3) claude-<project> tmux 세션(독립): Technoking pane N개, pane 0 = welcome
# 세션명·킹 수·대시보드 포트는 .claude-team/config.yml(SSOT)에서 파생 — env 로 덮어쓸 수 있다.
# env: CLAUDE_TEAM_SESSION · CLAUDE_TEAM_KINGS · DASH_PORT · DASHBOARD_DIR · CLAUDE_TEAM_RECREATE=1
# flag: --recreate  기존 동명 세션을 죽이고 새로 만든다 (기본은 재사용 — 남의 킹을 죽이지 않는다)
set -uo pipefail

TEAM_DIR="${CLAUDE_TEAM_DIR:-.claude-team}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$PWD"

RECREATE="${CLAUDE_TEAM_RECREATE:-0}"
for arg in "$@"; do case "$arg" in --recreate) RECREATE=1;; esac; done

# config.yml 값 읽기 (파일이 아직 없을 수 있음 — 그 경우 빈 값 → 아래 기본값)
cfg_get() { # cfg_get <key-regex> → 값 (인라인 주석·공백 제거)
  [ -f "$TEAM_DIR/config.yml" ] || return 0
  awk -v pat="$1" '$0 ~ pat { sub(/^[^:]*:[[:space:]]*/, ""); sub(/[[:space:]]*#.*$/, ""); gsub(/[[:space:]]/, ""); print; exit }' "$TEAM_DIR/config.yml"
}

echo "▶ setup-team — $PROJECT_DIR"

# 1) .claude-team/ (기존 보존 — registry/config/events 는 있으면 안 덮음)
mkdir -p "$TEAM_DIR"/tickets/{queue,in-progress,in-review,done,cancelled} \
         "$TEAM_DIR"/{reviews,rescues,backlog,handoff,archive,workers}
[ -f "$TEAM_DIR/workers/registry.json" ] || cp "$PLUGIN_DIR/templates/registry.json" "$TEAM_DIR/workers/registry.json"
[ -f "$TEAM_DIR/config.yml" ]            || cp "$PLUGIN_DIR/templates/config.yml" "$TEAM_DIR/config.yml"
[ -f "$TEAM_DIR/events.jsonl" ]          || : > "$TEAM_DIR/events.jsonl"
echo "  ✓ .claude-team/ 준비 (기존 registry/config 보존)"

# config.yml 파생값 — 프로젝트 축. 세션명이 프로젝트마다 달라야 다른 프로젝트의 킹을 건드리지 않는다.
PROJECT_NAME="$(cfg_get '^project_name:')"; PROJECT_NAME="${PROJECT_NAME:-$(basename "$PROJECT_DIR")}"
SESSION="${CLAUDE_TEAM_SESSION:-${CLAUDE_TEAM_WINDOW:-claude-$PROJECT_NAME}}"   # 구 CLAUDE_TEAM_WINDOW 호환
KINGS="${CLAUDE_TEAM_KINGS:-$(cfg_get '^[[:space:]]*kings:')}"; KINGS="${KINGS:-2}"
DASH_PORT="${DASH_PORT:-$(cfg_get '^[[:space:]]*port:')}"; DASH_PORT="${DASH_PORT:-4317}"

# claude 기동 플래그 — model/effort 는 config.yml(SSOT)에서, perms 는 bypass (L5 모델 불일치 제거)
KING_FLAGS="$("$SCRIPT_DIR/launch-flags.sh" "$TEAM_DIR")"
echo "  ✓ king flags: $KING_FLAGS"

# events.jsonl 절대경로 (대시보드 EVENTS_LOG)
case "$TEAM_DIR" in /*) EVENTS_ABS="$TEAM_DIR/events.jsonl";; *) EVENTS_ABS="$PROJECT_DIR/$TEAM_DIR/events.jsonl";; esac

# 2) 대시보드 — 확인만 한다. 기동·상주는 launchd(프로젝트별 인스턴스) 소유이므로 여기서 띄우지 않는다:
#    포트를 잘못 잡으면 같은 events 를 읽는 중복 대시보드가 생기고, 죽어도 아무도 안 살린다.
DASH_URL="http://localhost:$DASH_PORT"
if curl -fs -o /dev/null "$DASH_URL/" 2>/dev/null; then
  echo "  ✓ 대시보드: $DASH_URL"
else
  echo "  ⚠ 대시보드 응답 없음: $DASH_URL — launchd 인스턴스 확인 (launchctl list | grep claude-dashboard)"
  echo "    events: $EVENTS_ABS · 포트는 config.yml 의 dashboard.port"
fi

# 3) tmux — 프로젝트 전용 세션에 Technoking pane $KINGS 개 (균등 분할)
if ! command -v tmux >/dev/null; then
  echo "  ⚠ tmux 없음 — pane 부트스트랩 생략 (메인 세션에서 그대로 /feat 사용 가능)"
  echo "✅ setup 완료 — 대시보드 $DASH_URL"; exit 0
fi

WELCOME="/tmp/claude-team-welcome-$SESSION.txt"
cat > "$WELCOME" <<EOF
👑  Technoking — $PROJECT_NAME · pane 0 (메인)
────────────────────────────────────────────────
  /feat <요청>    전체 기능 (분류→설계→구현→리뷰→머지)
  /task <변경>    소규모 단일 변경 (1–2 파일)
  /status         티켓 보드      /review <PR>   리뷰 재실행
  · 모든 작업은 백그라운드 워크플로우/서브에이전트로 — 이 창은 안 막힙니다.
  · pane 1.. = 추가 Technoking(독립 작업 병렬). 티켓 ID atomic 공유, 머지는 merge-gate 직렬화.
  · 티켓·카운터는 이 프로젝트 전용 ($TEAM_DIR) — 다른 프로젝트 세션과 섞이지 않습니다.
  · 대시보드: $DASH_URL
  · 시작 시 이전 핸드오프 자동 복원 (/workflows:handoff --resume)
────────────────────────────────────────────────
EOF

# 프로젝트 전용 독립 세션. 기존 동명 세션은 **재사용**한다 — 무조건 kill 하면 진행 중인 킹이 죽는다.
if tmux has-session -t "$SESSION" 2>/dev/null; then
  if [ "$RECREATE" = 1 ]; then
    echo "  ⚠ 기존 세션 '$SESSION' 제거 후 재생성 (--recreate)"
    tmux kill-session -t "$SESSION" 2>/dev/null || true
  else
    echo "  ✓ 기존 세션 '$SESSION' 재사용 (새로 만들려면 --recreate)"
    if [ -n "${TMUX:-}" ]; then
      tmux switch-client -t "$SESSION" 2>/dev/null && echo "  → 세션 '$SESSION' 로 전환됨" || echo "  → 전환: tmux switch-client -t $SESSION"
    else
      echo "  → 접속: tmux attach -t $SESSION"
    fi
    echo "✅ setup 완료 — 대시보드 $DASH_URL"
    exit 0
  fi
fi
tmux new-session -d -s "$SESSION" -n "$PROJECT_NAME" -c "$PROJECT_DIR"
for _ in $(seq 2 "$KINGS"); do tmux split-window -h -t "$SESSION:" -c "$PROJECT_DIR"; done
tmux select-layout -t "$SESSION:" even-horizontal     # 균등 폭 세로 분할 (킹 2개 = 50/50)
# pane id 로 타깃 — 인덱스/이름·base-index 무관, 다른 세션의 동명 윈도우와 충돌 안 함
PANES=(); while IFS= read -r p; do PANES+=("$p"); done < <(tmux list-panes -t "$SESSION:" -F '#{pane_id}')
# pane 0 = 메인 킹: welcome + 로드 시 이전 핸드오프 자동 복원
tmux send-keys -t "${PANES[0]}" "clear; cat $WELCOME; claude $KING_FLAGS \"/workflows:handoff --resume\"" Enter
for i in $(seq 1 $((KINGS-1))); do
  tmux send-keys -t "${PANES[$i]}" "clear; printf 'Technoking — pane %s (추가 킹)\n\n' $i; claude $KING_FLAGS" Enter
done
tmux select-pane -t "${PANES[0]}"
echo "  ✓ tmux 세션 '$SESSION' (프로젝트 전용) — Technoking pane 0..$((KINGS-1)) (${KINGS}개, 균등 분할)"
if [ -n "${TMUX:-}" ]; then
  tmux switch-client -t "$SESSION" 2>/dev/null && echo "  → 세션 '$SESSION' 로 전환됨" || echo "  → 전환: tmux switch-client -t $SESSION"
else
  echo "  → 접속: tmux attach -t $SESSION"
fi
echo "✅ setup 완료 — 대시보드 $DASH_URL · pane 0 에서 /feat 시작"
