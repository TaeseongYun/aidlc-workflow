# 변경 사항: 기술 설계(Technical Design) 단계 추가

## 변경 일자
2026-03-23

## 배경

기존 워크플로우에서 **요구사항 분석(ctx-aidlc-run) → 구현(ctx-run)** 사이에 기술 설계를 수행하는 단계가 없었다.

이로 인해 발생하던 문제:
- API 응답 형태가 미정인 채로 구현에 진입 → `ctx-run` DESIGN VALIDATION에서 매번 STOP
- DB 스키마, 모듈 구조 등을 구현자가 즉흥 결정하거나, 사용자가 직접 지정해야 함
- "왜 이 설계를 선택했는가"에 대한 기록이 남지 않음

## 무엇이 바뀌었나

### 변경 전 흐름

```
요구사항 분석 → unit-of-work 분해 → GATE-3 → Readiness Score → 종료
                                                ↓
구현(ctx-run) → DESIGN VALIDATION에서 설계 미비 발견 → STOP → 사용자에게 질문
```

### 변경 후 흐름

```
요구사항 분석 → unit-of-work 분해 → GATE-3
  → [M/L 규모 존재] 기술 설계(STEP 6.5) → GATE-3.5 → Readiness Score → 종료
  → [전체 S 규모]   Readiness Score → 종료 (기술 설계 생략)

구현(ctx-run) → DESIGN VALIDATION에서 technical-design.md 확인 → 이미 검증됨 → 바로 구현 진행
```

---

## 변경 파일 목록

### 신규 파일

| 파일 | 설명 |
|------|------|
| `templates/technical-design.md` | 기술 설계 문서 템플릿 |

### 수정 파일

| 파일 | 변경 내용 |
|------|----------|
| `skills/ctx-aidlc-run/SKILL.md` | STEP 6.5 + GATE-3.5 추가, 규모 필드 필수화, 산출물 목록 추가 |
| `skills/ctx-run/SKILL.md` | DESIGN VALIDATION이 technical-design.md 우선 참조, ROLE 1이 설계 문서 따르도록 |
| `common/stage-gate-rules.md` | GATE-3.5 정의 추가, GATE-3에 규모 필드 검증 추가 |
| `core/core-workflow.md` | 승인 게이트 + 산출물 목록에 반영 |
| `common/diagram-standards.md` | 사용 시점에 technical-design.md 추가 |

---

## 기술 설계 템플릿 구성

`technical-design.md`는 9개 섹션으로 구성된다.

| 섹션 | 내용 | 필수 여부 |
|------|------|----------|
| 1. Design Overview | 설계 요약, 대상 모듈, brownfield 연결점 | 필수 |
| 2. Architecture Decisions | ADR 형식으로 기술 결정 기록 (맥락/선택지/결정/영향) | 필수 |
| 3. API Specification | 엔드포인트, 요청/응답 구조, 에러 코드 | API 변경 시 |
| 4. Data Model | 엔티티/필드/제약조건, 마이그레이션 전략 | DB 변경 시 |
| 5. Module/Component Structure | 모듈별 책임과 UOW 매핑 | 필수 |
| 6. Interaction Flow | 시퀀스/플로우 다이어그램 | 플로우가 자명하지 않을 때 |
| 7. Non-functional Design | 성능/정합성/보안/운영 (해당 항목만) | 필수 |
| 8. Testing Approach | UOW별 테스트 유형과 검증 내용 | 필수 |
| 9. Open Items | 미확정 사항 (없으면 "없음") | 필수 |

### 해당 없음 표기 규칙
- API 변경 없음 → Section 3에 "해당 없음"
- DB 변경 없음 → Section 4에 "해당 없음"
- 플로우가 자명 → Section 6에 "해당 없음"

---

## 실행 조건

| 조건 | 동작 |
|------|------|
| unit-of-work에 M 또는 L 규모가 1개 이상 | STEP 6.5 실행 → technical-design.md 생성 |
| unit-of-work 전체가 S 규모 | STEP 6.5 생략 → status.md에 "기술 설계 생략 — 전체 S 규모" 기록 |

### 규모 기준
`core/unit-sizing.md`를 따른다.

### 규모 필드 필수화 (추가 변경)
- 기존: unit-of-work 규모 필드가 비어 있어도 GATE-3 통과 가능
- 변경: 모든 UOW의 규모 필드(S/M/L)가 채워져 있어야 GATE-3 통과 가능
- 이유: STEP 6.5 실행 여부가 규모 필드에 의존하므로 빈 값 허용 불가

---

## GATE-3.5 리뷰 체크리스트

기술 설계 리뷰 시 확인할 항목:

- [ ] ADR 결정이 근거 있는 선택인가 (추측이 아닌가)
- [ ] API 응답 형태가 명시적이고 완전한가
- [ ] 데이터 모델 변경이 기존 스키마와 호환되는가
- [ ] 모듈 구조가 unit-of-work 분해와 일치하는가
- [ ] 암묵적 설계 결정이 남아 있지 않은가

---

## ctx-run 연계

`ctx-run` (구현 단계)에서의 동작 변화:

| 상황 | 변경 전 | 변경 후 |
|------|--------|--------|
| technical-design.md 있음 | - | DESIGN VALIDATION 통과 (사전 검증 완료). ROLE 1이 API/Data Model/Module 설계를 따라 구현. |
| technical-design.md 없음 (S 규모) | DESIGN VALIDATION에서 개별 검증 | 동일 (기존 방식 유지) |
| Open Items 미해결 | - | DESIGN VALIDATION에서 STOP. "DESIGN OPEN ITEMS UNRESOLVED" 출력. |

---

## 기존 워크플로우와의 호환성

- **하위 호환**: technical-design.md가 없어도 ctx-run은 기존 방식으로 동작
- **기존 산출물 변경 없음**: requirements.md, unit-of-work.md 등 기존 문서 형식은 그대로
- **역할 분리 유지**: ctx-aidlc-run 내부 STEP으로 추가. 별도 스킬을 만들지 않음

---

## 설계 근거

이 변경은 업계 베스트프랙티스 조사를 기반으로 설계되었다.

| 적용한 패턴 | 출처 |
|------------|------|
| Architect/Editor 분리 | Aider Architect Mode — 설계 추론과 코드 작성 분리 |
| ADR (Architecture Decision Record) | Michael Nygard 표준, AWS/Microsoft 채택 |
| Spec-first 접근 | GitHub Spec Kit — 스펙 확정 후 구현 |
| 기술 청사진 | implementation-planning-guide — 파일/클래스 수준 설계 |
| C4 모델 Component 레벨 | 업계 표준 — Context/Container/Component 중 L3까지 |
| Google 설계 문서 구조 | Design Overview + Alternatives + Open Questions |

### 의도적으로 제외한 항목

| 항목 | 제외 이유 |
|------|----------|
| Timeline/일정 | unit-of-work.md 규모(S/M/L)가 이미 담당 |
| Alternatives (별도 섹션) | ADR 내 선택지로 통합 |
| Dependencies (별도 섹션) | unit-of-work-dependency.md가 이미 담당 |
| Rollout/배포 전략 | 워크플로우 범위 밖 (운영 영역) |
| Security (별도 섹션) | Non-functional Design에 통합 |
