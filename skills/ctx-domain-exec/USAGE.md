# ctx-domain-exec 사용 방법

## 사용 방법 요약

### 실행 모드별 선택 기준

| 모드 | 사용 시점 | Global CTX | Local CTX |
|------|----------|------------|-----------|
| ARCHITECT_CONFIRMED | Architect 판단 결과가 있을 때 | 판단 결과에 따름 | 판단 결과에 따름 |
| EXECUTOR_ONLY | Architect 판단 생략 시 | 강제 참조 | 사용자 명시 |

### 워크플로우

1. **권장**: `/ctx-architect-judge`로 먼저 판단 수행
2. 판단 결과를 `/ctx-domain-exec`에 전달하여 구현
3. **예외적**: 단일 도메인이 확실한 경우에만 EXECUTOR_ONLY 사용

---

## ARCHITECT_CONFIRMED 호출 예시

```
/ctx-domain-exec

## 실행 모드
- ARCHITECT_CONFIRMED

## Architect 판단 결과

### 1. 영향 도메인 목록
- Grade: 사용자 등급 조회 기능이 Grade 도메인에 속함

### 2. 반드시 참조해야 할 Local CTX
- ctx/back-end/domain/grade.ctx.md

### 3. Global CTX 영향 여부
- 영향 있음
- ctx/back-end/api/api-response.ctx.md 응답 형식 준수 필요

### 4. 판단 불가 / 추가 확인 필요 지점
- 없음

## 작업 요구사항
- GradeService에 사용자 ID로 등급 조회하는 메서드 추가
- 등급이 없으면 기본 등급(BRONZE) 반환
```

**예상 출력:**

## 실행 모드 선언
- ARCHITECT_CONFIRMED

## 구현 요약
- 참조한 Global CTX: ctx/back-end/api/api-response.ctx.md
- 참조한 Local CTX: ctx/back-end/domain/grade.ctx.md

## 구현 내용

```java
@Service
@RequiredArgsConstructor
public class GradeService {

    private final GradeRepository gradeRepository;

    public Grade findByUserId(Long userId) {
        return gradeRepository.findByUserId(userId)
            .orElse(Grade.defaultBronze(userId));
    }
}
```

## CTX 준수 확인
위 구현은 입력으로 제공된 CTX 범위를 벗어나지 않음을 확인함.

---

## EXECUTOR_ONLY 호출 예시

```
/ctx-domain-exec

## 실행 모드
- EXECUTOR_ONLY

## 작업 요구사항
- NotificationService에 알림 읽음 처리 메서드 추가
- 알림 ID로 조회하여 readAt 필드를 현재 시각으로 업데이트

## 사용자 보증 선언 (필수)
- 이 작업은 단일 도메인 범위임을 보증한다
- 참조할 Local CTX를 직접 명시한다

## Global CTX (강제 참조)
- ctx/back-end/api/api-design.ctx.md
- ctx/back-end/api/api-response.ctx.md
- ctx/back-end/api/error-handling.ctx.md

## Local CTX (선택 참조)
- ctx/back-end/domain/notification.ctx.md
```

**예상 출력:**

## 실행 모드 선언
- EXECUTOR_ONLY

## 구현 요약
- 참조한 Global CTX: ctx/back-end/api/api-design.ctx.md, ctx/back-end/api/api-response.ctx.md, ctx/back-end/api/error-handling.ctx.md
- 참조한 Local CTX: ctx/back-end/domain/notification.ctx.md

## 구현 내용

```java
@Transactional
public void markAsRead(Long notificationId) {
    Notification notification = notificationRepository.findById(notificationId)
        .orElseThrow(() -> new NotFoundException("알림을 찾을 수 없습니다."));
    notification.markAsRead();
}
```

## CTX 준수 확인
위 구현은 입력으로 제공된 CTX 범위를 벗어나지 않음을 확인함.

## 판단 생략 고지
- Architect 판단은 생략되었음
- Global CTX는 모두 참조 및 준수되었음
- Local CTX 적합성은 사용자 선언에 의존함

---

## 잘못된 호출 예시 (중단되는 경우)

### 예시 1: EXECUTOR_ONLY에서 Global CTX 섹션 누락

```
/ctx-domain-exec

## 실행 모드
- EXECUTOR_ONLY

## 작업 요구사항
- 결제 취소 기능 구현

## 사용자 보증 선언 (필수)
- 이 작업은 단일 도메인 범위임을 보증한다
- 참조할 Local CTX를 직접 명시한다

## Local CTX (선택 참조)
- ctx/back-end/domain/kcp-payment.ctx.md
```

**예상 출력:**

## 실행 중단

중단 사유:
- EXECUTOR_ONLY 모드에서 Global CTX 섹션이 누락됨
- Global CTX는 항상 참조되어야 하며 생략 불가

확인이 필요한 질문:
1. Global CTX (강제 참조) 섹션을 추가하여 다시 요청해 주세요
2. 프로젝트의 Global CTX 목록을 포함해 주세요

---

### 예시 2: ARCHITECT_CONFIRMED에서 판단 불가 지점 존재

```
/ctx-domain-exec

## 실행 모드
- ARCHITECT_CONFIRMED

## Architect 판단 결과

### 1. 영향 도메인 목록
- Settlement: 정산 처리 기능
- Payment: 결제 연동 기능

### 2. 반드시 참조해야 할 Local CTX
- ctx/back-end/domain/settlement.ctx.md
- ctx/back-end/domain/kcp-payment.ctx.md

### 3. Global CTX 영향 여부
- 영향 있음

### 4. 판단 불가 / 추가 확인 필요 지점
- Settlement과 Payment 도메인 간 트랜잭션 경계가 불명확함
- 정산 실패 시 결제 롤백 정책이 CTX에 명시되지 않음

## 작업 요구사항
- 정산 완료 시 결제 상태 변경
```

**예상 출력:**

## 실행 중단

중단 사유:
- Architect 판단 결과에 "판단 불가 / 추가 확인 필요 지점"이 존재함
- 미해결 지점:
  1. Settlement과 Payment 도메인 간 트랜잭션 경계가 불명확함
  2. 정산 실패 시 결제 롤백 정책이 CTX에 명시되지 않음

확인이 필요한 질문:
1. 두 도메인 간 트랜잭션 경계를 명확히 정의해 주세요
2. 정산 실패 시 결제 롤백 정책을 결정하여 CTX에 추가해 주세요
3. 위 사항이 해결된 후 Architect 판단을 다시 수행해 주세요

---

### 예시 3: 다중 도메인 가능성 감지 (EXECUTOR_ONLY)

```
/ctx-domain-exec

## 실행 모드
- EXECUTOR_ONLY

## 작업 요구사항
- 프렌즈가 프로그램을 등록하면 알림 발송

## 사용자 보증 선언 (필수)
- 이 작업은 단일 도메인 범위임을 보증한다
- 참조할 Local CTX를 직접 명시한다

## Global CTX (강제 참조)
- ctx/back-end/api/api-design.ctx.md
- ctx/back-end/api/api-response.ctx.md
- ctx/back-end/api/error-handling.ctx.md

## Local CTX (선택 참조)
- ctx/back-end/domain/friends.ctx.md
```

**예상 출력:**

## 실행 중단

중단 사유:
- EXECUTOR_ONLY 모드에서 다중 도메인 가능성이 감지됨
- 요구사항 "프렌즈가 프로그램을 등록하면 알림 발송"은 다음 도메인에 영향을 미침:
  1. Friends 도메인 (프렌즈)
  2. Program 도메인 (프로그램 등록)
  3. Notification 도메인 (알림 발송)
- 단일 도메인 보증이 실제 요구사항과 일치하지 않음

확인이 필요한 질문:
1. `/ctx-architect-judge`를 사용하여 도메인 범위를 먼저 판단해 주세요
2. 또는 요구사항을 단일 도메인 범위로 분리하여 다시 요청해 주세요
