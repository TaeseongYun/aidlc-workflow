# 2026-04-14: 토큰 다이어트 — 중복 서술 압축

## 배경

프로젝트 총 8,700줄 중 동일 규칙이 여러 파일에서 반복 서술되어 불필요한 토큰을 소모하고 있었다. 프로세스나 규칙 자체를 제거하지 않으면서, **"한 곳에 정의 + 나머지는 참조"** 원칙을 적용하여 토큰 효율을 개선한다.

## 핵심 원칙

- **규칙의 존재는 반복하되, 규칙의 내용은 한 곳에만** 정의한다.
- 각 스킬이 독립 실행될 때 컨텍스트에 핵심 지시가 남아 있어야 하므로, "이 규칙을 따르라"는 언급은 유지한다.
- 상세 정의(P0/P1/P2 뜻, 중단 출력 형식 등)는 원본 문서를 참조한다.

## 변경 사항

### 1. ctx-aidlc-run/SKILL.md — STEP 보일러플레이트 통합 (-90줄)

- **STEP LIFECYCLE 공통 패턴** 상단 1회 선언: 시작/스킵/완료 시 audit.md 및 aidlc-state.md 갱신 규칙
- 개별 STEP에서 `Append [STEP-X]... to audit.md`, `Update aidlc-state.md` 보일러플레이트 제거
- STEP 4 질문 거버넌스 재서술 25줄 → 핵심 규칙 7줄로 압축 (상세는 `question-governance.md` 참조)
- 조건부 STEP을 "조건: X. 아니면 스킵." 패턴으로 통일
- GATE 메시지를 "`stage-gate-rules.md` 포맷 사용. 승인 전 진행 금지." 1줄로 통일

### 2. stage-gate-rules.md — 게이트 상세 통합 (-73줄)

- 기존: 요약 테이블 + 게이트별 발동조건/리뷰항목/통과후 각각 개별 섹션
- 변경: 테이블에 발동조건/통과후/건너뛰기 통합, 개별 섹션은 **리뷰 항목만** 잔류
- 발동조건/통과후가 테이블과 개별 섹션에서 이중 정의되던 문제 해소

### 3. question-governance.md — 포맷 중복 제거 (-21줄)

- 섹션 6 "질문 포맷 통합": 질문 포맷을 `question-rules.md`와 동일하게 재서술하던 것을 참조로 대체
- 유형별 필드 사용 테이블은 "미응답 대응 제한" 테이블로 압축하여 유지

### 4. 스킬 4개 — 중단 출력 형식 중복 제거 (각 -14줄)

대상: ctx-reviewer, ctx-refiner, ctx-domain-exec, ctx-architect-judge

- 기존: 중단 조건 + 중단 시 출력 형식을 각 스킬에서 전문 재서술
- 변경: 중단 조건 목록만 유지, 출력 형식은 `skills/_shared/skill-protocol.md` 참조
- ctx-updater, ctx-commit-planner는 고유 중단 출력 형식이 있으므로 변경하지 않음

## 수정된 파일 전체 목록

| 파일 | 변경 유형 | 줄 수 변화 |
|------|----------|-----------|
| `skills/ctx-aidlc-run/SKILL.md` | 보일러플레이트 통합, 참조화 | 556 → 466 (-90) |
| `common/stage-gate-rules.md` | 게이트 상세 통합 | 222 → 149 (-73) |
| `common/question-governance.md` | 포맷 중복 제거 | 257 → 236 (-21) |
| `skills/ctx-reviewer/SKILL.md` | 중단 출력 참조화 | 183 → 169 (-14) |
| `skills/ctx-refiner/SKILL.md` | 중단 출력 참조화 | 298 → 285 (-13) |
| `skills/ctx-domain-exec/SKILL.md` | 중단 출력 참조화 | 205 → 191 (-14) |
| `skills/ctx-architect-judge/SKILL.md` | 중단 출력 참조화 | 165 → 151 (-14) |

**총 변경: 86줄 삽입, 318줄 삭제 = 순 -232줄**

## 변경하지 않은 것

- 프로세스 흐름 (STEP 순서, GATE 발동 조건, 스킵 조건)
- 규칙 내용 (질문 거버넌스, 가드레일, 입력 검증)
- 출력 포맷 (각 스킬의 출력 구조)
- ctx-run/SKILL.md, ctx-updater/SKILL.md, ctx-commit-planner/SKILL.md (고유 구조라 압축 대상 아님)
- core/, templates/, docs/ (이미 효율적)
