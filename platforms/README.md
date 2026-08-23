# Platform Guidance

Per-platform architecture knowledge the AI agent must load **before implementing**
on that platform. Each document captures the current baseline the team works
against: boundaries, module structure, decision tables, rules, and refactor
signals.

## Platforms

| Platform | Guidance |
|----------|----------|
| Android | [android/guidance.md](android/guidance.md) |
| iOS | [ios/guidance.md](ios/guidance.md) |
| Backend | [backend/guidance.md](backend/guidance.md) |
| Frontend (Web) | [frontend/guidance.md](frontend/guidance.md) |
| Flutter | [flutter/guidance.md](flutter/guidance.md) |
| React Native | [rn/guidance.md](rn/guidance.md) |

## Precedence

```
project ctx/ (project-profile, local CTX)  >  platforms/<platform>/guidance.md  >  agent's general knowledge
```

- Platform guidance fills the gap when the project CTX is silent.
- If a project's `ctx/` contradicts platform guidance, the project CTX wins —
  flag the conflict in the review output, do not silently pick one.
- Platform guidance never overrides safety rules (hallucination guard, gates,
  security baseline).

## How the workflow consumes these documents

1. Declare the platform in the project profile (`ctx/project-profile.ctx.md`):

   ```markdown
   ## Platform
   - Platform: android          # android | ios | backend | frontend | flutter | rn
   - Guidance: {{TEAM_AI_WORKFLOW_DIR}}/platforms/android/guidance.md
   ```

   A project spanning multiple platforms lists one line per platform.

2. `ctx-run` ROLE 1 (IMPLEMENTOR) and `ctx-aidlc-run` STEP 6.5 (technical
   design) read the declared guidance file(s) before producing output.

3. If no platform is declared, infer it from the repository layout
   (`build.gradle.kts` + `AndroidManifest.xml` → android, `Package.swift`/
   `*.xcodeproj` → ios, `pubspec.yaml` → flutter, `react-native` in
   package.json → rn, other package.json with a UI framework → frontend,
   otherwise server code → backend) and state the inference in the output.

## Using the documents from outside this repo

The documents are plain markdown with no repo-internal dependencies, so any
external agent, skill, or repo can pull them:

- **Installed path** — after `install-skills.sh`, skills reference them via the
  injected absolute path: `{{TEAM_AI_WORKFLOW_DIR}}/platforms/<platform>/guidance.md`.
- **Raw URL** — fetch directly:
  `https://raw.githubusercontent.com/TaeseongYun/aidlc-workflow/main/platforms/<platform>/guidance.md`
- **Copy into a project** — copy the file into a project's `ctx/` and list it
  under "Related CTX Files" in `project-profile.ctx.md`. The copy then follows
  project-CTX precedence.

## Maintenance

- Each document is a living baseline. When team conventions change, update the
  document — do not encode conventions only in skill prompts.
- Team-specific conventions (not general platform knowledge) live under a
  `## Team Conventions` section in each document so they are easy to audit.
