# personal-claude-code v2

Claude Code를 "회사처럼" 운영하는 플러그인. 메인의 Technoking 1명이 작업을 스킬로 분배하고, 겹치지 않는 작업은 백그라운드에서 동시 실행한다. 모든 PR은 codex 리뷰를 거쳐 머지된다.

## 설치

```bash
/plugin marketplace add sideholic/personal-claude-code-v2
/plugin install workflows@personal-claude-code-v2            # 필수 (코어)
/plugin install stack-kotlin-spring@personal-claude-code-v2  # 옵션
/plugin install stack-nextjs@personal-claude-code-v2         # 옵션
```

## 첫 실행

```
/codex:setup     # codex CLI 인증 (필수 리뷰어)
/setup-team      # .claude-team/ 디렉터리 + registry 생성
/feat <요청>     # 기능 개발 시작
```

## 커맨드

| 커맨드 | 설명 |
|---|---|
| `/feat <요청>` | 전체 기능 라이프사이클 (분류 → 설계 → 구현 → 리뷰 → 머지) |
| `/task <변경>` | 소규모 단일 변경 (1–2 파일) |
| `/design <기능>` | PRD·설계 문서만 (구현 전 중단) |
| `/diagnose <버그>` | 버그 조사·원인·수정안 (구현 안 함) |
| `/review <PR\|브랜치>` | codex 리뷰 재실행 |
| `/status` | 티켓 보드 (텍스트) |
| `/handoff` | 다음 세션용 컨텍스트 직렬화 |
| `/cleanup` | 오래된 티켓 아카이브·워크트리 정리 |
| `/abort [T-NNNN\|--all]` | 진행 중 작업 취소 |
| `/setup-team` | 팀 디렉터리 부트스트랩 |
| `/hire <역할>` | 커스텀 스킬 추가 |
| `/show-team` | 팀 로스터 |

## 복잡도 라우팅

- **small** — 1–2 파일 → `/task` 단축 경로 (승인 0회)
- **medium** — 3–5 파일 (승인 1회)
- **large** — 6+ 파일 / 신규 도메인 / auth·DB 마이그레이션·외부 연동 (승인 3회)

## 티켓 · 대시보드

작업은 `.claude-team/tickets/`의 마크다운 티켓으로 관리되고, 상태 전이는 `.claude-team/events.jsonl`에 기록된다. 실시간 보드는 [personal-claude-code-dashboard](https://github.com/sideholic/personal-claude-code-dashboard)가 이 파일을 읽어 시각화한다.

## 요구사항

- **codex CLI** — 리뷰어 (필수)
- **python3** — 티켓 카운터·이벤트 emit
- **git**
- **tmux** — 멀티 Technoking(옵트인)에만 필요
