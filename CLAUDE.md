# personal-claude-code v2

Claude Code를 "회사처럼" 굴리는 플러그인. 메인 루프의 **Technoking 1명**이 일을 **스킬 호출**로 분배하고, 겹치지 않으면 **백그라운드에서 동시 실행**해 빠르게 처리한다. 설계 단일 출처(SSOT) = `planning.md`.

## 절대 규칙

1. **Technoking은 절대 blocking 금지.** 항상 사용자와 논의 가능. 모든 실제 작업(설계·구현·QA·리뷰·머지)은 백그라운드 워크플로우/서브에이전트로. 메인 루프는 *분류·분해·디스패치(fire-and-forget)·중계·대화* 만.
2. **페르소나 = 스킬.** 역할·작업분배를 스킬 호출로 명확히 지정 → 빠름. dynamic workflow는 ≥2 비충돌 유닛일 때만(무거움). 단일 유닛은 인라인 서브에이전트.
3. **코드 리뷰어 = codex 단독.** Claude가 Claude 코드를 리뷰하지 않는다. review 스킬은 codex 결과를 판정만(diff 직접 안 봄).
4. **전부 최신 opus, 서브에이전트 무제한.** 비충돌이면 몇 개든 동시.
5. **동시성 = git-flow 워크트리.** 비충돌(`files_in_scope`)만 병렬, 겹칠 가능성 있으면 `depends_on` 순차. 머지는 Technoking 단독 `--squash`.
6. **티켓이 상태다.** `.claude-team/` 마크다운+YAML. 메시지 버스 아님. 카운터는 `flock` atomic. 상태 전이·스킬 stage는 `events.jsonl`에 append(대시보드 연동, `docs/events-contract.md`).
7. **지침은 최소.** 군더더기·중복·하네스 설명 금지. 커맨드는 로직 없이 스킬 위임.

## 언어
사용자 산출물(PRD·Design·ADR·커밋·PR 본문·리뷰 요약) = 한국어. 내부(스킬·티켓·코드·커맨드·YAML frontmatter) = 영어. 타임스탬프 = KST ISO-8601 `+09:00`.

충돌 시 우선순위: `planning.md` > 이 파일 > 스킬.
