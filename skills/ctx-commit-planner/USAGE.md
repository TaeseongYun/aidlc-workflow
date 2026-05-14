# ctx-commit-planner 사용 예시

## 정상 호출 예시 (단일 커밋)

### 입력

```markdown
## 변경 사항 설명
- 사용자 등급 조회 API 추가
- GradeService에 등급 조회 메서드 구현
- GradeController에 엔드포인트 추가

## 변경 파일 목록
- center/back-end/src/main/java/com/nhnad/ohdasiyoung/admin/grade/GradeController.java
- center/back-end/src/main/java/com/nhnad/ohdasiyoung/admin/grade/GradeService.java
- center/back-end/src/main/java/com/nhnad/ohdasiyoung/admin/grade/dto/GradeResponse.java
```

### 출력

```markdown
## 커밋 설계 결과

### Commit 1
- title: feat: (grade) 사용자 등급 조회 기능 추가
- body:
  - 관리자가 사용자 등급을 조회할 수 있어야 함
  - 등급 조회 서비스 메서드와 컨트롤러 엔드포인트 구현
  - 등급 수정/삭제 기능은 이 커밋에 포함하지 않음
- include:
  - GradeController.java (조회 엔드포인트)
  - GradeService.java (조회 메서드)
  - GradeResponse.java (응답 DTO)
- exclude:
  - 등급 생성/수정/삭제 관련 코드
  - 테스트 코드

## 커밋 순서 설명
- 단일 커밋으로 등급 조회 기능 전체를 포함
```

---

## 정상 호출 예시 (다중 커밋)

### 입력

```markdown
## 변경 사항 설명
- 문의하기 기능 리팩토링
- 문의 유형 Enum 추가
- 문의 서비스 로직 분리
- 컨트롤러 응답 형식 변경
- 관련 테스트 코드 추가

## 변경 파일 목록
- center/back-end/src/main/java/com/nhnad/ohdasiyoung/cscenter/InquiryType.java (신규)
- center/back-end/src/main/java/com/nhnad/ohdasiyoung/cscenter/InquiryService.java
- center/back-end/src/main/java/com/nhnad/ohdasiyoung/cscenter/InquiryController.java
- center/back-end/src/test/java/com/nhnad/ohdasiyoung/cscenter/InquiryServiceTest.java (신규)
```

### 출력

```markdown
## 커밋 설계 결과

### Commit 1
- title: refactor: (cscenter) 문의 유형 열거형 추가
- body:
  - 문의 유형을 코드에서 관리해야 함
  - 문의 유형 Enum 클래스 신규 생성
  - 서비스/컨트롤러 적용은 다음 커밋에서 진행
- include:
  - InquiryType.java (신규 Enum)
- exclude:
  - InquiryService.java
  - InquiryController.java
  - 테스트 코드

### Commit 2
- title: refactor: (cscenter) 문의 서비스에 유형 Enum 적용
- body:
  - 문의 서비스가 새로운 유형 Enum을 사용해야 함
  - 기존 문자열 기반 유형 처리를 Enum으로 변경
  - 컨트롤러 변경은 다음 커밋에서 진행
- include:
  - InquiryService.java (유형 Enum 적용)
- exclude:
  - InquiryController.java
  - 테스트 코드

### Commit 3
- title: refactor: (cscenter) 문의 컨트롤러 응답 형식 개선
- body:
  - 클라이언트에 일관된 응답 형식 제공 필요
  - 컨트롤러 응답에 유형 Enum 반영
  - 테스트 코드는 다음 커밋에서 추가
- include:
  - InquiryController.java (응답 형식 변경)
- exclude:
  - 테스트 코드

### Commit 4
- title: test: (cscenter) 문의 서비스 단위 테스트 추가
- body:
  - 리팩토링된 서비스 로직 검증 필요
  - 문의 서비스 단위 테스트 신규 작성
  - 컨트롤러 테스트는 이 커밋에 포함하지 않음
- include:
  - InquiryServiceTest.java (신규 테스트)
- exclude:
  - 컨트롤러 테스트
  - 통합 테스트

## 커밋 순서 설명
- Commit 1 → 2: Enum이 먼저 존재해야 서비스에서 참조 가능
- Commit 2 → 3: 서비스 변경 후 컨트롤러가 해당 변경을 반영
- Commit 3 → 4: 기능 구현 완료 후 테스트 추가
```

---

## 잘못된 호출 예시 (중단됨)

### 입력

```markdown
## 변경 사항 설명
- 여러 가지 수정함

## 변경 파일 목록
- 여러 파일
```

### 출력

```markdown
## 커밋 설계 중단

- 중단 사유: 변경 사항이 불충분함
- 문제 지점:
  - 변경 사항 설명이 "여러 가지 수정함"으로 모호함
  - 변경 파일 목록이 "여러 파일"로 구체적이지 않음
  - 커밋 단위 분리를 위한 정보가 없음
```

---

## 중단 예시 (include/exclude 경계 불명확)

### 입력

```markdown
## 변경 사항 설명
- UserService와 UserController 전체 리팩토링
- 메서드 이름 변경, 로직 분리, 응답 형식 변경이 혼재

## 변경 파일 목록
- UserService.java
- UserController.java
```

### 출력

```markdown
## 커밋 설계 중단

- 중단 사유: include/exclude 경계를 명확히 나눌 수 없음
- 문제 지점:
  - 메서드 이름 변경, 로직 분리, 응답 형식 변경이 동일 파일에 혼재
  - 각 변경 유형을 분리하여 커밋하려면 변경 사항을 더 세분화해야 함
  - 현재 정보로는 의미 단위 분리가 불가능
```
