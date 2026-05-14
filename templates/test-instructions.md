<!-- workflow-step: STEP-9 | gate: GATE-5 | producer: ctx-aidlc-run | condition: M/L units exist -->
# Test Instructions

이 파일은 `aidlc-docs/features/<feature-slug>/test-instructions.md`에 생성하는 것을 권장한다.

선행 산출물:
- `aidlc-docs/features/<feature-slug>/unit-of-work.md`
- `aidlc-docs/features/<feature-slug>/technical-design.md`
- `aidlc-docs/features/<feature-slug>/build-instructions.md`

관련 상태 파일:
- `aidlc-docs/features/<feature-slug>/status.md`

## 작성 조건

- build-instructions.md가 작성된 경우 함께 작성한다.
- technical-design.md의 Testing Approach 섹션을 구체화한 문서이다.

---

## 1. Test Strategy Overview

- 테스트 프레임워크: {JUnit / pytest / Jest / 기타}
- 커버리지 목표: {라인 커버리지 % 또는 "프로젝트 기준 따름"}
- 테스트 전략: {ctx/project-profile.ctx.md의 test-strategy 따름: TDD / Test-after}

## 2. Unit Tests

| 대상 UOW | 테스트 대상 | 테스트 시나리오 | 기대 결과 |
|---------|-----------|-------------|---------|
| UOW-{N} | | | |
| UOW-{M} | | | |

## 3. Integration Tests

| 테스트 시나리오 | 관련 UOW | 사전 조건 | 실행 순서 | 기대 결과 |
|--------------|---------|---------|---------|---------|
| | | | | |

## 4. Edge Case / Exception Tests

| 시나리오 | 입력 조건 | 기대 동작 | 관련 요구사항 |
|---------|---------|---------|-----------|
| | | | |

## 5. Performance Tests

해당 없으면 "해당 없음"으로 표기한다.

- 대상: {API 엔드포인트 / 배치 처리 / 기타}
- 목표: {응답시간, 처리량}
- 도구: {k6 / JMeter / 기타}

## 6. Test Execution

```bash
# 단위 테스트 실행
{command}

# 통합 테스트 실행
{command}

# 전체 테스트 실행
{command}
```

## 7. Quality Gate

- 테스트 통과 기준: {전체 통과 / 커버리지 N% 이상}
- 실패 시 조치: {빌드 중단 / 리뷰 후 판단}

## 8. Runtime Verification

빌드·테스트 통과 이후 서비스가 실제로 동작하는지 확인한다.
M/L 규모 단위가 포함된 경우 아래 루틴을 완료해야 GATE-5를 통과할 수 있다.
전체 S 규모이거나 배치/CLI처럼 서버 기동이 없는 경우 "해당 없음"으로 표기한다.

### 기동 명령

```bash
{서버/프로세스 실행 명령}
```

### 헬스 체크

```bash
{헬스 체크 명령 — 예: curl -s http://localhost:{port}/health}
```

### 대표 유스케이스 검증

| # | 설명 | 실행 명령 | 기대 응답 |
|---|------|---------|---------|
| 1 | {핵심 성공 케이스} | `{curl 또는 CLI 명령}` | {기대 결과 요약} |
| 2 | {핵심 차단/예외 케이스} | `{명령}` | {기대 오류 응답} |

### 실행 로그 확인

```bash
{로그 확인 명령}
```

### 환경 제약 (해당 시)

sandbox, 포트 바인딩, 네트워크 등 실행 환경 제약이 있으면 기록한다.
없으면 "없음"으로 표기한다.
