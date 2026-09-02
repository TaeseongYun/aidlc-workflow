# Hallucination Guard (바이브 블로커) 가이드

AI의 근거 없는 추측이 dev fact처럼 산출물에 새어나가는 것을 막는 **항상 켜진** 레이어.
`ai-bloc-hallucination`에서 검증한 hallucination guard를 team-ai-workflow 본체로 이식하고,
검증의 1차 소스로 **코드 그래프(graphify)** 를 강력히 권장한다. (codegraph는 선택적 fallback.)

## 왜 코드 그래프를 권장하는가

가드의 핵심 규칙은 "모든 dev fact를 구체적 소스로 검증하라. 코드를 기억하지 말고 읽어라.
추측을 다른 추측으로 검증하지 마라"이다. 이때 가장 신뢰도 높은 소스가 **코드 그래프**다 —
`graphify query "<질문>"` / `graphify explain "<entity>"` / `graphify path "<a>" "<b>"` (또는 MCP
`query_graph`/`get_node`)는 노드·호출 경로와 원문 위치(`file:line`)를 돌려준다. 그래프가 없으면
VERIFY는 grep/Read로 후퇴하는데, 이는 hallucination이 가장 잘 생기는 약한 표면이다. 그래서 `graphify`
+ `graphify-out/graph.json` 그래프를 **강력히 권장**한다 — 다만 필수는 아니다. 없으면 가드는
**degraded 모드**로 동작한다(지원되는 폴백; grep/Read + `⚠️ UNCERTAIN` 적극 부착).
codegraph가 설치돼 있으면 보조 fallback으로 쓴다.

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

## 코드 그래프 체크 (비차단)

`scripts/check-graphify.sh [project-root] [--mode=brownfield|greenfield]` 종료코드는 정책이 아니라
**진단 신호**다. 소비자(스크립트/스킬)가 각자 처리한다:

- `0` — 충족 (`graphify` + `graphify-out/graph.json`). 진행 가능. (greenfield에서 그래프 미생성도
  `0`+`WARN` — 첫 구현 후 생성.)
- `2` — `graphify` 도구 누락. **degraded 가능**(차단 아님) — VERIFY가 grep/Read로 후퇴. 설치 권장.
- `3` — brownfield인데 그래프 미생성. `graphify .`로 생성 후 통과.

배선:

- **CLI 경로** — `scripts/init-project.sh`가 시작 시 게이트를 실행한다. 코드 2면 경고만 남기고
  **degraded 모드로 계속 진행**한다(더 이상 `exit 1` 하지 않는다). 코드 3이면 `graphify .`으로
  그래프를 만들고, 실패해도 경고 후 degraded로 계속한다.
- **Claude 경로** — `/team-ai-workflow-start`의 진단 F가 게이트를 평가하고, 코드 2면 **CASE 0**에서
  자유 텍스트 "계속" 프롬프트 대신 **AskUserQuestion 대화 상자**로 (1) 설치 (2) degraded 모드로 진행
  (3) 취소 를 묻는다. (1) 승인 시 install 명령 + `graphify .` 실행 후 재검사로 통과를 확인한 뒤 라우팅한다.
  (2) 선택 시 `aidlc-docs/aidlc-state.md`에 `Hallucination Guard Mode: degraded`를 기록하고 계속한다.

> graphify는 PyPI 패키지 `graphifyy`(더블 y, 콘솔 명령은 `graphify`)로 설치한다:
> `uv tool install "graphifyy[mcp]"`. 정확한 패키지·설치 문자열은 `scripts/check-graphify.sh`의
> `GRAPHIFY_PKG`/`GRAPHIFY_INSTALL` 한 곳에서만 지정한다 (감지는 `command -v graphify`).

## 감사 루프

`/ctx-hallucination-audit [scope]` — HARVEST → VERIFY(graphify 우선) → SCORE → RECORD → QUARANTINE
→ CAPTURE(→ Linear)를 Hallucination-Free Score ≥ 87까지 반복한다. Score < 87에서 스스로 완료를
선언하지 않으며, 사용자만 확인 가능한 사실에서 막히면 멈추고 묻는다. 규칙·점수표는 가드 규칙 원문 참조.
