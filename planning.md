# personal-claude-code v2 — 기획 / 설계 문서 (planning)

> 상태: **설계 합의 완료, 구현 전**. 이 문서는 v2의 의도·결정·아키텍처를 모두 담는 단일 출처(SSOT)다.
> 작성일: 2026-06-15 (KST). v1 분석은 `../personal-claude` 5개 영역 병렬 분석 결과 기반.

---

## 0. 한 줄 요약

v1의 **과잉 하네스(fswatch 데몬·워치독·페인 바인딩 워커·inbox 폴링)** 를 전부 걷어내고,
**메인 루프에서 절대 멈추지 않는 테크노킹 1명**이 겹치지 않는 작업을 **백그라운드 dynamic workflow / 서브에이전트**로 동시 fan-out 하는 구조로 재설계한다.
티켓 데이터 모델·git-flow·codex 리뷰·페르소나 전문성은 유지하되, 전달 메커니즘을 **페인-바인딩 에이전트 → 워크플로우가 호출하는 스킬**로 바꾼다.

**★ 본질은 '빠름'이다.** 역할·작업분배를 **'스킬 호출'로 명확히 지정**하고, 비충돌 작업을 **개수 제한 없는 opus 서브에이전트**로 동시 처리해 구현 시간을 획기적으로 단축한다. 무거운 다단계 fan-out일 때만 dynamic workflow를 쓰고, 그 외엔 인라인 서브에이전트로 가볍게 — 어느 경우든 메인 킹은 안 막힌다. 시각화(로컬 대시보드)로 이 동시 작업을 한눈에 모니터링한다.

---

## 1. 배경 — v1의 한계

v1(`personal-claude`)은 "7명 회사" 모델로 잘 동작했지만 다음 한계가 명확했다.

| # | 한계 | 근거 (v1 실측) |
|---|---|---|
| L1 | **과잉 하네스 엔지니어링** | `workflows/bin/` 9개 스크립트 ~57KB. 그중 ~50KB가 "이벤트 루프 흉내": `ticket-watchdog.sh`(354줄, 6-신호 stuck 분류기), `worker-idle.sh`(240줄, bash 잡러너), fswatch 데몬 2개 + `Monitor(tail -F wake.log)` wake 채널. 전부 *페인에 떨어진 별도 OS 프로세스가 끝났는지*를 터미널 스크래핑으로 추론하려는 코드. |
| L2 | **티켓 1개 = 페인 1개 바인딩** | 고정 5-페인(`worker-be/fe/qa/review`), 코드 생산 페인은 2개뿐 → BE/FE 동시성이 파일 비충돌이어도 **2로 캡**. |
| L3 | **느린 간접 디스패치** | 큐 파일 드롭 → 30s 폴링 → atomic claim → headless `claude` exec → `INBOX-*.json` → fswatch → wake.log → Monitor wake → inbox drain. 한 이벤트에 3~5 홉. |
| L4 | **codex를 감싼 무거운 비동기 래퍼** | codex 자체가 아니라 *비차단 dispatch → `/codex:result` 매 턴 폴링 → RR placeholder → 30분 타임아웃 escalation* 의 하네스가 문제. |
| L5 | **모델 불일치** | `config.yml`(sonnet) vs `agents/*.md`(opus effort:medium) vs `worker-idle.sh`(sonnet default) — 출처 3곳 모순. |
| L6 | **지침 비대** | 코퍼스 ~194KB. `technoking.md` 21KB, CLAUDE.md 7.9KB. 대부분이 *삭제 대상 하네스* 설명. |
| L7 | **티켓 시각화 부재** | 텍스트 `/status` 보드뿐. |

---

## 2. v2 목표 (사용자 의도)

1. **G1 — 하네스 제거**: fswatch 데몬·워치독·페인 워커·inbox 폴링 전부 삭제.
2. **G2 — 티켓 데이터 모델 유지**: `.claude-team/` 마크다운+YAML 티켓 스키마/디렉터리 그대로.
3. **G3 — git-flow 동시 실행**: 겹치지 않는 작업은 무조건 동시 실행해 구현 시간 단축.
4. **G4 — 메인 테크노킹 1명 총괄**: 페르소나를 페인-에이전트로 나누지 않고, 테크노킹이 dynamic workflow로 design/FE/BE/QA를 병렬 호출.
5. **G5 — 페르소나 = 스킬 (속도의 핵심)**: 역할·작업분배를 행위에 맞는 **스킬 호출**로 명확히 지정 → 빠른 처리. dynamic workflow는 무거우니 ≥2 비충돌 유닛일 때만.
6. **G6 — 멀티 테크노킹(옵트인)**: tmux pane을 **허용하는 한 무제한**으로 띄워, 티켓을 atomic increment로 겹치지 않게 관리.
7. **G7 — 전 워크플로우/서브에이전트 모델 = 최신 opus, 서브에이전트 개수 제한 없음** (비충돌이면 몇 개든 동시).
8. **G8 — 티켓 전체 시각화**: multica 스타일 로컬 웹 보드를 **별도 git 프로젝트**로 직접 구현·연동.
9. **G9 — 지침 최소화**: 글자수 하드 제한은 두지 않되, karpathy 레퍼런스처럼 **최대한 간략·핵심만**.

### ★ G0 — 비차단 원칙 (최상위, 모든 결정에 우선)

> **메인 테크노킹은 절대·절대·절대 blocking 되어선 안 된다. 항상 사용자와 논의할 준비가 되어 있어야 한다.**
> 모든 실제 작업(설계/구현/QA/리뷰/머지)은 **백그라운드 워크플로우 · 서브에이전트 · 백그라운드 Bash**로 진행한다.
> 메인 루프는 *분류 → 분해 → 디스패치(fire-and-forget) → 결과/에스컬레이션 중계 → 대화* 만 한다. 동기적으로 기다려 사용자를 막는 호출을 하지 않는다.

이 원칙이 G4(단일 킹)와 G3(동시성)을 하나로 묶는다: 킹이 안 막히려면 일을 전부 백그라운드로 던져야 하고, 그러면 자연히 비충돌 작업이 동시에 돈다.

---

## 3. 합의된 결정 (이번 논의 확정)

| 항목 | 결정 | 비고 |
|---|---|---|
| **대시보드** | 로컬 웹 보드 자체 구현, **별도 git repo로 분리 관리**. 플러그인은 `tickets/*` + `events.jsonl` 피드만 내보냄 | multica는 Postgres 전용이라 직접 연동 불가 → 스타일만 차용 |
| **동시성 주력** | 단일 **비차단** 메인 킹 + 백그라운드 dynamic workflow / 병렬 서브에이전트 | G0+G4 |
| **멀티 테크노킹** | 아키텍처는 **pane 무제한** 지원(하드캡 없음)으로 atomic 카운터 설계. 다중 기동 런처는 **옵트인 후속** | G6 |
| **코드 리뷰어** | **codex 고정**. "Claude가 짠 코드를 Claude가 리뷰"는 부적절 → 외부 어드버서리얼 리뷰 유지 | 단, 데몬/폴링 하네스 제거, 백그라운드 레인 내 **동기 await** |
| **지침 분량** | 글자수 제한 **없음**. karpathy 스타일 — 간략·핵심·간결 | G9 |
| **모델** | 전 워크플로우/스킬 = **최신 opus** 단일 출처 | G7 |
| **언어** | 사용자 산출물(PRD/Design/ADR/커밋·PR 본문/리뷰 요약) = 한국어, 내부(스킬·티켓·코드·커맨드·frontmatter) = 영어. KST ISO-8601 | v1 유지 |

### default로 채택한 세부 결정 (재확인 불요, 필요 시 조정)

- **QA 2단계 직렬화 → 유닛별 파이프라인**: 비충돌 유닛마다 `fail-first AC 테스트 → 구현 → 리뷰`를 독립 병렬 레인으로. 유닛 간 통합/E2E만 마지막 수렴 배리어. (What-If Witch의 2-phase 계약 유지하면서 벽시계 단축)
- **카운터 원자성 → `flock(1)`**: v1 `mkdir` 락은 SIGKILL 시 stale 디렉터리 잔존. `flock`은 프로세스 사망 시 자동 해제 → pane 무제한 안전. SQLite/git-backed는 멀티-호스트 필요 시점까지 보류.
- **design 레인 → 2 스킬 1 파이프라인**: `prd`(Spec Shaman) + `design`(Galaxy Brain)을 별도 스킬로 두되 하나의 design 파이프라인으로 노출. large의 PRD-승인/Design-승인 이중 Stop 경계 보존.
- **워크트리 기준 통일**: `feat/T-NNNN-<slug>` (main 기준, develop 없음). v1의 `develop` 기준 잔재 제거.
- **`in-review`를 실제 디렉터리로 승격**: 보드 컬럼이 디렉터리에 1:1 매핑되도록.
- **추론 effort**: Technoking=**high**(비차단 응답성 우선, 라우팅·분해·중계엔 충분) / 백그라운드 서브에이전트(design·BE·FE·review·qa)=**xhigh**(품질=산출물, 지연 숨겨짐). 고위험 분해 순간만 xhigh 백그라운드 플래너로 위임 가능. `config.yml.effort`.

---

## 4. v2 아키텍처

### 4.1 컨트롤 플로우 (v1 대비)

**v1 (삭제):** `user → Technoking → queue 파일 → 30s 폴링 → headless 페인 → INBOX → fswatch → wake.log → Monitor → drain`

**v2:**
```
user ⇄ Technoking(메인 루프, opus, 절대 비차단)
        │  /feat 수신 → 복잡도 판정(small/medium/large, auto-large 트리거)
        │
        ├─▶ [BG] design 파이프라인 워크플로우  (prd-skill → design-skill, B-패턴 Stop)
        │        └ 완료 알림 → 킹이 사용자에게 승인 요청(필요 시)
        │
        ├─  ticket-publish(flock + registry.json 카운터) → T-NNNN → tickets/queue/
        │
        ├─  동시성 플래너: 분해된 티켓들의 files_in_scope[] 교집합 계산 → 최대 비충돌 집합
        │
        ├─▶ [BG] fan-out: 비충돌 유닛마다 1개 워크트리(.worktrees/T-NNNN, feat/T-NNNN-<slug>)에서
        │        per-unit 파이프라인 { QA-pre(fail-first 테스트) → 구현(BE/FE skill) → codex 리뷰(동기 await) }
        │        (겹치는 유닛은 depends_on[] 으로 순차)
        │        └ 각 스킬은 구조화된 결과(아티팩트/verdict/error)를 RETURN — inbox·sentinel·폴링 없음
        │
        ├─  실패 2회: 레인의 테스트 러너가 직접 감지 → 1-shot rescue 스킬(티켓·시그니처당 ≤1, 초과 시 사용자 에스컬레이션)
        │
        └─▶ [BG] 수렴: 유닛 간 통합/E2E(QA-skill) 배리어 → 킹 단독 --squash 머지(pre-merge 체크리스트)
                 → 티켓 tickets/done/, 워크트리 제거 → events.jsonl emit

  ★ 위 [BG] 단계는 전부 run_in_background. 킹은 디스패치 직후 즉시 사용자에게 복귀.
    완료/에스컬레이션은 task-notification 으로 킹에 도달 → 킹이 중계.
```

### 4.2 비차단 구현 메커니즘 (G0 실현 수단)

- **백그라운드 워크플로우**: `Workflow`는 호출 즉시 task ID 반환, 완료 시 notification. 무거운 다단계 fan-out의 주력.
- **백그라운드 서브에이전트 / Bash**: `run_in_background`로 단일 유닛·빠른 작업 오프로드.
- **킹이 동기 await 하는 것은 없음**: codex 리뷰의 동기 await는 *백그라운드 레인(워크플로우) 내부*에서 일어나고, 킹 자신은 그 워크플로우를 백그라운드로 띄워 막히지 않는다.
- **결과 수신**: 모든 완료/실패는 notification으로 킹에 전달 → 킹은 그때 사용자에게 보고하거나 다음 단계를 디스패치.

### 4.3 공유 가변 상태 (멀티 테크노킹 안전)

유일한 공유 가변 상태 = `registry.json { counters: { T, RV, BL } }` + `flock` 락.
- pane이 몇 개든(무제한) 각 킹은 atomic increment로 **유일한 T-NNNN**을 받음 → ID 충돌 0.
- 킹들이 경합하는 지점은 카운터와 머지 게이트뿐. (v1의 `panes{pid,pane_id}` 블록은 삭제 — 페인-워커 없음)
- 티켓 = **스케줄링 원장 + 대시보드 레코드**. 절대 메시지 버스 아님. `inbox/` 타입 전체 삭제.

---

## 5. 티켓 데이터 모델 (G2 — 유지 + 정리)

`.claude-team/` 디렉터리 상태머신 유지. **`in-review`를 실제 디렉터리로 승격**.

```
tickets/queue/        ← 발행
tickets/in-progress/  ← 작업 중
tickets/in-review/    ← 리뷰 중 (신규 디렉터리)
tickets/done/         ← 완료 (영구 보존)
tickets/cancelled/    ← 취소
reviews/   rescues/   backlog/   handoff/   archive/{YYYY-MM}/
workers/registry.json ← counters{T,RV,BL} 만 (panes{} 삭제)
events.jsonl          ← 대시보드용 append-only 이벤트 (신규)
```

### work 티켓 frontmatter

**유지(core):** `id, type, title, status(queued|in_progress|in_review|done|cancelled), assignee(=스킬 정체성), complexity, parent_feature, acceptance_criteria[], files_in_scope[], depends_on[], created, updated, author`

- `files_in_scope[]` + `depends_on[]` 를 **1급 동시성 프리미티브**로 승격 (플래너 입력).

**삭제(하네스 전용):** `attempt_count, last_error_signature, last_update_at, protected_files, owner, claimed_at` — 전부 워치독/데몬 staleness 신호용이었음.

### ID / 카운터

- 4자리 zero-pad `T-0042` / `RV-0007` / `BL-0019`, 9999 초과 자동 확장.
- `RR-T-NNNN-N`(리뷰 리포트, 라운드별, 카운터 없음), `RESCUE-/HANDOFF-`(타임스탬프, 카운터 없음).
- 카운터: `registry.json.counters` + `flock` (4절 참고). `ticket-publish.sh` 만 유지/적응.

### 아티팩트 타입

`work(T)`, `review(RV)`, `review-report(RR)`, `rescue(RESCUE)`, `backlog(BL)`, `handoff(HANDOFF)` 유지.
**`inbox(INBOX)` 타입 + ~11 kind enum 전체 삭제** (서브에이전트 return으로 대체).

---

## 6. 페르소나 → 스킬 매핑 (G5)

| v1 페르소나 | v2 형태 | 레인 | 산출물 |
|---|---|---|---|
| Technoking | **에이전트 유지** (메인 루프, 멀티턴 세션 소유, 비차단) | 오케스트레이션 | 복잡도 판정·티켓·머지·중계 |
| Spec Shaman | **스킬** `prd` | design | PRD (한국어) |
| Galaxy Brain | **스킬** `design` | design | Design Doc·ADR·인터페이스 계약 |
| Persistence Paladin | **스킬** `backend` | BE | 서버 코드+테스트·PR |
| Pixel Wizard | **스킬** `frontend` | FE | UI 코드+테스트·PR |
| What-If Witch | **스킬** `qa` (2-phase) | QA | fail-first AC 테스트 + 통합/E2E |
| The Roastmaster | **스킬** `review` | review | codex dispatch + verdict 판정 → RR |

- 테크노킹만 에이전트. 나머지 6은 워크플로우가 호출하는 스킬.
- 스킬은 stateless-per-ticket, 단일 책임, discrete 아티팩트 반환 → 워크플로우 fan-out에 최적.
- 사용자 명명 분배 = **design / FE / BE / QA** (+ review). prd+design은 design 파이프라인으로 묶음.

---

## 7. 라이프사이클 (재표현 — 11→6 압축)

> v1의 11-step를 **6 페이즈**로 압축. 원칙: **게이트는 한 글자도 안 줄이고, 페이즈 경계만 알리던 의식(승인을 별도 번호 스텝으로 세던 것)을 그 게이트가 지키는 페이즈 안으로 접는다.** 킹은 *분류 → 분해 → 디스패치(fire-and-forget) → 중계 → 대화* 만 한다. 실제 작업은 전부 [BG].

킹이 실제로 쏘는 디스패치 면(面)은 **3종**뿐: design 파이프라인(2) · per-unit 레인(4, in-lane rescue 포함) · 수렴(5).

```
1  classify              (킹, 메인 루프 — 디스패치 없음, Stop 없음)
2  spec 파이프라인        [BG] prd→design 1 워크플로우
                          ── Stop: large=PRD승인 then Design승인(이중, SSOT) / medium=PRD+Design 통합 1회 / small=skip
3  분해 + 동시성 플래닝   (킹 — files_in_scope[] 교집합 → 최대 비충돌 집합, depends_on[] 순차, T-NNNN flock)
                          ── Stop: large=batch 승인 / 그 외 없음
4  build fan-out         [BG, 병렬] 유닛마다 1 워크트리: qa-pre(fail-first, red 선커밋) → 구현(BE/FE) → codex 리뷰(레인 내 동기 await)
                          + in-lane rescue(error_2x/pattern_stuck, ≤1/티켓·시그니처) · Stop 없음
5  converge              [BG] 유닛 간 통합/E2E 배리어 (large 기본 / medium=AC 요구 시 / small·task skip; auto-large는 강제 ON)
                          · 모든 레인 APPROVE 후 발동 · green CI + 전 AC 체크 = 머지 선행조건 · Stop 없음
6  merge + report        (킹 단독 --squash, pre-merge 체크리스트 → done/, 워크트리 제거, events.jsonl, 한국어 리포트)
```

**왜 6인가 (11→6 매핑):** 2+3+4+5(PRD·승인·Design·승인) → 페이즈 2 한 파이프라인(승인은 *별도 행*이 아니라 페이즈 내부 체크포인트). 7+8+9(fail-first·구현·리뷰) → 페이즈 4 per-unit 레인 하나로(원래 글로벌 배리어 3개였던 게 벽시계 낭비의 핵심 — 유닛 A가 codex 리뷰 중일 때 유닛 B는 red 테스트 작성 중일 수 있다). rescue → 페이즈 4 안의 조건 분기(데몬·inbox 없음, 레인이 실패를 직접 봄). 1·6·10·11은 그대로(분류 두뇌·동시성 두뇌·수렴 배리어·머지 게이트는 load-bearing).

**복잡도별 변형:**
- **small** → `/task`: 1 → (4 단일 인라인 레인) → 6. **0 Stop.** 2·3·5 skip. 단, fail-first·codex 리뷰·rescue·머지 게이트는 레인 안에서 전부 발동(리뷰 스킵 아님).
- **medium** → 1 → 2(**1 Stop**: PRD+Design 통합) → 3(batch Stop 없음) → 4(≥2 비충돌 유닛이면 Workflow, 아니면 인라인) → 5(AC가 통합 요구 시만) → 6.
- **large** → 1 → 2(**2 Stop**: PRD승인 → Design승인, SSOT 이중 경계) → 3(**batch 승인 Stop**) → 4(무거운 dynamic Workflow, 비충돌 유닛마다 워크트리·opus 서브에이전트, 무제한) → 5(기본 ON) → 6. **총 3 Stop.**

**Stop 정책 (B-패턴, 정확히 보존):** small=0 / medium=1 / large=3. **머지 직전 Stop 없음.** 마지막 승인(large=3절 batch / medium=2절 통합) 후 페이즈 4–6 **자율**(사용자 인터럽트 = 암묵 동의). large의 PRD·Design 이중 Stop은 한 페이즈 안의 **두 개의 순차 체크포인트**로 명시 — 절대 하나로 합치지 않는다(§3 불변식). 강제 에스컬레이션(정책 무관, 항상 알림/Stop): requirements_change·architectural_change·untestable_ac, mid-flight auto-large(누락 Stop 삽입), 리뷰 3R 연속 BLOCKING, rescue 검증 실패, codex 미준비(해당 레인만 보류·킹 통지, 메인 대화 계속, codex 리뷰 없이 머지 금지).

**디스패치 규칙 (G5):** dynamic workflow는 **≥2 비충돌 유닛일 때만**. 단일 유닛·`/task` = 인라인 BG 서브에이전트(의식 없음). 비차단(G0): 모든 [BG]는 run_in_background, 킹은 디스패치 직후 즉시 사용자 복귀. 시스템에서 진짜 동기 await는 codex 리뷰 하나뿐 — 그건 **레인 내부**에서 일어나고 킹은 그 레인을 BG로 띄워 안 막힌다.

**품질 게이트 (복잡도·페이즈 무관 불변):** PR마다 codex 어드버서리얼 리뷰(codex 단독 리뷰어), 전 AC 체크 통과, green CI, **테크노킹 단독 squash 머지** + pre-merge 체크리스트.

### 복잡도 판정 (라우팅 두뇌)

- **small**: 1–2 파일 / 단일 영역 / DB·API·auth·외부 의존 없음
- **medium**: 3–5 파일 / 소규모 DB or 1–2 API / 기존 도메인
- **large**: 6+ 파일 / BE+FE 동시 / 대규모 DB / 신규 도메인 / 외부 연동
- **auto-large 트리거**: auth·권한, DB 스키마 마이그레이션, 신규 도메인, 외부 결제·법률. 매 스텝 재평가.

---

## 8. 코드 리뷰 & rescue (codex 고정, 하네스 제거)

- **리뷰어 = codex** (`/codex:adversarial-review`). Roastmaster 스킬은 diff를 직접 보지 않고 codex 결과를 **판정**(uphold/downgrade/escalate)·분류(BLOCKING/SHOULD/NIT/OUT-OF-SCOPE) → verdict(APPROVE/COMMENT/BLOCKING).
- **하네스 제거**: 비차단 dispatch + `/codex:result` 폴링 + RR placeholder + `.runtime` sentinel + 30분 타임아웃 데몬 삭제. 대신 **백그라운드 리뷰 워크플로우 내부에서 codex 결과를 동기 await** (킹은 그 워크플로우를 BG로 띄워 안 막힘).
- **codex 미준비 처리**: 전체 halt 금지(G0). 해당 리뷰 레인만 보류 → 에스컬레이션을 킹에 notification → 킹이 사용자에게 안내(`/codex:setup`). 메인 대화는 계속 가능.
- **rescue**: 6-step 상태머신 → 1개 `rescue` 스킬로 축소. 불변식 유지(티켓·시그니처당 ≤1, 초과 시 사용자, rescue의 rescue 금지). `error_signature` 수동 SHA-1 + `kind:error_2x` inbox 프로토콜 삭제 — 워크플로우가 실패를 직접 본다.

---

## 9. 대시보드 (G8 — 별도 프로젝트)

- **별도 git repo**로 직접 구현 (이 플러그인 repo와 분리). multica 스타일(보드 컬럼·assignee·실시간 스트리밍)만 차용, multica 자체 연동은 안 함.
- **데이터 소스**: 플러그인이 `.claude-team/tickets/*`(상태=컬럼, frontmatter=카드) + `events.jsonl`(append-only)을 내보냄.
- **이벤트 emit**: 데몬 없음. **HTTP POST 없음** — 플러그인은 티켓 상태 쓰기·스킬 stage 경계마다 `events.jsonl`에 **한 줄 append**만 한다(의존성 0). 대시보드(별도 repo)가 **읽기 레이어에서만** tail+WS push. 절대 오케스트레이터 wake 채널로 부활 금지(= L1/G1 안티패턴).
- **입도(확정)**: **Hybrid** — Tier1 티켓 상태 전이(컬럼) + Tier2 per-skill stage(레인 내부 타임라인). 보드=컬럼, 카드=stage 타임라인.
- **컬럼**: queue / in-progress / in-review / done(+cancelled). **squad** = 스킬 레인(design/FE/BE/QA/review).
- 스택: 자체 구현(예: Next.js + WebSocket). `/status` CLI 보드는 폴백으로 유지.
- **계약(확정)**: 플러그인 ↔ 대시보드 인터페이스 = `events.jsonl` 스키마. 상세는 **`docs/events-contract.md`** (P0에서 작성, v1).

---

## 10. 지침 철학 (G9)

- **글자수 하드 제한 없음.** karpathy `CLAUDE.md`(약 750단어, 4원칙, 굵은 한 줄 + 불릿, 직설·반독단) 처럼 **간략·핵심·간결**.
- load-bearing 표(복잡도 판정, Stop 정책, 티켓 스키마, git-flow 네이밍)는 *필요한 만큼만* 명시 — 규칙을 삭제하지 않되 군더더기·중복·하네스 설명은 제거.
- 커맨드 본문엔 로직 금지, 항상 스킬 위임.
- 삭제되는 하네스 설명(데몬/wake/watchdog/inbox/5-페인)이 대부분이라 분량은 자연 감소.

---

## 11. 마켓플레이스 / 디렉터리 구조

```
personal-claude-code-v2/            (이 repo)
  CLAUDE.md                         ← 최소 글로벌 지침
  planning.md                       ← (이 문서)
  .claude-plugin/marketplace.json
  workflows/                        ← 코어 플러그인 (stack-agnostic)
    commands/   *.md                ← /feat /task /design /diagnose /review /status /handoff /cleanup /abort /setup-team /hire /show-team
    agents/     technoking.md       ← 유일한 에이전트
    skills/     prd, design, backend, frontend, qa, review,
                orchestration-guide, ticket-protocol, git-flow,
                adversarial-review-bridge, coding-principles, testing-principles
    bin/        ticket-publish.sh (flock), board-emit (events.jsonl) — 그 외 v1 bin 삭제
    hooks/      block-dangerous.sh, stop-verification (plugin.json/hooks.json에 명시 배선)
  stacks/                           ← 스왑형 오버레이 (독립 버전)
    kotlin-spring/ , nextjs/        ← 간략화된 SKILL + canonical 명령
─────────────────────────────────────────────
(별도 repo) personal-claude-dashboard/   ← G8, 직접 구현, events.jsonl 소비
```

- **삭제할 v1 bin**: `technoking-watcher.sh, technoking-watchdog-daemon.sh, technoking-daemons.sh, ticket-watchdog.sh, worker-idle.sh, worker-launch.sh, ticket-poll.sh, tmux-setup.sh`. (멀티 테크노킹 옵트인 시 슬림한 pane 부트스트랩만 별도)
- **hook 배선 명시화**: v1은 `.claude/settings.local.json` 관행 의존 → v2는 `plugin.json`/`hooks.json`에 Stop·PreToolUse 선언. `stop-verification`은 변경 파일 테스트로 스코프 축소 검토.

---

## 12. 구현 로드맵 (제안)

| 단계 | 산출물 | 비고 |
|---|---|---|
| **P0** | 이 `planning.md` 합의 | ✅ 현재 |
| **P1** | 스캐폴딩: marketplace.json, workflows plugin.json, `.claude-team/` 디렉터리, `registry.json`, CLAUDE.md(최소) | 골격 |
| **P2** | 티켓 핵심: `ticket-protocol` 스킬, `ticket-publish.sh`(flock), `events.jsonl` emit, `git-flow` 스킬 | G2/G3 기반 |
| **P3** | 스킬 6종(prd·design·backend·frontend·qa·review) — 간략 카드 + 필요한 표 | G5/G7 |
| **P4** | `orchestration-guide` + `technoking` 에이전트 — 비차단 BG 디스패치·동시성 플래너 | G0/G4 |
| **P5** | 커맨드 12종 재표현 (스킬 위임) | — |
| **P6** | codex 브리지 동기 await 재구성 + rescue 스킬 | 8절 |
| **P7** | stacks 오버레이 간략화 (kotlin-spring, nextjs) | G9 |
| **P8** | (별도 repo) 대시보드 + events.jsonl 계약 설계 문서 | G8 |
| **P9** | 멀티 테크노킹 pane 런처 (옵트인) | G6 |

---

## 13. 미해결 / 후속 결정

### 확정 (2026-06-15 라운드)
- **events.jsonl 입도** → **Hybrid** (Tier1 티켓 상태 전이 + Tier2 per-skill stage). 스키마 = `docs/events-contract.md`.
- **files_in_scope 충돌 안전망** → **보수적 순차 + 워크트리 격리** (겹칠 가능성 시 depends_on 순차, 확실한 비충돌만 병렬).
- **stop-verification 스코프** → **변경 파일 관련 테스트만** (CI 중복 회피, 전체 검증은 머지 전 CI).
- **stacks 범위** → **kotlin-spring + nextjs 둘 다 유지(간략화)** (P7).

### 남은 미해결
- **in-lane codex 타임아웃 가드**: 데몬(30분 워치독)은 삭제하되, **레인 내부 타임아웃 가드는 유지** — 행(hang)된 codex가 워크트리를 영구 점유하지 않도록 에스컬레이션 반환. (기본값 30분, 실측 조정)
- **files_in_scope[] 정확도 의존**(잔여 리스크): 보수적 정책으로도 *늦은 쓰기 충돌* 가능 → 페이즈 5 수렴 배리어 + 페이즈 경계 킹 재평가로 완화.
- **fat lane 컨텍스트 압박**: qa-pre+구현+리뷰를 한 인라인 서브에이전트에 몰면 큰 유닛은 압박 → 컨텍스트 예산 가드로 레인 분할 필요할 수 있음.
- **서브에이전트 동시 캡**: 설계상 무제한이나 단일 Workflow 런타임 캡(~16) 존재 → 폭 넓으면 큐잉/여러 BG 워크플로우 분산. 킹은 어느 경우든 안 막힘.
- **멀티 테크노킹 머지 게이트 경합 (P9)**: 동일 main 동시 squash 시 **T-counter flock 외 머지 게이트 전용 flock** 필요. 멀티킹 활성화 전 해결 전제.
- **codex 미준비 UX**: 안내 문구·재시도. 폭 넓은 fan-out은 codex 호출이 유닛 수만큼 증가 → 비용·레이트리밋 `/status` 가시화.

---

*이 문서는 합의의 단일 출처다. 페르소나·스킬·커맨드·대시보드 설계가 충돌하면 이 문서가 우선한다. 변경 시 이 문서를 먼저 갱신한다.*
