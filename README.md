# personal-claude-code v2

> Claude Code를 **작은 개발 회사처럼** 운영하는 플러그인.
> 멈추지 않는 Tech Lead 1명이 설계·구현·QA·리뷰를 백그라운드 서브에이전트에 **병렬 분배**, **독립 리뷰어** 통과 코드만 머지.

![version](https://img.shields.io/badge/version-2.2.0-blue) ![license](https://img.shields.io/badge/license-MIT-green) ![claude-code](https://img.shields.io/badge/Claude%20Code-plugin-8A2BE2)

| | |
|---|---|
| **문제** | 한 번에 한 작업 → 대기 시간 낭비 · 코드 작성 모델의 셀프 리뷰 · 진행 상태가 대화 속에 묻힘 |
| **해결** | 비차단 오케스트레이터 · 파일 범위 기반 병렬 git worktree · 독립 Opus/max 리뷰어 게이트 · 파일 기반 티켓 + 이벤트 피드 |
| **규모** | 커맨드 12 · 스킬 24 · atomic 티켓/머지 스크립트(bash+python) · 안전 훅 2종 · 실시간 칸반 [대시보드](https://github.com/sideholic/personal-claude-code-dashboard)(별도 repo) |

## 핵심 아이디어

- **오케스트레이터 비차단.** 실작업은 전부 백그라운드. 메인 루프는 분류·분해·디스패치·중계·대화만.
- **페르소나 = 스킬.** pane 바인딩 에이전트 대신 stateless 스킬. 파일 범위 비충돌이면 개수 제한 없이 동시 실행.
- **티켓 = 상태.** `.claude-team/` 마크다운 파일, 디렉터리 = 칸반 컬럼. 세션 종료 후에도 유지, 대시보드가 직접 읽음.
- **리뷰어 독립.** 구현자와 분리된 fresh 컨텍스트의 Opus 서브에이전트, `effort: max`. 자기 diff 셀프 리뷰 금지.

## 동작 흐름

```
/feat 요청 → 복잡도 판정 (small / medium / large)
  ├─▶ [BG] spec       PRD → Design            (large: 승인 2회)
  ├─  분해·플래닝     files_in_scope 교집합 → 비충돌 유닛 병렬, 충돌 시 순차
  ├─▶ [BG, 병렬] build 워크트리마다: fail-first 테스트 → 구현 → 독립 리뷰 → (막히면 rescue 1회)
  ├─▶ [BG] converge   통합 / E2E
  └─  merge           Tech Lead 단독 squash → 한국어 리포트
```

| 판정 | 기준 | 승인 | 리뷰 |
|---|---|---|---|
| small | 1–2 파일 | 0회 (`/task`) | general |
| medium | 3–5 파일 | 1회 | general |
| large | 6+ 파일 · 신규 도메인 · auth/DB 마이그레이션 | 3회 | adversarial |

매 PR 독립 리뷰 · 전 AC 통과 · green CI = 복잡도 무관 불변 게이트. 머지 직전 Stop 없음.

## 시작하기

```bash
/plugin marketplace add sideholic/personal-claude-code-v2
/plugin install workflows@personal-claude-code-v2            # 필수
/plugin install stack-kotlin-spring@personal-claude-code-v2  # 옵션: Kotlin/Spring · nextjs · nest
```

```
/setup-team      # .claude-team/ 골격 + tmux 세션 + 대시보드 안내
/feat <요청>     # 기능 개발
/task <변경>     # 1–2 파일 소규모 변경
```

요구사항: `git` · `gh` · `python3`. tmux는 멀티 세션 시에만.

| 커맨드 | 설명 |
|---|---|
| `/feat` `/task` | 전체 라이프사이클 / 소규모 단축 경로 |
| `/design` `/diagnose` | 설계 문서만 / 버그 원인 분석만 (구현 없음) |
| `/review <PR>` | 독립 리뷰어 재실행 |
| `/status` `/handoff` | 티켓 보드 / 세션 간 컨텍스트 저장·복원 |
| `/abort` `/cleanup` | 작업 취소 / 티켓·워크트리·브랜치 정리 |
| `/setup-team` `/hire` `/show-team` | 워크스페이스 부트스트랩 / 페르소나 추가 / 로스터 |

## 설계 결정

| 결정 | 이유 |
|---|---|
| 비차단 = effort 아닌 **구조**로 보장 | 일 전부 백그라운드 → 킹 항상 대화 가능, 비충돌 작업 자연 병렬 |
| 상태 = 파일 시스템, 메시지 버스 아님 | `ls`만으로 진실 확인. 대시보드는 `events.jsonl` append 한 줄만 읽음 (의존성 0) |
| 카운터 `fcntl.flock` | 프로세스 사망 시 락 자동 해제 → Tech Lead pane 무제한, 티켓 ID 충돌 0 |
| 리뷰어 = 독립 Opus/max 서브에이전트 | 외부 CLI 인증·폴링·타임아웃 데몬 전부 제거. 독립성 = 컨텍스트 격리 + 적대 프레이밍 + 더 높은 effort |
| 리뷰 2모드 (general / adversarial) | adversarial = 벽시계 2~3배. large 또는 명명된 위험 축에서만 |
| 승인 small 0 / medium 1 / large 3 | 되돌리기 비싼 지점(PRD·Design·배치)에만 Stop |

**v1 → v2**: 폴링·데몬 하네스 9개 스크립트(~57KB) 삭제 · 이벤트 전달 3~5홉 → 0홉 · 동시성 pane 2개 캡 → 무제한 · 11 스텝 → 6 페이즈.

## 구조

```
workflows/        코어 플러그인 — agents/technoking · commands 12 · skills 15 · bin (flock 티켓·머지 게이트) · hooks
stacks/           kotlin-spring · nextjs · nest 오버레이 (core · data-access · testing + Stop 훅)
planning.md       설계 단일 출처 (SSOT)
docs/events-contract.md   플러그인 ↔ 대시보드 계약
```

검증: `workflows/bin/_tests/lifecycle-test.sh` — 티켓 상태머신 E2E.

## 라이선스

MIT
