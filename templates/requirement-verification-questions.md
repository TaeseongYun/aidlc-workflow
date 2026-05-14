<!-- workflow-step: STEP-4 | gate: GATE-2 | producer: ctx-aidlc-run -->
# Requirement Verification Questions

이 파일은 `aidlc-docs/features/<feature-slug>/requirement-verification-questions.md`에 생성하는 것을 권장한다.

관련 상태 파일:
- `aidlc-docs/features/<feature-slug>/status.md`

질문 작성 기준:
- 질문 포맷과 규칙은 `common/question-rules.md`를 따른다.
- 질문 거버넌스(범위, 유형, 확신도, 예산)는 `common/question-governance.md`를 따른다.
- BLOCK 질문이 1개라도 남아 있으면 requirements.md는 implementation-ready가 아니다.

> **Request Anchor**: {최초 요청 1-2줄 요약 — STEP 2에서 확정}

## Summary

| ID | 우선순위 | 범위 | 유형 | 분류 | 영향도 | 상태 | 미응답 시 | 확신 |
|----|----------|------|------|------|--------|------|-----------|------|
| Q1 | P0/P1 | | policy/domain/scope | | | OPEN / ANSWERED | BLOCK / ASSUME / AI-RECOMMEND / DEFER | |

## 1. Domain And Scope

### Q1. {질문 제목}
- 우선순위: P0-CRITICAL / P1-IMPORTANT
- 범위: [원래 요청] {관련 부분 설명}
- 유형: policy / domain / scope
- 분류: scope
- 영향도: high / medium / low
- 이유: {이 질문이 필요한 이유}
- 선택지:
  - A) {선택지} → {구현 영향}
  - B) {선택지} → {구현 영향}
  - C) 기타 (직접 입력)
- AI 추천: {선택지}) {추천 내용} — 근거: {판단 근거}
- 미응답 시: BLOCK / ASSUME-{X} ({가정 근거}) / AI-RECOMMEND-{X} / DEFER-TO-FEATURE
- [답변]:
- [확신]: 확실 / 추정 / AI추천 / 미정

## 2. User Flow
<!-- Q1과 동일 포맷. 카테고리에 맞는 질문을 추가한다 -->

## 3. Policy / Exception
<!-- Q1과 동일 포맷. policy 유형 질문은 AI 추천 필드를 사용하지 않는다 -->

## 4. Integration
<!-- Q1과 동일 포맷. 카테고리에 맞는 질문을 추가한다 -->

## 5. Ops / Notification / Reporting
<!-- Q1과 동일 포맷. 카테고리에 맞는 질문을 추가한다 -->

## AI 자동 결정 (P2)
<!-- P2-DEFERRABLE 항목은 AI가 디폴트로 결정하고 여기에 기록한다. 인간은 사후 검토 가능. -->

| # | 항목 | 디폴트 값 | 근거 | 변경 시 영향 |
|---|------|----------|------|-------------|
| | | | | |

## 추가 질문 (다음 라운드)
<!-- 질문 예산 초과 시 여기에 보관. 현재 라운드 답변 완료 후 승격 -->
