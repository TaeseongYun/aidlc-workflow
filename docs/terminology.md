# Terminology

이 프로젝트에서 사용하는 핵심 용어 정의다.

## 요청 분류

| 용어 | 정의 |
|------|------|
| `raw-request` | 마케팅/운영/현업 원문 수준의 요청. 목표는 있으나 범위, 정책, 성공 기준이 정리되지 않은 상태. `request-intake.md`와 `planning-draft.md`를 먼저 작성한다. |
| `prepared-requirement` | 이미 구조화된 요구사항. `requirements.md` 중심으로 바로 진행한다. |
| `change-on-existing-feature` | 기존 feature에 대한 추가 변경 또는 후속 요구사항. 새 폴더보다 기존 feature 폴더 갱신을 우선 검토한다. |

## 프로젝트 유형

| 용어 | 정의 |
|------|------|
| `greenfield` | 완전 신규 프로젝트. 기존 코드/DB/API/운영 흐름이 없다. 요구사항과 도메인 정의부터 시작한다. |
| `brownfield` | 기존 프로젝트. 기존 코드/DB/API/운영/배포 제약을 읽어야 한다. 새 기능도 기존 구조에 맞춰 들어간다. |

## 질문/승인 상태

| 용어 | 정의 |
|------|------|
| `BLOCK` | 답 없이는 구현 진행 불가. high impact 질문의 기본값. |
| `ASSUME-{X}` | 가정으로 진행 가능. medium/low impact 질문에서 사용. `{X}`는 선택된 가정 옵션. 가정 근거를 반드시 명시한다. |
| `OPEN` | 질문이 아직 답변되지 않은 상태. |
| `ANSWERED` | 질문에 답변이 완료된 상태. |
| `implementation-ready` | BLOCK 질문이 0개이고 요구사항이 확정된 상태. 구현 진행 가능. |

## 산출물/구조

| 용어 | 정의 |
|------|------|
| `CTX` (Context) | 프로젝트 로컬 사실을 담는 `ctx/` 디렉토리. 기존 구조, 금지 규칙, 재사용 컴포넌트 등을 정의한다. |
| `aidlc-docs` | 기능 작업 산출물 디렉토리. 요구사항, 질문, unit-of-work, 상태 추적 문서를 보관한다. |
| `feature-slug` | 기능별 산출물 폴더명. lowercase kebab-case를 사용한다. 예: `coupon-feature`, `b2b-approval-flow` |
| `UOW` (Unit of Work) | 독립적으로 검증 가능한 작업 단위. 도메인 책임, 배포 단위, 실패 영향 등으로 분해한다. |
| `ADR` (Architecture Decision Record) | 기술 결정 기록. 맥락/선택지/결정/영향을 구조적으로 남긴다. |

## 승인 게이트

| 용어 | 정의 |
|------|------|
| `GATE-1` | planning-draft 리뷰. `raw-request`일 때만 발동. |
| `GATE-2` | requirements + questions 리뷰. 항상 발동. |
| `GATE-3` | unit-of-work 리뷰. 항상 발동. |
| `GATE-3.5` | technical-design 리뷰. M/L 규모 단위가 있을 때만 발동. |

## Readiness Score

| 용어 | 정의 |
|------|------|
| `READY` (80+) | 구현 가능 상태. |
| `CONDITIONAL` (60-79) | ASSUME 조건부 진행 가능. 재작업 위험 있음. |
| `NOT_READY` (60 미만) | 구현 불가. 질문 해결 필요. |

## 규모

| 용어 | 정의 |
|------|------|
| `S` | 단일 파일/함수 수준 변경. 반나절 이내. |
| `M` | 여러 파일 변경, 테스트 포함. 1~2일. |
| `L` | 모듈 단위 변경, 외부 연동/마이그레이션 포함. 3일 이상. |
