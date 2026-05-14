<!-- workflow-step: STEP-6.7 | gate: GATE-4 | producer: ctx-aidlc-run | condition: infrastructure change required -->
# Infrastructure Design

이 파일은 `aidlc-docs/features/<feature-slug>/infrastructure-design.md`에 생성하는 것을 권장한다.

선행 산출물:
- `aidlc-docs/features/<feature-slug>/requirements.md`
- `aidlc-docs/features/<feature-slug>/unit-of-work.md`
- `aidlc-docs/features/<feature-slug>/technical-design.md`

관련 상태 파일:
- `aidlc-docs/features/<feature-slug>/status.md`

## 작성 조건

- 신규 인프라 리소스 생성, 기존 인프라 구성 변경, 또는 배포 토폴로지 변경이 필요할 때 작성한다.
- 기존 인프라에 코드만 배포하는 경우 생략할 수 있다.
- 생략 시 status.md에 "인프라 설계 생략 — 기존 인프라 변경 없음"으로 기록한다.

---

## 1. Infrastructure Overview

이 기능에 필요한 인프라 변경 요약. 2~5문장으로 기술한다.

- 변경 유형: 신규 리소스 / 기존 리소스 변경 / 구성 변경
- 대상 환경: dev / staging / production
- IaC 도구: Terraform / CDK / CloudFormation / 수동 / 기타

## 2. Resource Inventory

### 신규 리소스

| 리소스 | 서비스 | 용도 | 예상 사양 | 대상 UOW |
|--------|--------|------|---------|---------|
| | | | | |

### 변경 리소스

| 리소스 | 현재 상태 | 변경 내용 | 영향 범위 | 대상 UOW |
|--------|---------|---------|---------|---------|
| | | | | |

## 3. Network & Security

- VPC/Subnet 변경: 있음 / 없음
- 보안 그룹 변경: {변경 내용 또는 "없음"}
- IAM 역할/정책 변경: {변경 내용 또는 "없음"}
- 인증서/암호화: {변경 내용 또는 "없음"}

## 4. CI/CD Pipeline

- 빌드 파이프라인 변경: {변경 내용 또는 "기존 유지"}
- 배포 전략: Rolling / Blue-Green / Canary / 기존 유지
- 환경별 배포 순서: {dev -> staging -> production 등}

## 5. Cost Estimate

| 리소스 | 월 예상 비용 | 산출 근거 |
|--------|-----------|---------|
| | | |
| **합계** | | |

비용은 개략 추정이며, 실제 비용은 사용량에 따라 달라진다.

## 6. Migration Plan

DB 마이그레이션, 데이터 이전, 또는 서비스 전환이 필요한 경우 기술한다.
없으면 "해당 없음"으로 표기한다.

- 마이그레이션 전략:
- 롤백 계획:
- 다운타임 예상:
