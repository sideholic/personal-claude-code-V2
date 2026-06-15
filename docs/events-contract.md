# events.jsonl — 플러그인 ↔ 대시보드 계약 (v1)

> 플러그인(producer)과 로컬 대시보드(별도 repo, consumer) 사이의 **유일한 인터페이스**.
> 이 계약만 지키면 양쪽은 독립 개발·배포된다. 변경은 하위호환(append-only field, 새 event type는 무시 가능) 원칙.

---

## 1. 전송 모델

- **파일**: `.claude-team/events.jsonl` — append-only JSON Lines (한 줄 = 한 이벤트, UTF-8).
- **데몬·HTTP POST 없음.** 플러그인은 *티켓 상태 쓰기*와 *스킬 stage 경계*마다 같은 셸/툴 시퀀스 안에서 **한 줄 append** 만 한다. 의존성 0.
- **대시보드(별도 repo)** 가 이 파일을 **tail** 하고 자기 WebSocket 클라이언트로 push 한다. 이 tail-watch는 **읽기 레이어에만** 존재 — 절대 오케스트레이터를 깨우는 채널로 쓰지 않는다(v1 wake-channel 안티패턴 금지).
- **순서**: 파일 라인 순서가 authoritative. `ts`는 표시용, 동률 시 `seq`로 타이브레이크.
- **재생(replay)**: 대시보드는 파일 처음부터 읽어 현재 상태를 재구성한다. 파일은 절대 rewrite 하지 않는다(회전/아카이브는 P8에서).

---

## 2. 공통 봉투(envelope)

모든 라인이 공유하는 필드:

| 필드 | 타입 | 필수 | 설명 |
|---|---|---|---|
| `v` | int | ✓ | 스키마 버전. 현재 `1`. |
| `seq` | int | ✓ | 프로세스/세션 단조 증가. 동일 `ts` 타이브레이크. |
| `ts` | string | ✓ | KST ISO-8601, 예 `2026-06-15T23:50:00+09:00`. |
| `event` | string | ✓ | 이벤트 타입(네임스페이스). 아래 카탈로그. |
| `feature` | string\|null | ✓ | 부모 피처 id(엄브렐러 T-ID 또는 slug). 피처 단위 그룹핑. |
| `ticket` | string\|null | ✓ | `T-NNNN`/`RV-NNNN` 등. 피처/페이즈 레벨 이벤트는 `null`. |
| `actor` | string | ✓ | `king` 또는 `skill:<id>` (`skill:prd`·`skill:design`·`skill:qa`·`skill:backend`·`skill:frontend`·`skill:review`·`skill:rescue`). |
| `data` | object | ✓ | 이벤트별 페이로드(아래). 없으면 `{}`. |

알 수 없는 `event`/`data` 키는 소비자가 **무시**(forward-compat).

---

## 3. 이벤트 카탈로그

### Tier 0 — 피처/페이즈 (오케스트레이션, `ticket=null`)
| `event` | `data` | 보드 효과 |
|---|---|---|
| `feature.started` | `{request, complexity}` | 새 피처 그룹 생성 |
| `phase.entered` | `{phase}` — `classify\|spec\|decompose\|build\|converge\|merge` | 피처 진행 표시 |
| `stop.requested` | `{phase, kind, summary}` — kind=`prd\|design\|merged-spec\|batch` | "승인 대기" 배지 |
| `stop.resolved` | `{kind, decision}` | 배지 해제 |
| `escalation.raised` | `{reason, detail}` — reason=`requirements_change\|architectural_change\|untestable_ac\|codex_unavailable\|rescue_failed\|review_3x_blocking\|other` | 경고 표시 |

### Tier 1 — 티켓 라이프사이클 (보드 컬럼)
| `event` | `data` | → 컬럼 |
|---|---|---|
| `ticket.published` | `{title, complexity, assignee, files_in_scope, depends_on}` | queue |
| `ticket.claimed` | `{worktree, branch}` | in-progress |
| `ticket.review` | `{pr, round}` | in-review |
| `ticket.done` | `{merge_commit}` | done |
| `ticket.cancelled` | `{reason}` | cancelled |

### Tier 2 — per-skill stage (카드 타임라인, 레인 내부)
| `event` | `data` |
|---|---|
| `stage.started` | `{skill, stage}` — stage 예: `qa-pre`·`impl`·`review`·`prd`·`design`·`qa-post`·`rescue` |
| `stage.completed` | `{skill, stage, summary?}` |
| `stage.failed` | `{skill, stage, error_signature?}` |

### Tier 2b — review/rescue 상세 (선택, 더 풍부)
| `event` | `data` |
|---|---|
| `review.round` | `{round, verdict, codex_job_id, findings}` — verdict=`APPROVE\|COMMENT\|BLOCKING`, findings=`{blocking,should,nit,oos}` 카운트 |
| `rescue.triggered` | `{trigger, error_signature}` — trigger=`error_2x\|pattern_stuck` |
| `rescue.resolved` | `{validation_ticket}` |
| `rescue.failed` | `{reason}` |

---

## 4. squad 매핑 (대시보드 그룹핑)

| squad | 스킬(stage) |
|---|---|
| design | `prd`, `design` |
| BE | `backend` |
| FE | `frontend` |
| QA | `qa-pre`, `qa-post` |
| review | `review` |

`rescue`는 원 소스 티켓의 squad에 귀속(별도 `rescue` 태그 부여).

---

## 5. 소비 규칙 (대시보드)

- **보드 컬럼** = 각 티켓의 *최신* `ticket.*` 이벤트.
- **카드 타임라인** = 그 티켓의 `stage.*` + `review.round` + `rescue.*` 를 `seq` 순으로.
- **승인 대기** = 마지막 `stop.requested` 이후 `stop.resolved` 미수신.
- **피처 진척** = `phase.entered` 시퀀스.
- 멱등: 같은 라인을 두 번 읽어도 상태 동일해야 함(최신값 채택).

---

## 6. 예시 (한 피처의 일부)

```jsonl
{"v":1,"seq":1,"ts":"2026-06-15T23:50:00+09:00","event":"feature.started","feature":"T-0006","ticket":null,"actor":"king","data":{"request":"주문 취소 기능","complexity":"large"}}
{"v":1,"seq":2,"ts":"2026-06-15T23:50:01+09:00","event":"phase.entered","feature":"T-0006","ticket":null,"actor":"king","data":{"phase":"build"}}
{"v":1,"seq":3,"ts":"2026-06-15T23:50:02+09:00","event":"ticket.published","feature":"T-0006","ticket":"T-0007","actor":"king","data":{"title":"취소 API","complexity":"medium","assignee":"skill:backend","files_in_scope":["api/order/cancel.kt"],"depends_on":[]}}
{"v":1,"seq":4,"ts":"2026-06-15T23:50:03+09:00","event":"ticket.claimed","feature":"T-0006","ticket":"T-0007","actor":"king","data":{"worktree":".worktrees/T-0007","branch":"feat/T-0007-cancel-api"}}
{"v":1,"seq":5,"ts":"2026-06-15T23:50:04+09:00","event":"stage.started","feature":"T-0006","ticket":"T-0007","actor":"skill:qa","data":{"skill":"qa","stage":"qa-pre"}}
{"v":1,"seq":6,"ts":"2026-06-15T23:51:00+09:00","event":"stage.completed","feature":"T-0006","ticket":"T-0007","actor":"skill:qa","data":{"skill":"qa","stage":"qa-pre","summary":"3 fail-first AC tests committed RED"}}
{"v":1,"seq":7,"ts":"2026-06-15T23:51:01+09:00","event":"stage.started","feature":"T-0006","ticket":"T-0007","actor":"skill:backend","data":{"skill":"backend","stage":"impl"}}
{"v":1,"seq":8,"ts":"2026-06-15T23:55:00+09:00","event":"ticket.review","feature":"T-0006","ticket":"T-0007","actor":"skill:review","data":{"pr":42,"round":1}}
{"v":1,"seq":9,"ts":"2026-06-15T23:57:00+09:00","event":"review.round","feature":"T-0006","ticket":"T-0007","actor":"skill:review","data":{"round":1,"verdict":"APPROVE","codex_job_id":"cx_abc","findings":{"blocking":0,"should":1,"nit":2,"oos":0}}}
{"v":1,"seq":10,"ts":"2026-06-15T23:58:00+09:00","event":"ticket.done","feature":"T-0006","ticket":"T-0007","actor":"king","data":{"merge_commit":"a1b2c3d"}}
```

---

## 7. 불변식

1. append-only. 라인 수정·삭제 금지.
2. 모든 라인은 §2 봉투 6필드 + `data` 보유.
3. `ticket.*`는 컬럼 상태머신을 위반하지 않는다(queue→in-progress→in-review→done; cancelled는 어디서든).
4. emit은 실제 상태 쓰기와 **같은 시퀀스**에서(누락 시 보드가 진실과 어긋남).
5. 플러그인은 대시보드 가동 여부와 무관하게 동작(파일은 그냥 쌓임).
