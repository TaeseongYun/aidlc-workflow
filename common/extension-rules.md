# Extension Rules

선택적 규칙 팩(Extension)을 관리하는 규칙이다.

## 목적

모든 프로젝트에 필요하지 않은 규칙(보안, 컴플라이언스, 성능 등)을 옵트인 방식으로 제공한다.
필요한 규칙만 로드하여 컨텍스트 윈도우를 절약하고, 팀별 커스터마이징을 가능하게 한다.

## 디렉토리 구조

```text
extensions/
└── <domain>/
    ├── <name>.opt-in.md      # 경량 프롬프트 (~20줄). 시작 시 로드.
    └── <name>.md              # 전체 규칙. opt-in 후에만 로드.
```

## 규칙

### Opt-In 파일 (`*.opt-in.md`)
- STEP 1에서 `extensions/` 디렉토리를 스캔하여 모든 `*.opt-in.md`를 로드한다.
- 각 opt-in 파일은 사용자에게 활성화 여부를 묻는 간단한 질문을 포함한다.
- opt-in 파일은 20줄 이내로 유지한다. 상세 규칙을 포함하지 않는다.

### 전체 규칙 파일 (`*.md`)
- 사용자가 opt-in을 승인한 경우에만 로드한다.
- 활성화된 extension은 해당 워크플로우 전체에서 **강제 규칙**으로 적용된다.
- 비활성화된 extension의 규칙 파일은 로드하지 않는다.

### 상태 추적
- `aidlc-state.md`의 `Extension Configuration` 섹션에 각 extension의 상태를 기록한다.
- 상태: `disabled` (기본값) / `enabled`

### Extension 추가 방법
1. `extensions/<domain>/` 디렉토리를 생성한다.
2. `<name>.opt-in.md`를 작성한다 (질문 1개, 설명 1-2줄).
3. `<name>.md`를 작성한다 (전체 규칙).
4. `aidlc-state.md` 템플릿의 Extension Configuration에 항목을 추가한다.

## 현재 제공되는 Extension

| Extension | 도메인 | 설명 |
|-----------|--------|------|
| security-baseline | security | 프로덕션 보안 기준 11개 항목 (SECURITY-01~11) |
| performance-baseline | performance | 성능 요구사항 6개 항목 (PERF-01~06) |
| api-contract | api-contract | API 계약 5개 항목 (API-01~05) |
