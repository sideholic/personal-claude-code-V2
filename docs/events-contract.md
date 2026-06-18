# events.jsonl — 플러그인 ↔ 대시보드 계약 (v2)

> **변경 이력**
> - **v2**: 보드 권위 소스를 events.jsonl → 티켓 디렉터리/frontmatter로 정정; events.jsonl은 이벤트 피드/타임라인 보조 채널로 재정의.
> - v1: events.jsonl 단일 인터페이스 모델(현재는 폐기).

> 플러그인(producer)과 로컬 대시보드(별도 repo, consumer) 사이의 계약. 이 계약만 지키면 양쪽은 독립 개발·배포된다. 변경은 하위호환(append-only field, 새 event type는 무시 가능) 원칙.

---

## 1. 전송 모델 / 인터페이스 정의

플러그인 ↔ 대시보드는 **두 채널**로 연결된다.

### 채널 A — 보드 상태 (권위 소스)
- **소스**: `.claude-team/tickets/<status>/*.md` — **디렉터리 = 상태(컬럼)**. 각 티켓의 YAML frontmatter가 카드 메타.
- **대시보드**가 이 디렉터리 트리를 **스캔/폴링**(~5s)하여 컬럼·카드를 재구성한다. 보드의 진실은 *티켓 파일이 놓인 디렉터리*이지 events.jsonl이 아니다.
- 컬럼은 디렉터리로, 카드 필드는 frontmatter로 결정(§6 매핑 참조).

### 채널 B — 이벤트 피드/타임라인 (보조)
- **파일**: `.claude-team/events.jsonl` — append-only JSON Lines (한 줄 = 한 이벤트, UTF-8).
- **데몬·HTTP POST 없음.** 플러그인은 *티켓 상태 쓰기*와 *스킬 stage 경계*마다 같은 셸/툴 시퀀스 안에서 **한 줄 append** 만 한다. 의존성 0.
- **용도**: 라이브 활동 로그, 페이즈/스테이지 타임라인, 승인 대기 배지 등. **보드 컬럼의 권위 소스는 아니다.**
- 대시보드는 이 파일을 SSE(`/api/events`)로 스트림할 수 있으나, 보드 클라이언트는 이를 소비하지 않는다(계약 호환 목적 유지).
- **순서**: 파일 라인 순서가 authoritative. `ts`는 표시용, 동률 시 `seq`로 타이브레이크. 파일은 절대 rewrite 하지 않는다(회전/아카이브는 P8에서).

플러그인은 두 채널 모두 **대시보드 가동 여부와 무관하게** 동작한다(디렉터리는 그냥 존재, events.jsonl은 그냥 쌓임).

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

### Tier 1 — 티켓 라이프사이클 (피드/타임라인)
> **주의**: 이 `ticket.*` 이벤트는 이제 디렉터리 전이를 **미러링**한다(`ticket-transition.sh`가 디렉터리 이동과 함께 emit). 보드 컬럼의 권위 소스가 아니라 **라이브 피드·타임라인**을 구동한다. 컬럼은 디렉터리가, 이벤트는 그 이동의 알림이 결정한다. "→ 컬럼"은 해당 이벤트가 대응하는 디렉터리 상태일 뿐.

| `event` | `data` | ↔ 디렉터리 상태 |
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

- **보드 컬럼** = 티켓 파일이 위치한 **디렉터리**(`.claude-team/tickets/<status>/`). events.jsonl이 아니라 디렉터리 스캔/폴링으로 결정.
- **카드 메타** = 그 티켓의 **frontmatter**(§6 매핑). 이벤트 페이로드가 아님.
- **카드 타임라인** = 그 티켓의 `stage.*` + `review.round` + `rescue.*` 를 `seq` 순으로(events.jsonl).
- **승인 대기** = 마지막 `stop.requested` 이후 `stop.resolved` 미수신(events.jsonl).
- **피처 진척** = `phase.entered` 시퀀스(events.jsonl).
- 멱등: 같은 라인을 두 번 읽어도 상태 동일해야 함(최신값 채택).

---

## 6. Frontmatter ↔ 대시보드 매핑 (권위 카드 메타)

보드 카드는 티켓 frontmatter에서 다음 필드를 읽는다. 컬럼 자체는 디렉터리가 결정하고, `status`는 그 디렉터리와 일치해야 한다(이중 기록). 이 표는 `ticket-protocol` 스킬이 인코딩하는 계약과 동일하다.

| 필드 | 소유 | 용도 |
|---|---|---|
| `title` | agent | 카드 제목 |
| `status` | script | 디렉터리와 일치(이중 기록). 컬럼은 디렉터리가 권위 |
| `assignee` | agent | 담당 스킬/레인 |
| `complexity` | agent | small\|medium\|large 배지 |
| `priority` | agent | 정렬/강조 |
| `parent_feature` | agent | 피처 그룹핑 |
| `files_in_scope` | agent | 충돌 판정·표시 |
| `depends_on` | agent | 선행 의존 표시 |
| `created` | script | 생성 시각 |
| `started` | script | 착수(in-progress 진입) 시각 |
| `done` | script | 완료(done 진입) 시각 |
| `updated` | script | 마지막 frontmatter 갱신 시각 |
| `last_activity_at` | script | 라이브 활동 타임스탬프 |
| `progress_note` | agent | 진행 메모 |
| `rescue_count` | script | rescue 횟수 |
| `review_rounds` | script | 리뷰 라운드 수 |

- **script-owned**(스크립트가 전이 시 기록): `created`, `started`, `done`, `updated`, `last_activity_at`, `rescue_count`, `review_rounds`.
- **agent-owned**(스킬/오케스트레이터가 기록): `title`, `assignee`, `complexity`, `priority`, `parent_feature`, `files_in_scope`, `depends_on`, `progress_note`. (`status`는 디렉터리 이동과 함께 스크립트가 동기화.)

---

## 7. 예시 (한 피처의 일부, 피드/타임라인 채널)

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

## 8. 불변식

1. events.jsonl은 append-only. 라인 수정·삭제 금지.
2. 모든 라인은 §2 봉투 6필드 + `data` 보유.
3. **디렉터리 이동이 권위**다(컬럼 상태머신: queue→in-progress→in-review→done; cancelled는 어디서든). `ticket.*` 이벤트는 그 이동을 미러링할 뿐이며, frontmatter `status`·디렉터리·`ticket.*` 셋은 서로 일치해야 한다.
4. emit은 실제 디렉터리 전이와 **같은 시퀀스**에서(누락 시 피드/타임라인이 진실과 어긋남).
5. 플러그인은 대시보드 가동 여부와 무관하게 동작(디렉터리는 존재하고, events 파일은 그냥 쌓임).
