<!-- workflow-step: all steps & gates | producer: ctx-aidlc-run, ctx-aidlc-roadmap | append-only -->
# Audit Log

감사 로그 작성 규칙:
- 타임스탬프는 ISO 8601 형식 (YYYY-MM-DDTHH:MM:SSZ)
- 사용자 입력은 원문 그대로 기록 (요약/의역 금지)
- 항상 기존 내용 뒤에 append (덮어쓰기 금지)
- **모든 STEP 시작/완료, 모든 GATE 통과, 사용자 입력(질문 답변 포함)마다 기록**
- **Phase 0 (Roadmapping) 이벤트, GATE-0, 핸드오프**도 동일 규칙으로 기록한다.

## 로깅 트리거 (필수)

아래 이벤트가 발생하면 반드시 audit.md에 append 한다.

### 1. STEP 시작/완료
매 STEP 진입 시와 완료 시 기록한다. 조건부 STEP이 스킵되는 경우에도 스킵 사유를 기록한다.
Phase 0 STEP은 ID를 `STEP-R1` ~ `STEP-R6`로 표기하고, Feature 필드는 `roadmap`(피처가 결정되기 전 단계)으로 기록한다.

```markdown
## [STEP-N] [단계명] — [started / completed / skipped]
- Timestamp: [ISO 8601]
- Feature: <feature-slug>  # Phase 0 단계는 "roadmap"
- Step: STEP-N
- Action: started / completed / skipped
- Reason: [스킵 시 사유. 예: "전체 S 규모", "기존 사용자 유형만 해당", "single-feature"]
- Outputs: [생성/갱신된 파일 목록]
```

### 2. GATE 통과
매 GATE에서 사용자 승인/변경 요청/스킵 시 기록한다.
GATE-0 (Roadmap Review)도 동일 포맷을 사용하며 Feature 필드는 `roadmap`으로 기록한다.

```markdown
## [GATE-N] [단계명]
- Timestamp: [ISO 8601]
- Feature: <feature-slug>  # GATE-0은 "roadmap"
- Gate: GATE-N
- Decision: approved / change-requested / skipped
- User Input: "[사용자 원문 그대로]"
- Notes: [변경 요청 시 요청 내용 요약]
```

### 3. 사용자 입력 (질문 답변)
사용자가 BLOCK/ASSUME 질문에 답변하거나 Discovery 라운드에서 응답할 때 기록한다.

```markdown
## [ANSWER] 질문 답변
- Timestamp: [ISO 8601]
- Feature: <feature-slug>
- Question: [질문 ID 또는 요약]
- User Input: "[사용자 원문 그대로]"
- Impact: [BLOCK 해제 / ASSUME 확정 / Discovery 정보 수집]
```

### 4. 상태 변경
feature status가 변경될 때 기록한다 (예: questions-open → approved).

```markdown
## [STATUS] 상태 변경
- Timestamp: [ISO 8601]
- Feature: <feature-slug>
- Previous: [이전 상태]
- Current: [현재 상태]
- Trigger: [변경을 유발한 이벤트]
```

### 5. 핸드오프 (스킬 간 전환)
한 스킬이 다른 스킬에게 작업을 넘기며 차단할 때 기록한다.
대표 사례: `ctx-aidlc-run` STEP 1-A에서 multi-feature 감지 → `ctx-aidlc-roadmap` 실행 안내.

```markdown
## [HANDOFF] [from-skill] → [to-skill]
- Timestamp: [ISO 8601]
- Feature: <feature-slug 또는 roadmap>
- From: ctx-aidlc-run
- To: ctx-aidlc-roadmap
- Reason: [예: "multi-feature detected, _roadmap.md absent"]
- Resume Hint: [후속 명령어 또는 다음 단계 안내]
```

---

## [timestamp] Feature Start
- Feature: <feature-slug>
- Raw user request captured.
- Workspace scan completed.
- Initial requirement gaps identified.

---
