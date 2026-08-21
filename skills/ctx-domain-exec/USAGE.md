# How to Use ctx-domain-exec

## Usage Summary

### Selection Criteria by Execution Mode

| Mode | When to Use | Global CTX | Local CTX |
|------|----------|------------|-----------|
| ARCHITECT_CONFIRMED | When Architect judgment results exist | Per the judgment result | Per the judgment result |
| EXECUTOR_ONLY | When Architect judgment is omitted | Forced reference | User-specified |

### Workflow

1. **Recommended**: Perform judgment first with `/ctx-architect-judge`
2. Pass the judgment result to `/ctx-domain-exec` for implementation
3. **Exceptional**: Use EXECUTOR_ONLY only when a single domain is certain

---

## ARCHITECT_CONFIRMED Invocation Example

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

**Expected output:**

## Execution Mode Declaration
- ARCHITECT_CONFIRMED

## Implementation Summary
- Referenced Global CTX: ctx/back-end/api/api-response.ctx.md
- Referenced Local CTX: ctx/back-end/domain/grade.ctx.md

## Implementation Content

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

## CTX Compliance Confirmation
Confirmed that the implementation above does not go beyond the CTX scope provided as input.

---

## EXECUTOR_ONLY Invocation Example

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

**Expected output:**

## Execution Mode Declaration
- EXECUTOR_ONLY

## Implementation Summary
- Referenced Global CTX: ctx/back-end/api/api-design.ctx.md, ctx/back-end/api/api-response.ctx.md, ctx/back-end/api/error-handling.ctx.md
- Referenced Local CTX: ctx/back-end/domain/notification.ctx.md

## Implementation Content

```java
@Transactional
public void markAsRead(Long notificationId) {
    Notification notification = notificationRepository.findById(notificationId)
        .orElseThrow(() -> new NotFoundException("알림을 찾을 수 없습니다."));
    notification.markAsRead();
}
```

## CTX Compliance Confirmation
Confirmed that the implementation above does not go beyond the CTX scope provided as input.

## Judgment-Omitted Notice
- Architect judgment was omitted
- All Global CTX was referenced and complied with
- Local CTX suitability depends on the user's declaration

---

## Incorrect Invocation Examples (cases that stop)

### Example 1: Global CTX section missing in EXECUTOR_ONLY

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

**Expected output:**

## Execution Stopped

Stop reason:
- The Global CTX section is missing in EXECUTOR_ONLY mode
- Global CTX must always be referenced and cannot be omitted

Questions that need confirmation:
1. Please add the Global CTX (forced reference) section and request again
2. Please include the project's Global CTX list

---

### Example 2: Points that cannot be judged exist in ARCHITECT_CONFIRMED

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

**Expected output:**

## Execution Stopped

Stop reason:
- The Architect judgment result contains "Points that cannot be judged / require additional confirmation"
- Unresolved points:
  1. The transaction boundary between the Settlement and Payment domains is unclear
  2. The payment rollback policy on settlement failure is not specified in the CTX

Questions that need confirmation:
1. Please clearly define the transaction boundary between the two domains
2. Please decide the payment rollback policy on settlement failure and add it to the CTX
3. After the above items are resolved, please perform the Architect judgment again

---

### Example 3: Possibility of multiple domains detected (EXECUTOR_ONLY)

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

**Expected output:**

## Execution Stopped

Stop reason:
- A possibility of multiple domains was detected in EXECUTOR_ONLY mode
- The requirement "send a notification when a friend registers a program" affects the following domains:
  1. Friends domain (friends)
  2. Program domain (program registration)
  3. Notification domain (notification sending)
- The single-domain guarantee does not match the actual requirement

Questions that need confirmation:
1. Please use `/ctx-architect-judge` to judge the domain scope first
2. Or split the requirement into a single-domain scope and request again
