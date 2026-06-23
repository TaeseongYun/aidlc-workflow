<!-- workflow-step: STEP-1 | gate: none | producer: ctx-aidlc-run | updated-by: all steps -->
# Feature Status

## Identity
- Feature Slug:
- Title:
- Request Type:
  - raw-request / prepared-requirement / change-on-existing-feature
- Status:
  - intake / planning-draft / questions-open / approved / implementing / completed / parked

## Readiness Score

| 영역 | 배점 | 점수 | 상태 |
|------|------|------|------|
| 기능 범위 정의 | 15 | | |
| 정책/예외 확정 | 20 | | |
| 사용자 시나리오 | 15 | | |
| NFR 확인 | 15 | | |
| 승인 항목 해결 | 20 | | |
| 리스크 평가 | 15 | | |
| 사용자 스토리 품질 (조건부) | 10 | | 해당 없음 / 채점 |
| 시스템 구조 설계 (조건부) | 10 | | 해당 없음 / 채점 |
| **합계** | **100 (+가점)** | | |

판정 기준:
- 기본 만점 100점. 조건부 영역 활성화 시 만점이 증가한다.
- 판정 임계값은 실제 만점의 80%/60% 비율로 환산한다.
- 60% 미만: 구현 금지 (BLOCK 질문 잔존 가능성 높음)
- 60~79%: 조건부 진행 (ASSUME 가정 명시 필수)
- 80% 이상: 구현 가능

## Post-Implementation Score (구현 후 — ctx-score-loop)

구현 **이후** 의존성 인지 점수 루프(`/ctx-score-loop`)가 산출하는 최신 점수를 미러한다.
Readiness Score(구현 전)와 시점·용도가 다르다. 상세 이력은 피처/모듈 디렉토리의 `dependency-check.md` Score History를 본다.

| 항목 | 값 |
|------|-----|
| 최신 총점 | (0~100) |
| 최신 라운드 | |
| 축별 (의/빌/테/AC) | / / / |
| 판정 | COMPLETE(>85) / INCOMPLETE / STALLED / EXHAUSTED / REGRESSED |
| 최종 갱신 | (ISO 8601 UTC) |

채점 기준: `core/dependency-score.md`. 완료 임계: 85점 초과(`> 85`) AND 빌드 축 ≠ 0 (GR-1).

## Scope
- Goal:
- In-Scope Summary:
- Out-of-Scope Summary:

## Gate Approval History

| Gate | Decision | Timestamp | Notes |
|------|----------|-----------|-------|
| GATE-1 (Planning Draft) | - | - | raw-request only |
| GATE-2 (Requirements) | - | - | |
| GATE-2.5 (User Stories) | - | - | 조건부 |
| GATE-2.7 (Application Design) | - | - | 조건부 |
| GATE-3 (Unit-of-Work) | - | - | |
| GATE-3.5 (Technical Design) | - | - | M/L only |
| GATE-4 (Infrastructure Design) | - | - | 조건부 |
| GATE-5 (Build & Test) | - | - | 조건부 |

## Approval
- Requirement Status:
- Design Status:
- Last Approved At:
- Approved By:

## Implementation
- Code Started:
- Current Owner:
- Related Branch:

## Related Files
- Request Intake:
- Planning Draft:
- Requirements:
- Questions:
- Personas:
- Stories:
- Components:
- Services:
- Component Dependency:
- Unit of Work:
- Dependency Map:
- Story Map:
- Technical Design:
- Infrastructure Design:
- Deployment Architecture:
- Build Instructions:
- Test Instructions:
- Security Baseline:

## Notes
-
