# Android Detailed Skills

`guidance.md`(팀 Android 베이스라인)를 6개 주제로 확장한 **참조-지식 스킬**. 각 스킬은
공식 skills 형식(`SKILL.md` + `reference.md`)을 따르며, 관련 파일을 만질 때 `paths`로
자동 로드되고 `/android-*`로 수동 호출도 된다. 심화 자료는 각 스킬의 `reference.md`에.

정합성: 이 스킬들은 `../guidance.md`를 상세 확장한 것이며 이를 상대경로로 참조한다.
프로젝트 `ctx/`가 상충하면 프로젝트 CTX가 우선한다(가이던스 precedence 그대로).

| 스킬 | 목적 | 자동 로드(paths) |
|------|------|-----------------|
| [android-architecture](android-architecture/SKILL.md) | 앱 아키텍처 뼈대 — 의존 흐름·레이어 책임·Feature Slice 결정. 나머지 5개를 묶는 우산 | (없음 — 설명 키워드·수동·상호링크) |
| [android-viewmodel-state](android-viewmodel-state/SKILL.md) | UiState/StateFlow·이벤트(effect)·SavedStateHandle·UDF | `**/*ViewModel.kt`, `**/ui/**/*.kt` |
| [android-module-structure](android-module-structure/SKILL.md) | app/core/feature 분리·api\|impl 분리 시점·convention plugin·버전 카탈로그 | `**/build.gradle.kts`, `**/settings.gradle.kts`, `**/libs.versions.toml`, `**/*.gradle` |
| [android-lifecycle-memory](android-lifecycle-memory/SKILL.md) | 라이프사이클 인식 수집·스코프 취소·onTrimMemory·누수 방지 | `**/*Activity.kt`, `**/*Fragment.kt`, `**/ui/**/*.kt` |
| [android-background-rules](android-background-rules/SKILL.md) | 백그라운드 실행 제한·WorkManager·포그라운드 서비스·Doze·백그라운드 위치 | `**/*Worker.kt`, `**/*Service.kt`, `**/AndroidManifest.xml` |
| [android-security](android-security/SKILL.md) | exported 신뢰 경계·Intent/extras 검증·데이터 암호화·네트워크 보안·Keystore·Play Integrity | `**/AndroidManifest.xml`, `**/network_security_config.xml`, `**/*.kt` |
