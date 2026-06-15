---
description: Serialize orchestrator context to a handoff ticket, or resume from the latest one.
argument-hint: "[--resume]"
---

`$ARGUMENTS` 가 `--resume` 면 **RESUME**, 아니면 **SAVE**.

**SAVE** (기본): 현재 in-flight 티켓 · 열린 Stop · 미해결 에스컬레이션/rescue · 다음 액션을 `HANDOFF-<ts>` 아티팩트로 직렬화한다 (see `ticket-protocol`). 한국어 요약으로 마무리.

**RESUME** (`--resume`): `.claude-team/handoff/` 의 **최신 `HANDOFF-*`** 를 읽어 in-flight 티켓 · 열린 Stop · 미해결 항목을 복원·요약하고 다음 한 걸음을 제안한 뒤 **사용자 입력 대기**. handoff 가 없으면 "이어갈 컨텍스트 없음" 안내 후 대기. **비차단(G0)**: 복원은 요약까지만 — 실제 작업 재개는 사용자 확인 후 백그라운드로.
