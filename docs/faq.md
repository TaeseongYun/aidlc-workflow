# FAQ

## 자주 하는 실수

### 공통
- `ctx/`만 읽고 바로 구현해버림
- `aidlc-docs` 없이 정책 공백을 코드에서 메움
- `team-ai-workflow`를 안 읽고 프로젝트마다 질문 품질이 달라짐
- brownfield인데 기존 구조 재사용 검토 없이 새 구조를 만듦

### Greenfield
- ctx가 없다고 바로 구현부터 시작함
- product policy가 안 정해졌는데 API부터 설계함
- aidlc-docs 없이 논의가 채팅에만 남음
- 최소 ctx 없이 구현을 시작해 팀 기준이 흩어짐
- 이전 기능 문서를 덮어써서 변경 이력이 사라짐

## 최소 체크리스트
- [ ] 공통 기준은 `team-ai-workflow/`를 읽었는가
- [ ] 프로젝트 로컬 컨텍스트는 `ctx/INDEX.md`, `AGENTS.md` 또는 `CLAUDE.md`, `README.md`를 읽었는가
- [ ] 요구사항 공백을 질문으로 문서화했는가
- [ ] 산출물을 `aidlc-docs/`에 남겼는가
- [ ] 기능별 산출물을 `aidlc-docs/features/<feature-slug>/`로 분리했는가
- [ ] feature 상태를 `status.md`와 `aidlc-state.md`에 반영했는가
- [ ] 구현 전 사람 승인 항목을 분리했는가
