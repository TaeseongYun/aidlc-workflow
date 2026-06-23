<!-- workflow-step: post-implementation | producer: ctx-score-loop | location: feature/module directory | append-only-history -->
# Dependency Check — {feature-slug 또는 module name}

이 파일은 의존성이 필요한 **각 피처/모듈 디렉토리 안**에 둔다 (분산 배치, 중앙 모음 아님).
권장 경로 예: `aidlc-docs/features/<feature-slug>/dependency-check.md` 또는 해당 모듈 폴더 내.

`/ctx-score-loop`이 이 파일을 읽고 4축 채점한다. 채점 기준: `core/dependency-score.md`.

> **머지 규칙**: 항목 끝의 출처 마커를 보고 자동 갱신 범위를 정한다.
> - `<!-- src: human -->` — 사람이 작성. 루프는 **읽기만**, 절대 수정/삭제하지 않는다.
> - `<!-- src: auto -->` — 루프가 생성/갱신. 자동 머지 대상.
> - 마커가 없으면 human으로 간주하여 보존한다.

---

## Loop Config (선택 — 기본값 오버라이드)

기본값을 바꿀 때만 작성한다. 비워두면 `core/dependency-score.schema.yaml`의 기본값을 사용한다.

| 파라미터 | 기본값 | 이 피처 설정 |
|----------|--------|-------------|
| complete_threshold (초과 기준) | 85 | |
| stall_rounds (정체 판정) | 2 | |
| max_rounds (최대 반복) | 10 | |
| max_minutes (최대 시간) | 30 | |

---

## 1. 기능 간 선후관계 의존성 (Functional Order)

선행되어야 하는 다른 기능/태스크. 충족되지 않으면 의존성 축 점수에 반영된다.

| # | 선행 항목 | 기대 상태 | 해결 | BLOCK | 근거 | 출처 |
|---|-----------|-----------|------|-------|------|------|
| F-1 | {예: 로그인 feature} | completed | ☐ | ☐ | | <!-- src: human --> |

## 2. 빌드/라이브러리 의존성 (Build / Library)

Gradle 등 빌드 레벨 의존성과 라이브러리 설정.

| # | 의존성 | 기대 버전/설정 | 해결 | BLOCK | 근거 | 출처 |
|---|--------|----------------|------|-------|------|------|
| B-1 | {예: retrofit} | {버전} + 빌드 통과 | ☐ | ☐ | | <!-- src: human --> |

## 3. 모듈 간 의존성 (Module)

다른 모듈의 API를 올바르게 호출/구현하는가.

| # | From → To | 기대 계약 | 해결 | BLOCK | 근거 | 출처 |
|---|-----------|-----------|------|-------|------|------|
| M-1 | {예: feature-A → core-network} | API X 호출/구현 | ☐ | ☐ | | <!-- src: human --> |

---

## 4. Current Score (최신 라운드)

채점 기준: `core/dependency-score.md` (4축 · 각 25점). **빌드·테스트 축은 실제 명령 실행 결과만 근거. 미실행 시 0점.**

| 축 | 배점 | 점수 | 근거 (필수) |
|----|------|------|-------------|
| 1. 의존성 해결 | 25 | | (BLOCK 의존성 있으면 최대 12 — GR-2) |
| 2. 빌드/컴파일 | 25 | | (빌드 명령 종료 코드/로그 인용) |
| 3. 테스트/커버리지 | 25 | | (테스트 리포트 인용) |
| 4. 요구사항/AC 충족 | 25 | | (UOW 수용기준 + requirements FR 기준) |
| **총점** | **100** | | |

**판정**: COMPLETE (>85 & 빌드≠0) / INCOMPLETE

---

## 5. Score History (append-only)

매 라운드 1행 추가. 정체(2회 연속 미개선)·회귀(하락) 판정에 사용한다. 기존 행을 수정하지 않는다.

| round | total | per_axis (의/빌/테/AC) | verdict | timestamp (UTC) |
|-------|-------|----------------------|---------|-----------------|
| 1 | | / / / | CONTINUE / COMPLETE / STALLED / EXHAUSTED / REGRESSED | |

verdict 값:
- `CONTINUE` — 미완료, 다음 라운드 진행
- `COMPLETE` — 85 초과 & 빌드≠0, 완료 종료
- `STALLED` — 2회 연속 미개선, 중단·보고
- `EXHAUSTED` — 최대 반복/시간 도달, 중단·보고
- `REGRESSED` — 직전 대비 하락, 경고·보고 (v1 자동 롤백 없음)
