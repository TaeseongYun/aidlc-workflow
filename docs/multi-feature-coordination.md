# Multi-Feature Coordination Guide

큰 prepared 기획서가 **여러 피처**로 자연스럽게 분해될 때, 팀이 분업하면서 발생하는 중복·선행·충돌을 사전에 정리하기 위한 운용 가이드.

단일 피처 작업에는 적용하지 않는다. 단일 피처일 때는 곧바로 `/ctx-aidlc-run`으로 진입한다.

## 1. 언제 Phase 0가 필요한가

다음 중 하나에 해당하면 Phase 0(Roadmapping)을 선행한다.

- 기획서가 2개 이상의 피처를 명시적으로 나열한다
- 기획서가 ≥3개 독립 도메인을 다룬다 (예: 결제 + 알림 + 정산)
- 같은 컴포넌트/테이블/모듈을 여러 작업이 동시에 건드린다
- 팀이 분업하기로 합의했고, 누가 무엇을 맡을지 결정해야 한다

신호가 모호하면 일단 `/ctx-aidlc-roadmap`을 실행하고 STEP R1에서 단일/복수 판정을 받는다.

## 2. 진입 경로 (양방향)

### 2-1. 직접 호출
큰 기획서를 받고 곧바로:

```text
/ctx-aidlc-roadmap

다음 prepared-requirement 기획서로 Phase 0 로드맵을 작성한다.
- 원본: <기획서 경로 또는 본문>
- depth level: standard
```

### 2-2. 핸드오프 (감지 후 차단)
사용자가 멀티피처임을 모르고 `/ctx-aidlc-run`을 먼저 실행한 경우:

1. STEP 1-A 1번 라운드 ("Is this a single feature or multiple independent features?")에서 "multiple"로 답변
2. `_roadmap.md`가 없으면 `ctx-aidlc-run`이 STOP하고 `/ctx-aidlc-roadmap`을 안내
3. `audit.md`에 `[HANDOFF] ctx-aidlc-run → ctx-aidlc-roadmap` 이벤트 기록
4. 사용자는 안내된 명령으로 Phase 0 진행

## 3. Phase 0 산출물 해석

`/ctx-aidlc-roadmap` 실행 결과 `aidlc-docs/_roadmap.md`가 생성된다. 핵심 섹션은 다음과 같다.

| 섹션 | 의미 | 분업 시 활용 |
|------|------|-------------|
| 2. Feature List | 피처 슬러그 + 1줄 책임 | 담당자 배정 단위 |
| 3. Resource Matrix | 컴포넌트/테이블/API의 피처별 점유 | ⚠ 표시는 충돌 가능성 |
| 4. Dependency Graph | 피처 간 의존 + Resolution | 직렬/병렬 결정 |
| 5. Allocation Recommendation | 실행 Phase 그룹화 + 역할 권고 | 누가 언제 시작 |
| 6. Handoff Plan | 피처별 입력 발췌 + `/ctx-aidlc-run` 호출 안내 | 분담 후 실행 |

`aidlc-state.md`의 다음 영역도 함께 동기화된다.
- Roadmap State
- Feature Index (Roadmap Source 컬럼)
- Cross-Feature Dependencies

## 4. 분업 패턴

### 4-1. Foundation-First (권장 기본)

공통 도메인 모델·테이블·기반 모듈을 `foundation-*` 피처로 추출하고 **한 명이 먼저** 진행. 나머지 피처는 그 위에서 병렬.

```
Phase 1 (직렬): foundation-domain-model
Phase 2 (병렬): feature-a, feature-b, feature-c
Phase 3 (직렬): feature-d (← feature-b의 산출물 필요)
```

장점: 머지 충돌 최소화, 일관된 도메인 모델.
비용: Phase 1 동안 다른 팀원 대기.

### 4-2. Vertical Slice

각 피처를 end-to-end 수직 분할. 공통 기반은 최소화하고 각 피처가 자체 컴포넌트를 갖는다.

장점: 완전 병렬, 빠른 피드백.
비용: 추후 공통화 작업이 필요할 수 있음.
조건: 도메인 간 결합이 매우 약할 때만.

### 4-3. Sequential

의존성이 강해 병렬화가 어려운 경우 직렬 실행. Phase 0의 가치는 "어디까지 직렬해야 하는가"를 명확히 하는 데 있다.

## 5. 충돌 해결 절차

### 5-1. 자원 중복 (⚠)
같은 컴포넌트를 2개 이상 피처가 만들려고 함.
- **추출**: `foundation-*` 피처 신설, 양쪽이 의존하도록 변경
- **단일 소유 지정**: 한 피처가 만들고 다른 피처는 read-only 사용
- **분리 불가** 시: 두 피처를 하나로 병합

### 5-2. 정책 충돌
서로 다른 피처가 같은 정책(예: 환불 규칙)에 다른 가정을 둠.
- 정책을 `ctx/` 글로벌 룰로 승격해 단일 출처로 만든다
- 각 피처 STEP 4에서 동일 질문이 반복되지 않도록 함

### 5-3. 순환 의존
피처 A → B → A 형태가 발견되면 GATE-0을 통과시키지 않는다.
- 피처 분할 변경
- 의존 방향 역전 (이벤트 기반으로 디커플)
- 공통 부분 추출

## 6. 피처별 `/ctx-aidlc-run` 실행

GATE-0 승인 후, 각 팀원은 자기 피처에 대해:

```text
/ctx-aidlc-run

Phase 0 로드맵 기준으로 F-2(<slug>) 작업을 시작한다.
- 입력: prepared-requirement (원본 §3.2 ~ §3.4)
- 의존: aidlc-docs/features/foundation-domain-model/requirements.md
- aidlc-docs/_roadmap.md를 먼저 읽어라.
```

`ctx-aidlc-run`은 BOOTSTRAP에서 `_roadmap.md`를 읽고, STEP 1에서 슬러그가 로드맵에 있는지 검증한 뒤, 의존성과 공유 자원을 `status.md`의 "Roadmap Context" 섹션에 인용한다.

## 7. 자주 묻는 질문

**Q. 단일 피처인데 큰 기획서야. Phase 0을 해야 해?**
A. 안 해도 된다. STEP R1에서 단일 피처로 판정되면 모든 R-step이 `[-]`로 스킵되고, `/ctx-aidlc-run`을 직접 사용하라는 안내가 나온다.

**Q. 로드맵을 만든 뒤 새 피처가 추가되면?**
A. `/ctx-aidlc-roadmap`을 다시 실행해 `_roadmap.md`와 `aidlc-state.md`를 갱신한 뒤 GATE-0를 다시 받는다. 기존 피처 폴더는 영향받지 않는다.

**Q. 로드맵에 없는 슬러그로 ctx-aidlc-run을 실행하면?**
A. ctx-aidlc-run이 경고하고 사용자에게 (a) 로드맵 추가 (b) standalone 진행 (c) 중단 중 하나를 묻는다. 답변은 audit.md에 기록된다.

**Q. Phase 0 결과를 사람이 직접 수정해도 되나?**
A. 가능. 단, GATE-0 승인 전이라면 해당 R-step부터 다시 실행하는 것이 안전하다. 승인 후 변경은 audit.md에 변경 사유와 함께 추가 GATE-0 round를 기록한다.
