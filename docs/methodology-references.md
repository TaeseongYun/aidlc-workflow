# team-ai-workflow 방법론 참조 출처 정리

team-ai-workflow는 단일 방법론을 그대로 가져온 것이 아니라, 여러 출처에서 **실전에서 작동한 패턴만 선별**하여 조합한 프레임워크다. 이 문서는 각 출처에서 무엇을 가져왔고, 무엇을 가져오지 않았는지를 정리한다.

---

## 1. AWS AI-DLC (aidlc-workflows)

AI 기반 소프트웨어 개발 라이프사이클을 25개 산출물로 정의한 프레임워크.

### 가져온 것

| 패턴 | 우리 프로젝트에서의 위치 | 설명 |
|------|----------------------|------|
| 25개 산출물 체계 | `aidlc-docs/features/` 구조 | 요구사항 → 설계 → 구현 → 검증까지 산출물 단위로 추적. 우리는 이 중 20개(80%)를 커버. |
| Adaptive Depth (깊이 조절) | `common/depth-levels.md` | 작업 복잡도에 따라 minimal/standard/comprehensive 3단계로 산출물 상세도 조절 |
| Extension Opt-In | `extensions/`, `common/extension-rules.md` | 보안 체크리스트 등 선택적 규칙 팩을 사용자가 명시적으로 활성화하는 방식 |
| Input Validation | `core/input-validation.md` | prepared-requirement 투입 시 사전 검증 (완전성, 모순, 리스크 태그) |
| Contradiction Detection | `common/content-validation.md` | 질문 답변 간 논리적 모순을 자동 감지 |
| aidlc-state / audit 추적 | `templates/aidlc-state.md`, `templates/audit.md` | 프로젝트 상태와 의사결정 이력을 실시간 추적 |

### 가져오지 않은 것

| 항목 | 이유 |
|------|------|
| AI-DLC의 구현/배포 자동화 | 우리 프레임워크는 요구사항/설계까지만 담당. 구현은 별도 스킬(`/ctx-run`)로 분리 |
| 25개 산출물 전체 | 5개(Monitoring, Observability, Deployment Pipeline 등)는 운영 영역으로 제외 |
| 추정(Estimation) 체계 | 의도적으로 제외. S/M/L 규모만 사용하고 시간 추정은 하지 않음 |

---

## 2. BMAD-METHOD

AI 에이전트가 다양한 역할(PM, Architect, Developer 등)을 전환하며 소프트웨어를 설계하는 방법론.

### 가져온 것

| 패턴 | 우리 프로젝트에서의 위치 | 설명 |
|------|----------------------|------|
| Phase별 문서 기반 컨텍스트 전달 | `docs/workflow-guide.md` 세션 분리 가이드 | LLM 컨텍스트 한계 대응. Phase A/B/C로 나누고, 이전 Phase의 **산출물만** 참조 (대화 내용 X) |
| AI 퍼실리테이터 역할 | `common/question-governance.md` AI-RECOMMEND | AI가 도메인 질문에 추천안을 제시하되, 비즈니스 정책은 절대 결정하지 않는 역할 분리 |
| Skill Validation | `tools/skill-validator.md` | 스킬 정의의 품질을 자동 검증하는 도구 |

### 가져오지 않은 것

| 항목 | 이유 |
|------|------|
| 역할별 페르소나 시스템 | 우리는 역할 전환 대신 **독립 스킬**로 분리 (architect-judge, domain-exec, reviewer 등) |
| Yolo Mode (전자동) | 우리는 Stage Gate로 인간 승인을 강제. 완전 자동 모드 미지원 |
| 마스터 프롬프트 기반 실행 | 우리는 `core-workflow.md` + 개별 스킬 조합 방식 |

---

## 3. AIDLC 워크숍 (자체 실전 경험)

5일간 3개 프로젝트에 적용한 워크숍 회고에서 도출한 패턴. 외부 방법론이 아닌 **자체 경험 기반**.

### 도출한 패턴

| 발견한 문제 | 해결책 | 위치 |
|------------|--------|------|
| AI가 저위험 질문(배치 크기)에 집중, 고위험(외부 API) 간과 | Risk-Based Priority (P0/P1/P2) | `question-governance.md` 섹션 4 |
| 인간이 유닛을 강제 지정 → 이질적 기능 묶임 | AI 주도 유닛 분해 + 응집도 검증 | `core/units-generation.md` |
| prepared_doc 정책 구멍이 인셉션 전체로 전파 | Input Validation (STEP 1-C) | `core/input-validation.md` |
| LLM 컨텍스트 한계 → 단계별 답변 불일치 | Phase별 세션 분리 | `docs/workflow-guide.md` |
| 질문이 원래 요청 범위를 넘어 확장 | Request Anchor + Scope Drift Detection | `question-governance.md` 섹션 1 |
| 낮은 확신 답변이 확정처럼 취급됨 | Confidence Tagging | `question-governance.md` 섹션 3 |

### Question Governance 전체가 자체 패턴

`question-governance.md`의 6개 섹션(Focus Anchor, Question Classification, Confidence Tagging, Risk-Based Priority, Question Budget, 포맷 통합)은 BMAD나 AI-DLC에 없던 **워크숍에서 발견한 신규 패턴**이다.

---

## 4. 업계 표준 / 개별 도구

### Aider Architect Mode

| 패턴 | 우리 프로젝트에서의 위치 |
|------|----------------------|
| Architect/Editor 역할 분리 | `/ctx-architect-judge` → `/ctx-domain-exec` 2단계 실행 |

설계 추론(architect)과 코드 작성(executor)을 분리하여, AI가 설계 판단 없이 코드만 작성하도록 강제.

### ADR (Architecture Decision Record)

| 패턴 | 우리 프로젝트에서의 위치 |
|------|----------------------|
| Michael Nygard 표준 ADR 형식 | `templates/technical-design.md` 섹션 2 |

기술 결정을 맥락/선택지/결정/영향 형식으로 기록. AWS, Microsoft도 채택한 업계 표준.

### GitHub Spec Kit

| 패턴 | 우리 프로젝트에서의 위치 |
|------|----------------------|
| Spec-first 접근 | 전체 워크플로우의 기본 철학 |

"스펙 확정 후 구현"이라는 원칙. Readiness Score 80% 이상이어야 구현 진입.

### C4 Model

| 패턴 | 우리 프로젝트에서의 위치 |
|------|----------------------|
| Component 레벨 (L3) | `templates/components.md`, `templates/services.md` |

Context(L1) → Container(L2) → Component(L3)까지만 다루고, Code(L4)는 구현 단계에 위임.

### Google Design Document

| 패턴 | 우리 프로젝트에서의 위치 |
|------|----------------------|
| Design Overview + Alternatives + Open Questions 구조 | `templates/technical-design.md` 전체 구조 |

---

## 5. 출처별 기여도 요약

```text
                         team-ai-workflow
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
    AWS AI-DLC           BMAD-METHOD         AIDLC 워크숍
    (구조/산출물)        (실행 모델)          (거버넌스)
          │                   │                   │
  ┌───────┴───────┐    ┌─────┴─────┐    ┌────────┴────────┐
  │ 25개 산출물   │    │ Phase     │    │ Question        │
  │ Adaptive Depth│    │ 분리 모델 │    │ Governance      │
  │ Extension     │    │ AI 역할   │    │ Risk Priority   │
  │ Input Valid.  │    │ 정의      │    │ Confidence Tag  │
  │ Contradiction │    │           │    │ AI 주도 유닛    │
  └───────────────┘    └───────────┘    └─────────────────┘
                              │
                   ┌──────────┼──────────┐
                   │          │          │
              Aider       ADR/C4    Google Design
              (역할분리)  (설계표준)  (문서구조)
```

## 6. 우리가 독자적으로 만든 것

외부 출처 없이 자체 설계한 부분:

| 패턴 | 설명 |
|------|------|
| CTX 기반 실행 규칙 체계 | "CTX는 설계 문서가 아니라 AI 오작동 방지용 실행 규칙 집합" |
| Stage Gate 승인 체계 (8단계) | GATE-1 ~ GATE-5 + 조건부 게이트 조합 |
| Readiness Score (정량 평가) | 6개 영역 100점 기준 + 보너스 점수 체계 |
| 스킬 파이프라인 (`/ctx-run`) | architect → implementor → test → reviewer → updater → refiner → commit planner |
| No-Implicit-Decisions 원칙 | 2개 이상 유효한 설계가 있으면 반드시 멈추고 질문 |
| Execution Boundary 원칙 | 각 스킬이 자기 책임 밖 행위를 절대 하지 않는 규칙 |
| 추정 금지 원칙 | 시간 추정을 하지 않고 S/M/L 규모만 사용 |
