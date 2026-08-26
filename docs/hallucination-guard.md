# Hallucination Guard (바이브 블로커) 가이드

AI의 근거 없는 추측이 dev fact처럼 산출물에 새어나가는 것을 막는 **항상 켜진** 레이어.
`ai-bloc-hallucination`에서 검증한 hallucination guard를 team-ai-workflow 본체로 이식하고,
검증의 1차 소스를 **코드 그래프(graphify)** 로 못박았다. (codegraph는 선택적 fallback.)

## 왜 코드 그래프가 전제조건인가

가드의 핵심 규칙은 "모든 dev fact를 구체적 소스로 검증하라. 코드를 기억하지 말고 읽어라.
추측을 다른 추측으로 검증하지 마라"이다. 이때 가장 신뢰도 높은 소스가 **코드 그래프**다 —
`graphify query "<질문>"` / `graphify explain "<entity>"` / `graphify path "<a>" "<b>"` (또는 MCP
`query_graph`/`get_node`)는 노드·호출 경로와 원문 위치(`file:line`)를 돌려준다. 그래프가 없으면
VERIFY는 grep/기억으로 후퇴하고, 그것이 바로 hallucination을 만드는 실패 모드다. 그래서 `graphify`
+ `graphify-out/graph.json` 그래프는 **초기 세팅의 필수 전제조건**이다 (nice-to-have가 아니다).
codegraph가 설치돼 있으면 보조 fallback으로만 쓴다.

## 구성 요소

| 요소 | 위치 | 역할 |
|---|---|---|
| 가드 규칙 (Rule 0–5) | `extensions/hallucination-guard/hallucination-guard.md` | dev fact 검증·격리·점수·Linear 라우팅 규칙 원문 |
| 모듈 맵 | `extensions/hallucination-guard/README.md` | 어떻게 배선되는지 |
| 전제조건 게이트 | `scripts/check-graphify.sh` | graphify·graph.json 감지 (codegraph는 선택적 fallback; TOOL REGISTRY 단일 소스) |
| 마커 수집기 | `scripts/harvest-assumptions.sh` | 감사 루프 HARVEST 입력 |
| 격리 대장 | `templates/hallucination-ledger.md` → `aidlc-docs/` | append-only 격리 목록 (Rule 1에서 최초 로드) |
| 교훈 로그 | `templates/knowledge-log.md` → `aidlc-docs/` | Linear로 푸시되는 교훈 |
| 감사 루프 스킬 | `skills/ctx-hallucination-audit/` | `/ctx-hallucination-audit` — 점수 ≥ 87까지 반복 |

## 전제조건 게이트 (핵심)

`scripts/check-graphify.sh [project-root] [--mode=brownfield|greenfield]` 종료코드:

- `0` — 충족 (`graphify` + `graphify-out/graph.json`). 진행 가능. (greenfield에서 그래프 미생성도
  `0`+`WARN` — 첫 구현 후 생성.)
- `2` — `graphify` 도구 누락. **HARD BLOCK**.
- `3` — brownfield인데 그래프 미생성. `graphify .`로 생성 후 통과.

배선:

- **CLI 경로** — `scripts/init-project.sh`가 시작 시 게이트를 실행한다. 코드 2면 "초기 세팅 불가"
  메시지와 함께 `exit 1` (bash는 대화 상자를 못 띄우므로 크게 실패하고 스킬로 넘긴다). 코드 3이면
  `graphify .`으로 그래프를 만든다.
- **Claude 경로** — `/team-ai-workflow-start`의 진단 F가 게이트를 평가하고, 코드 2면 **CASE 0**에서
  자유 텍스트 "계속" 프롬프트 대신 **AskUserQuestion 대화 상자**로 설치 여부를 묻는다. 사용자가
  명시 승인하면 install 명령 + `graphify .`을 실행하고, 재검사로 통과를 확인한 뒤에만 라우팅한다.

> graphify는 PyPI 패키지 `graphifyy`(더블 y, 콘솔 명령은 `graphify`)로 설치한다:
> `uv tool install "graphifyy[mcp]"`. 정확한 패키지·설치 문자열은 `scripts/check-graphify.sh`의
> `GRAPHIFY_PKG`/`GRAPHIFY_INSTALL` 한 곳에서만 지정한다 (감지는 `command -v graphify`).

## 감사 루프

`/ctx-hallucination-audit [scope]` — HARVEST → VERIFY(graphify 우선) → SCORE → RECORD → QUARANTINE
→ CAPTURE(→ Linear)를 Hallucination-Free Score ≥ 87까지 반복한다. Score < 87에서 스스로 완료를
선언하지 않으며, 사용자만 확인 가능한 사실에서 막히면 멈추고 묻는다. 규칙·점수표는 가드 규칙 원문 참조.
