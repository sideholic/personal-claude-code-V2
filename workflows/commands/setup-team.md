---
description: Bootstrap the v2 workspace — .claude-team/, the live dashboard, and a 3-pane Technoking tmux window.
---

Run the workflows plugin's bootstrap script: `${CLAUDE_PLUGIN_ROOT}/bin/setup-team.sh`. It:

1. **`.claude-team/` 준비** — 디렉터리 + registry + config + events.jsonl (idempotent: 기존 프로젝트의 registry/config 는 **덮지 않음**, counters 보존).
2. **대시보드** — 백그라운드 기동 후 URL 출력 (`DASHBOARD_DIR` 미지정 시 형제 `personal-claude-code-dashboard` 사용; `EVENTS_LOG` = 이 프로젝트의 `events.jsonl`).
3. **tmux `claude-team` 윈도우** — Technoking pane 0/1/2 (세로 33%씩). pane 0 = 메인(welcome 배너), pane 1·2 = 추가 킹. 개수는 `CLAUDE_TEAM_KINGS`(기본 3).

스크립트 실행 후 `/codex:status`(필수 리뷰어)를 확인하고, 사용자에게 **대시보드 URL · tmux attach 안내(새 세션일 때) · codex 준비 상태**를 보고한다. tmux 미설치 시 pane 부트스트랩만 생략하고 나머지는 진행.
