# Reverse Engineering

This is the workflow for systematically analyzing an existing system in a brownfield project.

## Trigger conditions

- STEP 1 determined it to be `brownfield`, and
- There are no existing Reverse Engineering artifacts (`aidlc-docs/reverse-engineering/`)
- Run it as STEP 1.5.

If existing RE artifacts are present, skip this step and reference the existing artifacts.

## Purpose

Starting design without understanding the existing system means:
- You end up proposing structures that conflict with existing patterns
- You end up duplicating components that already exist
- You miss the impact scope of data model changes

In this step, you first grasp the whole picture of the existing system.

## Artifacts

The artifacts are created at the project level (not the feature level):

```text
aidlc-docs/reverse-engineering/
├── business-overview.md
├── architecture-overview.md
└── component-inventory.md
```

Templates: `templates/reverse-engineering/`

## Order of execution

### 1. Business Overview

Grasp the business context of the project.

- **Business domain**: the core domain the project deals with (e.g. e-commerce, fintech, SaaS)
- **Core transactions**: the main business transactions the system handles (e.g. order → payment → shipping)
- **Stakeholders**: the user types that use or are affected by the system
- **Glossary**: the core business terms and definitions used in the project

Sources: `README.md`, `AGENTS.md`, `ctx/`, code comments, domain package structure

### 2. Architecture Overview

Grasp the technical architecture of the existing system.

- **Architecture pattern**: monolith / modular monolith / MSA / serverless, etc.
- **Main components**: the core components that make up the system and their roles
- **Data flow**: the paths that main data takes through the system
- **External integrations**: external services, APIs, message queues, etc. in use
- **Tech stack**: language, framework, DB, infrastructure

Sources: code structure, configuration files, package dependencies, `ctx/project-profile.ctx.md`

### 3. Component Inventory

Classify existing components by type.

- **Domain components**: modules/packages containing business logic
- **Infrastructure components**: DB, cache, queue, storage, etc.
- **Common components**: authentication, logging, error handling, utilities, etc.
- **Core dependencies**: dependency relationships between components (including whether cyclic)
- **Reuse candidates**: existing components that can be reused in new features

Sources: package structure, import relationships, configuration files

## For detailed exploration, see docs/brownfield-guide.md

When actually analyzing a feature after Reverse Engineering completes:
- For a detailed guide on identifying impacted domains, checking existing patterns, selecting conflict points, etc., follow `docs/brownfield-guide.md`.
- The RE artifacts are used as a reference base in all subsequent feature analysis.

## Cautions

- Do not force a new structure without understanding the existing structure.
- Before proposing a "better way", first follow the existing patterns.
- When you must introduce a pattern that differs from the existing code, leave the rationale as an ADR.
