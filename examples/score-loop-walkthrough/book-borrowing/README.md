# Walkthrough 예시 — 도서 대출 (Book Borrowing)

`/ctx-aidlc-run`(요구사항 분석)부터 `/ctx-score-loop`(의존성 인지 점수 루프)까지 **한 기능을 끝까지** 진행한 예시다.
다른 사람이 이 흐름을 그대로 따라 할 수 있도록, 각 단계에서 무엇을 입력하고 무엇이 나오는지 보여준다.

> 이것은 **문서 예시**다. 실제 코드는 없고, 산출물과 루프 진행 과정을 글로 보여준다.
> 실제 프로젝트에서는 같은 명령을 자기 코드베이스에서 돌리면 된다.

## 가상 시나리오

- 프로젝트: 작은 도서관 백엔드 (가상)
- 요청: **"회원이 도서를 대출할 수 있게 해줘. 재고가 있으면 빌려주고, 1인당 최대 3권, 대출 기간은 14일."**
- 분류: prepared-requirement (요구사항이 비교적 명확)
- Depth: standard (단일 도메인, 설계 결정 1~2개)

## 진행 순서

| 단계 | 명령 | 산출물 | 이 예시 파일 |
|------|------|--------|-------------|
| 1 | `/ctx-aidlc-run` | 요구사항·질문·UOW 분석 | `requirements.md`, `requirement-verification-questions.md`, `unit-of-work.md`, `status.md` |
| 2 | (구현) | GATE-3 통과 후 실제 코드 작성 | (이 예시에선 생략 — 가상) |
| 3 | `/ctx-score-loop` | 의존성·4축 자동 반복 채점 | `dependency-check.md` (라운드별 변화) |

## 1단계 — `/ctx-aidlc-run` (요구사항 분석)

입력:
```
/ctx-aidlc-run

회원이 도서를 대출할 수 있게 해줘.
재고가 있으면 빌려주고, 1인당 최대 3권, 대출 기간은 14일.
```

핵심 흐름:
- prepared-requirement로 분류 → 입력 검증 → 질문 생성(BLOCK 1~2개) → GATE-2 → UOW 분해 → GATE-3.
- 산출물은 같은 디렉토리의 `requirements.md`, `requirement-verification-questions.md`, `unit-of-work.md`, `status.md` 참고.

이 단계에서 나온 **질문**(예: "이미 대출 중인 책을 또 빌리려 하면?")이 어떻게 BLOCK으로 잡히고 답해지는지가 핵심이다.

## 2단계 — 구현 (가상)

GATE-3 통과 후, UOW 순서대로 실제 코드를 작성한다. 이 예시에서는 코드를 생략하고, 3단계 점수 루프가 "구현된 코드"를 채점하는 상황을 가정한다.

## 3단계 — `/ctx-score-loop` (의존성 인지 점수 루프)

입력 (단 한 번):
```
/ctx-score-loop book-borrowing
```

그러면 사용자가 매번 "검증해줘"를 요청하지 않아도, 루프가 알아서 **구현→채점→보완**을 반복한다.

- `dependency-check.md`의 의존성 체크리스트를 채점 입력으로 쓴다.
- 4축(의존성/빌드/테스트/AC, 각 25점)을 매 라운드 채점한다.
- **85점을 초과(`> 85`)하면 완료**로 보고하고 종료한다.
- 2회 연속 미개선(정체) / 10회·30분(상한) / 점수 하락(회귀)이면 즉시 중단·보고한다.

`dependency-check.md`의 **Score History** 테이블이 라운드별로 어떻게 채워지는지를 보면 루프 동작을 한눈에 알 수 있다.

자세한 라운드별 진행은 `LOOP-RUN.md`를 본다.

## 따라 하기 (Quick Start)

```bash
# 0. 프레임워크 스킬 설치 (최초 1회)
bash scripts/install-skills.sh

# 1. 자기 프로젝트에서 요구사항 분석
/ctx-aidlc-run
> "회원이 도서를 대출할 수 있게 해줘. ..."

# 2. GATE 승인하며 진행 → 구현

# 3. 구현 후 점수 루프 한 번 실행
/ctx-score-loop book-borrowing
> 85점 초과까지 자동 반복. 정체/상한 시 중단·보고.
```
