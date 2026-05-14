# ctx-architect-judge 사용 방법

## 사용 방법 요약

1. `/ctx-architect-judge` 명령어로 Skill을 호출한다
2. 입력 포맷에 맞춰 작업 요구사항과 CTX 목록을 제공한다
3. Skill이 도메인 범위와 CTX 참조 범위를 판단하여 구조화된 결과를 반환한다
4. 판단 불가 시 중단 사유와 확인 질문이 반환된다

---

## 올바른 호출 예시

```
/ctx-architect-judge

## 작업 요구사항
- 사용자 등급(Grade) 조회 API에 캐싱 적용

## 제공된 Global CTX
- @ctx/back-end/api/api-design.ctx.md                                                                                                                                                                                                                                                                       
- @ctx/back-end/api/api-response.ctx.md                                                                                                                                                                                                                                                                     
- @ctx/back-end/api/error-handling.ctx.md                                                                                                                                                                                                                                                                   
- @ctx/back-end/api/swagger-global.ctx.md   

## 제공된 Local CTX
- .ctx/domains/grade/grade-domain.ctx.md
- .ctx/domains/grade/grade-api.ctx.md
```

**예상 출력:**

## 1. 영향 도메인 목록
- Grade: 사용자 등급 조회 API가 Grade 도메인에 속함

## 2. 반드시 참조해야 할 Local CTX
- .ctx/domains/grade/grade-domain.ctx.md
- .ctx/domains/grade/grade-api.ctx.md

## 3. Global CTX 영향 여부
- 영향 있음
- 캐싱 적용 시 caching-policy.ctx.md 규칙 준수 필요

## 4. 판단 불가 / 추가 확인 필요 지점
- 없음

---

## 잘못된 호출 예시 (중단되는 경우)

```
/ctx-architect-judge

## 작업 요구사항
- 성능 개선

## 제공된 Global CTX
- 전역 캐싱 정책 참조

## 제공된 Local CTX
- 등급 관련 규칙 참조
```

**예상 출력:**

## 판단 중단

중단 사유:
- 작업 요구사항이 추상적임 (어떤 기능의 성능을 개선할지 특정 불가)
- CTX가 파일 경로가 아닌 설명 텍스트로 제공됨

확인이 필요한 질문:
1. 성능 개선 대상이 되는 구체적인 API 또는 기능은 무엇인가요?
2. Global CTX 파일의 정확한 경로를 제공해 주세요
3. Local CTX 파일의 정확한 경로를 제공해 주세요
