# Skills

이 디렉터리는 팀 공통 Codex 스킬 원본 저장소다.

## 원칙
- 여기 있는 파일이 팀 공통 스킬의 원본이다.
- 글로벌 실행 경로는 `~/.codex/skills/`이다.
- Claude 글로벌 경로는 `~/.claude/commands/`이다.
- 직접 글로벌 스킬/명령을 수정하지 말고, 여기서 수정한 뒤 설치 스크립트로 배포한다.
- 모든 스킬은 `_shared/skill-protocol.md`의 공통 실행 프로토콜을 따른다.

## 포함 스킬
- `ctx-aidlc-roadmap`
  - Phase 0 멀티피처 로드맵 작성용 (큰 prepared 기획서를 피처별로 분해)
  - 산출물: `aidlc-docs/_roadmap.md`. GATE-0 통과 후 피처별 `ctx-aidlc-run` 진입.
- `ctx-aidlc-run`
  - 요구사항/설계 분석용
  - `team-ai-workflow + ctx + aidlc-docs` 흐름 사용
- `ctx-run`
  - 구현 실행용
- `ctx-architect-judge`
  - 요구사항/영향 범위 판단
- `ctx-domain-exec`
  - 도메인 구현 실행
- `ctx-reviewer`
  - CTX 기준 리뷰
- `ctx-updater`
  - CTX 갱신
- `ctx-refiner`
  - CTX 정제
- `ctx-commit-planner`
  - 커밋 분리 계획

## 설치

```bash
bash scripts/install-skills.sh
```

## 업데이트 절차
1. `skills/` 아래 원본 수정
2. 필요하면 `README.md` 또는 사용 예시 갱신
3. `bash scripts/install-skills.sh` 실행
4. 글로벌 `~/.codex/skills/`에서 동작 확인
5. 글로벌 `~/.claude/commands/`에서 동작 확인

## 사용 권장 흐름

### 단일 피처
1. 요구사항 분석: `/ctx-aidlc-run`
2. 사람 승인/답변 반영
3. 구현 실행: `/ctx-run`

### 멀티피처 (큰 prepared 기획서)
1. 로드맵: `/ctx-aidlc-roadmap` → `aidlc-docs/_roadmap.md` 생성, GATE-0 승인
2. 각 팀원이 자기 피처에 대해 `/ctx-aidlc-run` 실행 (입력: 원본의 해당 섹션 발췌)
3. 사람 승인/답변 반영
4. 구현 실행: `/ctx-run` (피처별)

자세한 운용 절차: `docs/multi-feature-coordination.md`
