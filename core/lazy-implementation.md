# Lazy Implementation (절제 구현 규칙)

이 문서는 **구현 단계에서 코드량을 최소화하는 공통 규칙**이다.
출처는 [ponytail](https://github.com/DietrichGebert/ponytail)의 "lazy senior developer" 철학이며,
aidlc-workflow의 CTX·게이트·과신 방지 규칙과 충돌하지 않도록 옮겨 적은 것이다.

> 핵심 원칙: **"가장 좋은 코드는 작성하지 않은 코드다."**
> 단, **"해법에는 게으르되, 읽기에는 절대 게으르지 않는다."** 코드를 덜 쓰기 위해
> 문제와 기존 코드를 더 깊이 읽는다.

이 규칙은 **새 코드를 작성하기 직전(주로 `ctx-run`의 ROLE 1 — IMPLEMENTOR)** 에 적용한다.
요구사항 분석/설계 단계(ROLE 0 이전, GATE-3 이전)에는 적용하지 않는다.
그 단계의 "무엇을 만들 것인가"는 이미 사람 게이트가 통제한다.

---

## 1. 7단계 절제 사다리 (Decision Ladder)

코드를 한 줄이라도 새로 쓰기 전에, 위에서부터 순서대로 자문한다.
위 칸에서 멈출 수 있으면 아래로 내려가지 않는다.

1. **이 코드가 존재할 필요가 있는가?** — 없으면 만들지 않는다 (YAGNI).
2. **이미 이 코드베이스에 있는가?** — 있으면 재사용한다. 다시 쓰지 않는다.
3. **표준 라이브러리로 되는가?** — 되면 표준 라이브러리를 쓴다.
4. **플랫폼/프레임워크 기본 기능인가?** — 되면 그것을 쓴다.
5. **이미 설치된 의존성으로 되는가?** — 되면 그것을 쓴다.
6. **한 줄로 되는가?** — 되면 한 줄로 한다.
7. **그제서야** 동작하는 최소한의 코드를 직접 작성한다.

CTX 우선순위와의 관계:
- 2번(코드베이스 재사용)은 `ctx/`의 **재사용 컴포넌트 목록**과 직접 연결된다.
  재사용 후보가 CTX에 명시되어 있으면 그것을 먼저 쓴다.
- 4·5번(기본 기능/기존 의존성)은 `ctx/project-profile.ctx.md`의
  **기술 스택·허용 의존성**을 근거로 판단한다.
- 새 의존성 추가는 의존성 관리 규칙(PR 설명에 사유 명시)을 그대로 따른다.
  사다리를 핑계로 의존성을 임의 추가하지 않는다.

---

## 2. 안전 가드 (절대 줄이지 않는 것)

절제는 **해법의 분량**에만 적용한다. 다음은 사다리로 깎을 수 없다.

- **신뢰 경계 검증** — 입력 검증, 권한 확인, 인증 (`core/input-validation.md`).
- **데이터 손실 방지** — 트랜잭션 경계, 롤백, 멱등성.
- **보안** — 비밀정보 비노출, 주입 방지, 최소 권한.
- **접근성** — 사용자 화면이 있는 경우 a11y 요건.
- **요구사항 충족** — `requirements.md`의 Acceptance Criteria.
- **비즈니스 정책** — 결제/환불/정산/권한/알림은 항상 사람 결정 (`core/core-workflow.md` §13).

위 항목을 "한 줄로 줄였다"는 이유로 누락하면 절제가 아니라 결함이다.

---

## 3. 적용 시점과 비적용 시점

### 적용한다
- `ctx-run` ROLE 1(IMPLEMENTOR)에서 production 코드를 쓰기 직전.
- OMC autopilot / ralph로 구현을 위임할 때 (프롬프트에 사다리를 주입).
- 리팩터링·확장 작업에서 기존 코드를 다시 만들려 할 때 (2번 우선).

### 적용하지 않는다
- 요구사항 분석·질문 생성·UOW 분해·기술 설계 (GATE-3 이전).
  이 단계의 산출물은 분량이 아니라 **누락 없음**이 목표다.
- 테스트 코드(ROLE 2)는 절제보다 **커버리지·재현성**이 우선이다.
  단, 중복 테스트·불필요한 목(mock)은 줄인다.
- 안전 가드(§2)에 해당하는 코드.

---

## 4. 절제 메모 (deferred shortcut)

사다리를 적용하다가 "지금은 최소로 두지만 나중에 검토할 여지"가 생기면
코드에 다음 형태의 단서를 남기고 `aidlc-docs/audit.md`에 한 줄 기록한다.

```
// ponytail: <줄인 내용 / 나중에 검토할 이유>
```

- 이 메모는 **결정의 연기**이지 누락이 아니다.
- 모아서 검토할 때는 ponytail 플러그인이 설치된 경우 `/ponytail-debt`로 정리하거나,
  설치돼 있지 않으면 ROLE 3(REVIEWER)에서 수동으로 점검한다.

---

## 5. 리뷰 시 점검 (ROLE 3 연계)

ROLE 3 — REVIEWER(`ctx-reviewer`)는 CTX 위반 점검에 더해 다음을 확인한다.

- 1~6번 사다리에서 멈출 수 있었는데 7번(직접 작성)으로 내려간 곳이 있는가?
- 재사용 가능한 기존 컴포넌트를 두고 새로 만든 코드가 있는가?
- §2 안전 가드가 "절제"를 이유로 빠지지 않았는가? (이건 절제 위반보다 우선 차단)

ponytail 플러그인이 설치돼 있으면 `/ponytail-review`로 diff를 스캔해
삭제 후보 목록을 받을 수 있다. 미설치 시 위 점검을 수동으로 수행한다.

---

## 6. 강도(intensity)와 모드

ponytail 플러그인을 함께 쓰는 경우 강도를 조절할 수 있다. 플러그인 없이도
같은 의미로 ROLE 1 프롬프트에 명시할 수 있다.

| 모드 | 의미 | aidlc-workflow 권장 |
|------|------|--------------------|
| `lite` | 사다리를 가볍게 적용 | 단순 변경(change-on-existing-feature) |
| `full` | 표준 적용 (기본값) | 일반 feature 구현 |
| `ultra` | 과잉 엔지니어링이 심한 코드의 최대 절제 | 레거시 정리·대규모 리팩터링 |
| `off` | 절제 비활성화 | 프로토타이핑 등 의도적으로 코드를 늘릴 때 |

기본값은 `full`이다. 강도와 무관하게 §2 안전 가드는 항상 유지된다.

---

## 7. 다른 워크플로우 규칙과의 우선순위

충돌 시 우선순위는 다음과 같다 (위가 우선).

1. 안전 가드(§2) 및 `core/core-workflow.md` §13 금지 사항.
2. CTX 사실(`ctx/`)과 승인된 `requirements.md` / `technical-design.md`.
3. 사람 게이트(GATE) 결정.
4. 본 문서의 절제 사다리(§1).

즉, 절제 사다리는 "동일하게 올바른 여러 구현" 중에서 **가장 적은 코드**를
고르게 하는 규칙이지, 요구사항·설계·안전을 깎는 권한이 아니다.

---
---

# Lazy Implementation (English mirror)

This document defines the **shared rule for minimizing code at implementation time**.
It is adapted from the "lazy senior developer" philosophy of
[ponytail](https://github.com/DietrichGebert/ponytail), rewritten so it does not
conflict with aidlc-workflow's CTX, gate, and overconfidence-prevention rules.

> Core principle: **"The best code is the code you never wrote."**
> But: **"Lazy about the solution, never about reading."** We read the problem and
> existing code more deeply in order to write less code.

Apply this rule **right before writing new code** (mainly `ctx-run` ROLE 1 — IMPLEMENTOR).
Do NOT apply it during requirements/design (before GATE-3); human gates already
control "what to build" there.

## 1. The 7-Rung Decision Ladder

Before writing a single new line, ask top-down. Stop at the first rung you can.

1. **Does this need to exist?** → no: skip it (YAGNI)
2. **Already in this codebase?** → reuse it, don't rewrite
3. **Stdlib does it?** → use it
4. **Native platform/framework feature?** → use it
5. **Installed dependency?** → use it
6. **One line?** → one line
7. **Only then:** the minimum code that works

Relation to CTX: rung 2 maps to the **reusable components** listed in `ctx/`;
rungs 4–5 are judged against the **tech stack / allowed dependencies** in
`ctx/project-profile.ctx.md`. Adding a new dependency still follows the
dependency-management rule (justify in the PR) — the ladder is not an excuse to add deps.

## 2. Safety Guards (never trimmed)

Laziness applies to the **solution's volume** only. These are off the chopping block:
trust-boundary validation, data-loss handling, security, accessibility,
Acceptance-Criteria coverage, and business policy (always a human decision).
Dropping any of these "to make it one line" is a defect, not laziness.

## 3. When to apply / not apply

Apply: ROLE 1 implementation, OMC autopilot/ralph hand-off prompts, refactors that
risk recreating existing code. Do NOT apply: requirements/design/UOW (goal is
completeness, not brevity), safety-guard code, or test coverage (cut only duplicate
tests/mocks).

## 4. Deferred shortcut note

Leave `// ponytail: <what was trimmed / why revisit later>` in code and log one line
in `aidlc-docs/audit.md`. It is a deferred decision, not an omission. Consolidate via
`/ponytail-debt` if the plugin is installed, else review manually in ROLE 3.

## 5. Review hook (ROLE 3)

ROLE 3 (`ctx-reviewer`) additionally checks: did we drop to rung 7 when an earlier
rung worked? Did we rebuild something reusable? Were any §2 guards skipped under the
name of laziness (blocked first)? Use `/ponytail-review` if installed; otherwise do
it manually.

## 6. Intensity modes

`lite` (gentle / simple changes), `full` (default), `ultra` (max reduction for
over-engineered code / large refactors), `off` (disabled, e.g. prototyping).
Safety guards in §2 hold regardless of intensity.

## 7. Precedence

Top wins: (1) safety guards §2 + core-workflow §13 prohibitions, (2) CTX facts and
approved requirements/technical-design, (3) human gates, (4) this ladder. The ladder
picks the **least code** among equally-correct implementations — it never overrides
requirements, design, or safety.
