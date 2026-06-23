# Score Loop Guide — 의존성 인지 점수 루프

`/ctx-score-loop`은 구현 **이후** 의존성과 4축 검증을 자동 반복 채점하여, **85점을 초과(`> 85`)했을 때에만** 완료로 판정하는 루프 엔지니어링 기능이다. "코드 구현 단 한 번의 요청"으로 사용자 추가 개입 없이 자율 반복한다.

> 핵심: 매 라운드 "검증해줘"를 반복 요청할 필요가 없다. 한 번 시작하면 85점 초과까지(또는 정체/상한까지) 알아서 돈다.

---

## 1. 언제 쓰나

- GATE-3(구현 승인)를 통과한 피처를 구현하면서, 의존성·빌드·테스트·AC를 객관 점수로 자동 완료 판정하고 싶을 때.
- 여러 종류의 의존성(기능 선후 / 빌드·라이브러리 / 모듈 간)이 얽혀 있어 "어디가 막혔는지" 추적이 필요할 때.

readiness-score(구현 **전** 준비도)와 혼동하지 말 것. 이 루프는 구현 **후** 산출물 점수다.

---

## 2. 4축 점수 (각 25점 · 총 100점)

| 축 | 의미 | 채점 근거 |
|----|------|----------|
| 의존성 해결 | 3종 의존성이 모두 충족되었는가 | `dependency-check.md` 체크리스트 |
| 빌드/컴파일 | 실제로 빌드되고 컴파일 에러가 없는가 | **빌드 명령 실행 결과** (미실행 0점) |
| 테스트/커버리지 | 테스트가 통과하고 커버리지가 기준 이상인가 | **테스트 명령 실행 결과** (미실행 0점) |
| 요구사항/AC 충족 | 의도한 Acceptance Criteria가 충족되는가 | UOW 수용기준 + requirements FR |

상세 기준: `core/dependency-score.md` / 스키마: `core/dependency-score.schema.yaml`

### 게이팅 (거짓 완료 방지)
- **빌드 축이 0점이면 85점을 넘겨도 완료가 아니다** (GR-1).
- BLOCK 미해결 의존성이 1건이라도 있으면 의존성 축은 최대 12점 (GR-2).
- 빌드·테스트 축은 **추정 채점 금지** — 명령을 실제로 실행한 증빙만 인정.

---

## 3. 의존성 검증 md 만들기

의존성이 필요한 **각 피처/모듈 디렉토리 안**에 `dependency-check.md`를 둔다(분산 배치). 템플릿: `templates/dependency-check.md`.

3종 의존성을 체크리스트로 분류한다:
1. **기능 간 선후관계** — 예: "로그인 feature가 completed여야 함"
2. **빌드/라이브러리** — 예: "retrofit, hilt 버전 설정 + 빌드 통과"
3. **모듈 간** — 예: "feature-A가 core-network API X를 호출/구현"

루프는 이 파일을 자동 생성/갱신하되, **사람이 작성한 항목(`<!-- src: human -->`)은 보존**한다.

---

## 4. 실행

```text
/ctx-score-loop <feature-slug>
```

선택 인자:
- `engine=ralph|evolve|native` (기본 ralph)
- `max_rounds=N`, `max_minutes=M` (기본 10 / 30 — `dependency-check.md`의 Loop Config로도 오버라이드)

### 한 라운드 흐름
```
의존성 md 동기화 → 빌드·테스트 실제 실행 → 4축 채점(근거 필수)
  → verdict 판정 → Score History 기록 + 보고
```

### 종료/중단 조건

| verdict | 조건 | 동작 |
|---------|------|------|
| COMPLETE | total > 85 AND 빌드축 ≠ 0 | "완료(85 초과)" 보고 후 **종료** |
| CONTINUE | 위 미달, 정체/상한/회귀 아님 | 부족 축 보완 후 다음 라운드 |
| STALLED | 2회 연속 점수 미개선 | **즉시 중단**, 막힌 축·사유 보고 |
| EXHAUSTED | 10회 또는 30분 도달 | **즉시 중단**, 사유 보고 |
| REGRESSED | 직전 대비 점수 하락 | **즉시 중단**, 경고 보고 (v1 자동 롤백 없음) |

중단 시 루프는 **자동 재시작하지 않고** 사람 결정을 기다린다.

---

## 5. 예시

### 완료까지 (S1)
```
[ctx-score-loop] coupon-feature — round 1
  의존성 18/25 · 빌드 25/25 · 테스트 12/25 · AC 20/25 = 75/100  (CONTINUE)
[ctx-score-loop] coupon-feature — round 2
  의존성 25/25 · 빌드 25/25 · 테스트 22/25 · AC 23/25 = 95/100  (COMPLETE)
  → 완료(85 초과). 루프 종료.
```

### 정체로 중단 (S2)
```
[ctx-score-loop] coupon-feature — round 3 (STALLED)
  최종 82/100. 막힌 축: 모듈 간 의존성 (core-network API 미배포)
  → 중단. 사람 결정 대기.
```

---

## 6. 다른 엔진과의 관계

- 기본 엔진은 OMC `ralph`다. 종료조건 "4축 점수 > 85 & 빌드축 ≠ 0"을 ralph에 주입한다 (`docs/omc-ouroboros-integration.md` §2-2-S).
- 측정 가능 목표가 강하면 Ouroboros `evolve`로 대체 가능. 규약(채점 기준·종료 판정)은 엔진 독립적이다.

---

## 7. 주의

- 이 루프는 **GATE(사람 승인)를 자동 통과시키지 않는다.** GATE-3 이후 구현 구간에서만 동작한다.
- 비즈니스 정책(환불/정산/권한) 미확정은 여전히 STOP 조건이다.
- 완료는 오직 검증 통과 시에만 보고한다. 테스트 실패/스킵 시 그 사실을 명시한다.

---

## 8. 전체 예시 (따라 하기)

`/ctx-aidlc-run`부터 `/ctx-score-loop`까지 한 기능을 끝까지 진행한 walkthrough 예시:

- `examples/score-loop-walkthrough/book-borrowing/` — "도서 대출" 기능
  - `README.md` — 단계별 흐름
  - `requirements.md` / `requirement-verification-questions.md` / `unit-of-work.md` / `status.md` — `/ctx-aidlc-run` 산출물
  - `dependency-check.md` — 점수 루프 채점 입력 + Score History(75→82→92)
  - `LOOP-RUN.md` — 라운드별 진행 + 정체/거짓완료 반례
