# 2026-04-10: Question Governance, Adaptive Depth, Extension System

## 배경

BMAD-METHOD와 aidlc-workflows 프로젝트를 참조하여 team-ai-workflow를 업데이트.
워크숍 실전 경험에서 발견한 3대 문제(질문 초점 이탈, 결정권자 부재, 지식 부족 답변 누적)를 직접 해결.

## 철학 변화

```
이전: "AI는 정책을 결정하지 않는다. 모르면 멈추고 질문해."
이후: "AI는 정책을 결정하지 않지만, 도메인 지식은 적극적으로 제안한다.
      질문의 깊이와 범위는 작업의 복잡도에 맞추고,
      모든 질문은 원래 요청과의 관계를 명시한다."
```

## 변경 사항

### 1. Question Governance (신규)
- `common/question-governance.md` — 질문 범위 통제, 유형 분류, 확신도 추적, 질문 예산
- Focus Anchor: 모든 질문 파일에 최초 요청 앵커 고정
- 질문 유형: policy(사람 필수) / domain(AI 추천 가능) / scope(범위 판단)
- AI-RECOMMEND: domain 유형 질문에 AI가 근거 기반 추천안 제시
- Confidence Tagging: 답변에 확신도(확실/추정/AI추천/미정) 표기
- Question Budget: depth별 라운드당 질문 상한

### 2. Adaptive Depth (신규)
- `common/depth-levels.md` — 3단계 깊이(minimal/standard/comprehensive)
- STEP 1-B에서 depth 판정, 이후 모든 단계에 적용
- depth별 질문 예산, 템플릿 상세도, 게이트 메시지 깊이 차별화

### 3. Extension / Opt-In System (신규)
- `extensions/` 디렉토리 + `common/extension-rules.md`
- `*.opt-in.md` 경량 프롬프트 → opt-in 시에만 전체 규칙 로드
- security-baseline을 첫 번째 extension으로 이관 및 상세화 (SECURITY-01~11 평가 기준)

### 4. Reverse Engineering 강화
- `core/reverse-engineering.md` — STEP 1.5로 체계적 brownfield 분석
- `templates/reverse-engineering/` — business-overview, architecture-overview, component-inventory

### 5. Skill Validation Framework (신규)
- `tools/skill-validator.md` — 10개 검증 규칙 (6개 자동 + 4개 추론)
- `tools/validate-skills.sh` — 자동 검증 스크립트

### 6. Content Validation (신규)
- `common/content-validation.md` — 답변 간 모순 감지, Mermaid/ASCII 검증

## 수정된 기존 파일

- `core/core-workflow.md` — STEP 1-B(depth), STEP 1.5(RE), question-governance/content-validation 참조 추가
- `common/question-rules.md` — AI-RECOMMEND, DEFER-TO-FEATURE, 확신도 필드 추가
- `common/stage-gate-rules.md` — Progress Line 추가
- `templates/aidlc-state.md` — Depth Level, Confidence Summary, Extension Configuration, STEP 1-B/1.5 추가
- `templates/requirement-verification-questions.md` — Request Anchor, Scope Tag, AI 추천, 확신도 포맷
- `templates/security-baseline.md` — extensions/ 이관 안내로 변경

## 참조 출처

| 출처 | 가져온 패턴 |
|------|-----------|
| BMAD-METHOD | AI 퍼실리테이터 역할, Skill Validation |
| aidlc-workflows | Adaptive Depth, Extension Opt-In, Contradiction Detection |
| 워크숍 경험 | Question Governance (3개 프로젝트 모두에 없던 신규 패턴) |
