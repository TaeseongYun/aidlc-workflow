# ctx-reviewer 사용 방법

## 사용 방법 요약

1. `/ctx-reviewer` 명령어로 Skill을 호출한다
2. 참조된 CTX 목록과 리뷰 대상 코드를 제공한다
3. Executor 실행 모드를 명시한다
4. Skill이 CTX 위반 여부와 규칙 반복성을 판단하여 결과를 반환한다

---

## 정상 리뷰 호출 예시 (ARCHITECT_CONFIRMED)

```
/ctx-reviewer

## 참조된 Global CTX
- ctx/back-end/api/api-response.ctx.md
- ctx/back-end/api/error-handling.ctx.md

## 참조된 Local CTX
- ctx/back-end/domain/notification.ctx.md

## 리뷰 대상 코드
```java
@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;

    @Transactional
    public void markAsRead(Long notificationId) {
        Notification notification = notificationRepository.findById(notificationId)
            .orElseThrow(() -> new NotFoundException("알림을 찾을 수 없습니다."));
        notification.markAsRead();
    }

    @Transactional(readOnly = true)
    public List<NotificationDto> findByUserId(Long userId) {
        return notificationRepository.findByUserIdOrderByCreatedAtDesc(userId)
            .stream()
            .map(NotificationDto::from)
            .toList();
    }
}
```

## Executor 실행 모드
- ARCHITECT_CONFIRMED
```

**예상 출력:**

## 1. CTX 위반 여부 판단
- 위반 없음

## 2. 식별된 규칙 목록
- 규칙 A: 알림 조회 시 생성일 기준 내림차순 정렬

## 3. CTX 반영 분류 결과
- 규칙 A → Local CTX

## 4. CTX 반영 제안
- 대상 파일: ctx/back-end/domain/notification.ctx.md
- 삽입 위치: 조회 규칙 섹션
- 추가 문장: "알림 목록 조회 시 생성일(createdAt) 기준 내림차순으로 정렬한다."
- 누락 시 AI 오작동: AI가 정렬 없이 조회하거나 오름차순으로 정렬하여 최신 알림이 하단에 표시됨

---

## EXECUTOR_ONLY 리뷰 호출 예시

```
/ctx-reviewer

## 참조된 Global CTX
- ctx/back-end/api/api-design.ctx.md
- ctx/back-end/api/api-response.ctx.md
- ctx/back-end/api/error-handling.ctx.md

## 참조된 Local CTX
- ctx/back-end/domain/grade.ctx.md

## 리뷰 대상 코드
```java
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/grades")
public class GradeController {

    private final GradeService gradeService;

    @GetMapping("/{userId}")
    public ResponseEntity<GradeDto> getGrade(@PathVariable Long userId) {
        Grade grade = gradeService.findByUserId(userId);
        return ResponseEntity.ok(GradeDto.from(grade));
    }
}
```

## Executor 실행 모드
- EXECUTOR_ONLY
```

**예상 출력:**

## 1. CTX 위반 여부 판단
- 위반 있음
- 위반된 규칙: "모든 API 응답은 CommonResponse로 감싸서 반환한다."
- 위반 발생 코드: `return ResponseEntity.ok(GradeDto.from(grade));`

## 2. 식별된 규칙 목록
- 없음

## 3. CTX 반영 분류 결과
- 해당 없음

## 4. CTX 반영 제안
- 없음

## EXECUTOR_ONLY 주의 표시
- 본 리뷰 대상 코드는 Architect 사전 판단 없이 실행되었음
- Global CTX 준수 여부는 검증 대상에 포함됨

---

## 잘못된 호출 예시 (중단되는 경우)

```
/ctx-reviewer

## 참조된 Global CTX
- API 응답 규칙 참조

## 참조된 Local CTX
- 등급 관련 CTX

## 리뷰 대상 코드
```java
// 일부 코드만 발췌
gradeService.findByUserId(userId);
```

## Executor 실행 모드
- (미명시)
```

**예상 출력:**

## 리뷰 중단

중단 사유:
- 참조된 CTX 목록이 파일 경로가 아닌 설명 텍스트로 제공됨
- 리뷰 대상 코드가 일부만 제공됨 (전체 맥락 파악 불가)
- Executor 실행 모드가 명시되지 않음

확인이 필요한 사항:
1. Global CTX 파일의 정확한 경로를 제공해 주세요 (예: ctx/back-end/api/api-response.ctx.md)
2. Local CTX 파일의 정확한 경로를 제공해 주세요
3. 리뷰 대상 코드의 전체 클래스/메서드를 제공해 주세요
4. Executor 실행 모드를 명시해 주세요 (ARCHITECT_CONFIRMED 또는 EXECUTOR_ONLY)
