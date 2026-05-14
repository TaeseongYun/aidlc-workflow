# API Contract

API 계약 5개 항목의 전체 규칙이다.
이 파일은 사용자가 opt-in한 경우에만 로드한다.

## 적용 규칙

- opt-in 시 모든 항목은 **blocking constraint**로 취급한다.
- FAIL 항목은 해당 UOW에서 반드시 해소해야 한다.
- 산출물은 `aidlc-docs/features/<feature-slug>/extensions/api-contract.md`에 생성한다.

---

## API-01. API 버전 관리 전략

**평가 기준**:
- PASS: 버전 관리 전략이 명시되어 있다 (URL path, header, query param 중 택일). 신규/변경 API의 버전이 정의되어 있다.
- FAIL: 버전 관리 전략 미정의, 기존 API와 버전 충돌 가능성 있음.
- N/A: 내부 전용 API로 버전 관리 불필요.

**일반적 조치**: URL path 버전(`/v1/`, `/v2/`) 권장, 버전 업 기준 정의 (breaking change 시).
**Brownfield 고려**: 기존 버전 체계와 일관성, 클라이언트 마이그레이션 계획.

## API-02. 요청/응답 스키마 정의

**평가 기준**:
- PASS: 모든 API의 요청/응답 스키마가 명시적으로 정의되어 있다. 필수/선택 필드, 데이터 타입, 제약 조건이 포함되어 있다.
- FAIL: 스키마 미정의, 필드 타입 불명확, 제약 조건 누락.
- N/A: 스키마 없는 이벤트 기반 통신.

**일반적 조치**: OpenAPI/Swagger 명세 작성, DTO 클래스 기반 자동 문서 생성, JSON Schema 검증.
**Brownfield 고려**: 기존 API 스키마와의 일관성, 필드 네이밍 컨벤션 준수.

## API-03. 에러 응답 표준

**평가 기준**:
- PASS: 에러 응답 형식이 일관된다 (error code, message, detail). HTTP 상태 코드가 의미에 맞게 사용된다. 비즈니스 에러 코드가 정의되어 있다.
- FAIL: 에러 형식 불일치, 상태 코드 오용 (모든 에러에 500), 에러 코드 미정의.
- N/A: 에러 발생이 없는 조회 전용 API.

**일반적 조치**: 표준 에러 응답 포맷 정의, 비즈니스 에러 코드 테이블, 내부 정보 노출 방지.
**Brownfield 고려**: 기존 에러 포맷과 일관성, 클라이언트 에러 핸들링 영향.

## API-04. 하위 호환성

**평가 기준**:
- PASS: 기존 API 변경 시 하위 호환성이 검토되었다. Breaking change가 있으면 마이그레이션 계획이 수립되어 있다. Deprecation 정책이 명시되어 있다.
- FAIL: 하위 호환성 미검토, breaking change 무계획 적용, 기존 클라이언트 영향 미분석.
- N/A: 신규 API만 추가 (기존 변경 없음).

**일반적 조치**: 필드 추가는 허용, 필드 삭제/변경은 버전 업, deprecation 기간(최소 2주) 공지.
**Brownfield 고려**: 기존 클라이언트 목록 파악, 영향 범위 분석, 점진적 마이그레이션.

## API-05. API 문서화

**평가 기준**:
- PASS: OpenAPI/Swagger 또는 동등한 문서가 작성되어 있다. 예제 요청/응답이 포함되어 있다. 인증/인가 요구사항이 명시되어 있다.
- FAIL: 문서 미작성, 예제 미포함, 인증 요구사항 누락.
- N/A: 내부 이벤트 기반 통신으로 API 문서 불필요.

**일반적 조치**: 코드 기반 OpenAPI 자동 생성, Swagger UI 제공, API 변경 시 문서 동기화 검증.
**Brownfield 고려**: 기존 문서 도구와 통합, 미문서화 API 식별.

---

## 산출물 포맷

```markdown
# API Contract

> **Request Anchor**: {최초 요청 요약}

## API Contract Checklist

| ID | 항목 | 상태 | 비고 |
|----|------|------|------|
| API-01 | 버전 관리 전략 | PASS / FAIL / N/A | |
| API-02 | 요청/응답 스키마 | PASS / FAIL / N/A | |
| API-03 | 에러 응답 표준 | PASS / FAIL / N/A | |
| API-04 | 하위 호환성 | PASS / FAIL / N/A | |
| API-05 | API 문서화 | PASS / FAIL / N/A | |

## Findings

### API-{NN}. {항목명}
- 상태: PASS / FAIL / N/A
- 현재 상태: {현재 적용 현황}
- 조치 필요: {필요한 조치 또는 "없음"}
- 관련 UOW: UOW-{N} / 해당 없음

## Summary
- 전체 항목: 5
- PASS: {N}
- FAIL: {N}
- N/A: {N}
- FAIL 항목이 있으면 해당 UOW의 구현에서 반드시 해소해야 한다.
```
