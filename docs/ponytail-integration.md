# Ponytail 연동 가이드

[ponytail](https://github.com/DietrichGebert/ponytail)은 AI 에이전트가 **코드를 덜 쓰도록**
만드는 플러그인이다. "가장 좋은 코드는 작성하지 않은 코드"라는 원칙으로, 코드를 쓰기 전에
7단계 의사결정 사다리를 통과시켜 과잉 엔지니어링을 막는다.

team-ai-workflow과는 담당 영역이 다르므로 **겹치지 않고 보완**된다.

```text
┌────────────────────┐   ┌────────────────────┐   ┌────────────────────┐
│ team-ai-workflow   │   │ OMC / Ouroboros    │   │ ponytail           │
│ - 요구사항/설계     │ → │ - 자동화 루프       │ + │ - 7단계 절제 사다리 │
│ - 사람 GATE         │   │ - 반복 검증         │   │ - over-eng 제거     │
└────────────────────┘   └────────────────────┘   └────────────────────┘
      (What)                   (How, 자동화)              (절제, How를 얇게)
```

- **What** — 무엇을 만들 것인가: team-ai-workflow (CTX + GATE)
- **How** — 어떻게 자동으로 굴릴 것인가: OMC / Ouroboros
- **절제** — 만들되 얼마나 적게 만들 것인가: ponytail

세 영역 모두 **GATE 승인은 사람이 한다**는 원칙을 공유한다. ponytail은 코드량만 줄일 뿐
요구사항·설계·안전을 깎지 않는다.

---

## 1. 어디에 끼워 넣는가

team-ai-workflow에서 코드를 실제로 쓰는 지점은 `ctx-run`의 **ROLE 1 — IMPLEMENTOR** 한 곳이다.
ponytail의 절제는 바로 그 직전에 작동하고, **ROLE 3 — REVIEWER**에서 결과를 점검한다.

```text
/ctx-aidlc-run            ← 요구사항/설계 (GATE-2/3, 사람 승인)
  ↓ (GATE-3 통과)
/ctx-run
  ROLE 0 ARCHITECT        ← 절제 미적용 (범위 판단)
  ROLE 1 IMPLEMENTOR      ← ★ 코드 쓰기 직전 7단계 사다리 적용
  ROLE 2 TEST_WRITER      ← 절제는 중복 테스트/목에만
  ROLE 3 REVIEWER         ← ★ over-engineering 점검 (/ponytail-review 대응)
  ROLE 4~6               ← 절제 미적용
```

절제 규칙의 원본은 [`core/lazy-implementation.md`](../core/lazy-implementation.md)에 있다.
ctx-run 스킬은 이 문서를 근거로 ROLE 1/ROLE 3에서 사다리를 적용한다.
**ponytail 플러그인을 설치하지 않아도** 이 규칙만으로 절제 효과를 얻는다.

---

## 2. 7단계 절제 사다리

코드를 새로 쓰기 전에 위에서부터 자문하고, 멈출 수 있는 칸에서 멈춘다.

1. 이 코드가 존재할 필요가 있는가? → 없으면 만들지 않는다 (YAGNI)
2. 이미 코드베이스에 있는가? → 재사용한다 (CTX 재사용 컴포넌트 우선)
3. 표준 라이브러리로 되는가? → 쓴다
4. 플랫폼/프레임워크 기본 기능인가? → 쓴다
5. 이미 설치된 의존성으로 되는가? → 쓴다
6. 한 줄로 되는가? → 한 줄로 한다
7. 그제서야 동작하는 최소한의 코드를 작성한다

안전 가드(검증/보안/데이터 보호/접근성/AC 충족/비즈니스 정책)는 사다리로 깎지 않는다.
자세한 내용과 우선순위는 [`core/lazy-implementation.md`](../core/lazy-implementation.md) 참조.

---

## 3. 사용 방법 — 세 가지 수준

활용 강도에 따라 셋 중 하나를 고른다. 위로 갈수록 손이 덜 가고, 아래로 갈수록 강력하다.

### 3-A. 규칙만 (플러그인 설치 없음, 기본 권장)

`ctx-run`이 `core/lazy-implementation.md`를 근거로 ROLE 1/3에서 자동 적용한다.
추가 설치가 필요 없고, 다른 계정·레포에서도 install-skills.sh만 돌리면 따라온다.

```text
/ctx-run
다음 산출물 기반으로 구현. core/lazy-implementation.md의 7단계 사다리 적용(full).
- aidlc-docs/features/<slug>/requirements.md
- aidlc-docs/features/<slug>/unit-of-work.md
```

### 3-B. OMC autopilot/ralph 프롬프트에 주입

자동 구현을 OMC에 위임할 때, autopilot/ralph 프롬프트에 사다리를 명시한다.

```text
/oh-my-claudecode:autopilot

다음 산출물 기반으로 구현. GATE-3 통과 상태.
- aidlc-docs/features/<slug>/requirements.md
- aidlc-docs/features/<slug>/unit-of-work.md

구현 제약: core/lazy-implementation.md의 7단계 절제 사다리를 적용한다.
- 새 코드를 쓰기 전에 재사용/표준/기존 의존성을 먼저 확인.
- 단, 입력검증·보안·데이터보호·AC 충족은 절대 생략 금지.
unit-of-work.md의 각 AC가 통과할 때까지 반복. 구현 후 ctx-reviewer로 검증.
```

### 3-C. ponytail 플러그인 실제 설치 (선택)

`/ponytail-review`, `/ponytail-audit`, `/ponytail-gain` 같은 전용 명령과 측정 지표가
필요하면 플러그인을 설치한다. 설치는 **사용자 환경 변경**이므로 직접 실행한다.

```text
# Claude Code 마켓플레이스에서 추가 (셸에서 ! 프리픽스로 실행하거나 직접)
/plugin marketplace add DietrichGebert/ponytail
```

설치 후 사용하는 전용 명령:

| 명령 | 용도 | aidlc-workflow 연계 |
|------|------|--------------------|
| `/ponytail [lite\|full\|ultra\|off]` | 절제 강도 조절 | ROLE 1 강도와 맞춘다 |
| `/ponytail-review` | 현재 diff의 over-engineering 삭제 후보 | ROLE 3 REVIEWER에서 호출 |
| `/ponytail-audit` | 레포 전체 불필요 코드 스캔 | 레거시 정리·brownfield 진입 시 |
| `/ponytail-debt` | 미뤄둔 `ponytail:` 메모를 원장으로 정리 | §4 절제 메모 정리 |
| `/ponytail-gain` | 절감 지표(LOC/비용/속도) 표시 | 효과 보고용 |

플러그인은 Node.js가 PATH에 있어야 라이프사이클 훅이 동작한다.

---

## 4. 강도(mode) 매핑

ponytail의 강도 모드를 aidlc-workflow 작업 유형에 매핑한다.

| ponytail 모드 | 의미 | 권장 작업 |
|--------------|------|----------|
| `lite` | 가볍게 적용 | 단순 변경(change-on-existing-feature) |
| `full` | 표준 (기본값) | 일반 feature 구현 |
| `ultra` | 최대 절제 | 레거시 정리·대규모 리팩터링 |
| `off` | 비활성화 | 프로토타이핑 등 의도적 코드 확장 |

기본값은 `full`. 강도와 무관하게 안전 가드는 항상 유지된다.

---

## 5. 충돌 방지 규칙

team-ai-workflow + OMC/Ouroboros + ponytail이 같은 레포에서 동작할 때.

### 5-1. 책임 경계
- **GATE-3 이전**(요구사항/설계)에는 ponytail을 적용하지 않는다.
  이 단계의 목표는 분량 최소화가 아니라 **누락 없음**이다.
- **GATE-3 이후**(구현)에만 절제 사다리를 적용한다.

### 5-2. 안전 가드 우선
- 절제와 안전이 충돌하면 **항상 안전이 이긴다**.
- 입력 검증/보안/데이터 보호/접근성/AC/비즈니스 정책은 "한 줄로 줄였다"는 이유로
  빠질 수 없다. 빠지면 절제가 아니라 결함이며 ROLE 3에서 차단한다.

### 5-3. 상태 디렉토리
- ponytail이 만드는 메모/원장(`ponytail:` 주석, `/ponytail-debt` 산출물)은
  `aidlc-docs/`를 덮어쓰지 않는다.
- 절제 관련 결정은 한 줄로 `aidlc-docs/audit.md`에 `[PONYTAIL]` 프리픽스로 append 할 수 있다.

### 5-4. 우선순위 (위가 우선)
1. 안전 가드 + `core/core-workflow.md` §13 금지 사항
2. CTX 사실 + 승인된 requirements / technical-design
3. 사람 GATE 결정
4. ponytail 절제 사다리

---

## 6. 권장 시나리오

| 시나리오 | 추천 조합 |
|---------|-----------|
| 규칙만으로 가볍게 절제 | `/ctx-run` (core/lazy-implementation.md 자동 적용) |
| 자동 구현 + 절제 | `/ctx-aidlc-run` → `/oh-my-claudecode:autopilot` (사다리 주입) |
| 측정 지표·전용 명령 필요 | ponytail 플러그인 설치 + `/ponytail-review`, `/ponytail-gain` |
| 레거시/over-engineered 코드 정리 | ponytail `ultra` + `/ponytail-audit` |
| 단순 변경 | `/ctx-run` + `lite` |

---
---

# Ponytail Integration Guide (English mirror)

[ponytail](https://github.com/DietrichGebert/ponytail) makes AI agents **write less code**
via a 7-rung decision ladder applied before writing code. It complements team-ai-workflow
without overlapping:

- **What** to build → team-ai-workflow (CTX + GATE)
- **How** to automate → OMC / Ouroboros
- **How thin** to make it → ponytail

All three share the rule: **humans approve gates**. ponytail only trims code volume; it
never trims requirements, design, or safety.

## 1. Where it plugs in

The only place code is written is `ctx-run` **ROLE 1 — IMPLEMENTOR**; the ladder runs just
before it, and **ROLE 3 — REVIEWER** checks the result. The rule source lives in
[`core/lazy-implementation.md`](../core/lazy-implementation.md), so you get the effect
**even without installing the plugin**.

## 2. The 7-rung ladder

1. Does it need to exist? (YAGNI) 2. Already in codebase? (reuse) 3. Stdlib? 4. Native
feature? 5. Installed dependency? 6. One line? 7. Only then: minimum code. Safety guards
(validation/security/data-loss/a11y/AC/business policy) are never trimmed — see
[`core/lazy-implementation.md`](../core/lazy-implementation.md).

## 3. Three usage levels

- **A. Rules only (default):** `ctx-run` applies `core/lazy-implementation.md` in ROLE 1/3.
  No install; travels with `install-skills.sh`.
- **B. Inject into OMC:** add the ladder to the autopilot/ralph prompt (keep safety guards explicit).
- **C. Install the plugin (optional):** `/plugin marketplace add DietrichGebert/ponytail`
  for `/ponytail-review`, `/ponytail-audit`, `/ponytail-debt`, `/ponytail-gain`. Needs
  Node.js on PATH. Installation changes the user environment — run it yourself.

## 4. Mode mapping

`lite` (simple changes), `full` (default), `ultra` (legacy/large refactors), `off`
(prototyping). Safety guards hold at every mode.

## 5. Conflict avoidance

Don't apply ponytail before GATE-3 (goal there is completeness, not brevity). Safety always
beats brevity. ponytail artifacts never overwrite `aidlc-docs/`; log decisions to
`audit.md` with a `[PONYTAIL]` prefix. Precedence (top wins): safety guards + core-workflow
§13 → CTX + approved design → human gates → ladder.

## 6. Recommended scenarios

Rules-only → `/ctx-run`. Automated + trimmed → `/ctx-aidlc-run` → autopilot with ladder.
Metrics/commands → install plugin. Legacy cleanup → `ultra` + `/ponytail-audit`. Simple
change → `lite`.
