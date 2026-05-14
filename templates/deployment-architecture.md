<!-- workflow-step: STEP-6.7 | gate: GATE-4 | producer: ctx-aidlc-run | condition: infrastructure change required -->
# Deployment Architecture

이 파일은 `aidlc-docs/features/<feature-slug>/deployment-architecture.md`에 생성하는 것을 권장한다.

선행 산출물:
- `aidlc-docs/features/<feature-slug>/infrastructure-design.md`

관련 상태 파일:
- `aidlc-docs/features/<feature-slug>/status.md`

## 작성 조건

- infrastructure-design.md가 작성된 경우 함께 작성한다.
- 단순 인프라 변경(설정값 수정 등)이면 생략할 수 있다.

---

## 1. Deployment Topology

전체 배포 구조를 기술한다. `diagram-standards.md`를 따라 다이어그램을 포함한다.

### 환경별 구성

| 환경 | 구성 | 비고 |
|------|------|------|
| dev | | |
| staging | | |
| production | | |

## 2. Component-to-Infrastructure Mapping

| 컴포넌트 | 배포 대상 | 런타임 | 스케일링 정책 |
|---------|---------|--------|-----------|
| | | | |

## 3. 외부 연동 경로

| 연동 대상 | 프로토콜 | 인증 방식 | 네트워크 경로 |
|---------|---------|---------|-----------|
| | | | |

## 4. Monitoring & Alerting

- 모니터링 도구: {CloudWatch / Datadog / Grafana / 기타}
- 핵심 메트릭: {응답시간, 에러율, 처리량 등}
- 알림 설정: {임계값 및 알림 채널}

## 5. Disaster Recovery

- 복구 목표 시간(RTO):
- 복구 목표 시점(RPO):
- 백업 전략:
- 페일오버 방식:

해당 없으면 "해당 없음"으로 표기한다.
