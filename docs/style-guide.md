# Style Guide

This is the standard for mixing Korean/English when writing outputs.

## Principles

- Outputs must be quick for teammates to read.
- Keep proper nouns and technical terms in English.
- Write explanations and judgments in Korean.

## Section Headings

| Location | Language | Example |
|------|------|------|
| Template section titles | English | `## Goal`, `## In-Scope`, `## Summary` |
| Workflow rule doc sections | Korean | `## 원칙`, `## 게이트 목록`, `## 승인 필요 항목` |

Reason: template headings are fixed in English for consistency across projects. Rule docs are read by the internal team, so Korean reads naturally.

## Field Labels

| Location | Language | Example |
|------|------|------|
| Question doc labels | Korean (required) | 분류, 영향도, 이유, 선택지, 미응답 시, [답변] |
| UOW field labels | Korean | 책임, 예상 위치, 의존성, 규모, 수용 기준, 검증 방법 |
| Status values | English | `OPEN`, `ANSWERED`, `BLOCK`, `ASSUME-A`, `TODO` |

Reason: keep it consistent with the "labels must be in Korean" rule in `common/question-rules.md`. Status values stay in English so they can be parsed by code/automation.

## Body

| Item | Language | Example |
|------|------|------|
| Requirement descriptions | Korean | "재구매 고객에게 자동으로 할인 쿠폰을 발급한다" |
| Technical terms | Keep in English | API, DB, Entity, Repository, JPA, batch |
| File paths | English | `ctx/project-profile.ctx.md` |
| Commit messages | Korean (excluding type/scope) | `feat: (coupon) 쿠폰 도메인 기본 구조 추가` |

## Prohibited Mixing

- Do not needlessly mix Korean and English within a single sentence.
  - Bad: "유저의 order를 cancel하는 로직"
  - Good: "사용자의 주문을 취소하는 로직" or, in a technical context, "Order 취소 로직"
- Do not alternate between Korean and English for the same concept within the same document.
  - Bad: mixing "쿠폰" and "coupon" in the same document
  - Good: unify to one ("쿠폰" in the body, "coupon" in code/paths)
