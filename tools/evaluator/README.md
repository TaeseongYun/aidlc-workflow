# Evaluator — 산출물 검증 도구

aidlc-docs 산출물의 품질을 자동 검증한다.

## 사용법

```bash
# 전체 검증 (권장)
bash tools/evaluator/validate-all.sh aidlc-docs/features/<feature-slug>

# 개별 검증
bash tools/evaluator/validate-artifacts.sh aidlc-docs/features/<feature-slug>
bash tools/evaluator/validate-questions.sh aidlc-docs/features/<feature-slug>
bash tools/evaluator/validate-readiness-score.sh aidlc-docs/features/<feature-slug>
```

## 검증 항목

### validate-artifacts.sh — 산출물 완성도
- 필수 파일 존재 (status.md, requirements.md, questions.md, unit-of-work.md)
- 필수 섹션 존재 (Goal, In-Scope, Summary 등)
- 빈 섹션 감지
- UOW ID 참조 무결성 (Summary ↔ 본문 헤딩)
- feature-slug 일관성 (status.md ↔ 디렉토리명)
- 다이어그램 검증 (Mermaid 텍스트 대안, 유니코드 박스 문자)

### validate-questions.sh — 질문 거버넌스 태그
- Request Anchor 존재
- Summary 테이블 존재
- 질문별 필수 필드 (분류, 영향도, 미응답 시, 범위, 우선순위)
- policy 질문에 AI 추천 금지 검증
- BLOCK 질문/미답변 현황
- 확신도 태그 통계

### validate-readiness-score.sh — Readiness Score
- Score 테이블 존재 및 합계 추출
- 판정(READY/CONDITIONAL/NOT_READY) 일관성 (점수 기준)
- BLOCK 질문 교차 검증 (READY인데 BLOCK 존재 시 오류)
- 배점 합산 검증
- UNCERTAIN 마커 교차 검증

## 종료 코드

| 코드 | 의미 |
|------|------|
| 0 | 통과 (경고 포함 가능) |
| 1 | 실패 (오류 존재) |
