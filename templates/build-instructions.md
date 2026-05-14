<!-- workflow-step: STEP-9 | gate: GATE-5 | producer: ctx-aidlc-run | condition: M/L units exist -->
# Build Instructions

이 파일은 `aidlc-docs/features/<feature-slug>/build-instructions.md`에 생성하는 것을 권장한다.

선행 산출물:
- `aidlc-docs/features/<feature-slug>/unit-of-work.md`
- `aidlc-docs/features/<feature-slug>/technical-design.md`

관련 상태 파일:
- `aidlc-docs/features/<feature-slug>/status.md`

## 작성 조건

- M/L 규모 단위가 1개 이상 있을 때 작성한다.
- 전체가 S 규모이면 생략할 수 있다.
- 생략 시 status.md에 "빌드/테스트 가이드 생략 — 전체 S 규모"로 기록한다.

---

## 1. Prerequisites

- 런타임 환경: {언어 버전, 프레임워크 버전}
- 필수 도구: {빌드 도구, CLI 도구}
- 환경 변수:

| 변수명 | 용도 | 예시 값 |
|--------|------|--------|
| | | |

## 2. Build Steps

```bash
# 1. 의존성 설치
{command}

# 2. 빌드
{command}

# 3. 로컬 실행
{command}
```

## 3. UOW별 빌드 순서

| 순서 | UOW | 빌드 명령 | 의존 조건 |
|------|-----|---------|---------|
| 1 | UOW-{N} | | 없음 |
| 2 | UOW-{M} | | UOW-{N} 완료 |

## 4. 배포 절차

- 배포 대상: {환경}
- 배포 명령:

```bash
{command}
```

- 배포 후 검증: {헬스체크 URL, smoke test 등}

## 5. Rollback

- 롤백 절차:
- 롤백 판단 기준: {에러율 임계값, 모니터링 메트릭}
