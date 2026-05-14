<!-- workflow-step: STEP-5 | gate: GATE-2 | producer: ctx-aidlc-run -->
# Feature Requirements

## Goal
주문 목록 조회 시 최신 주문이 상단에 표시되도록 정렬 오류를 수정한다.

## Background
- 고객 CS 접수: "주문 내역에서 가장 오래된 주문이 맨 위에 나옵니다"
- 원인: `OrderRepository.findByUserId()`의 정렬 조건이 `ASC`로 되어 있음
- 기존 패턴: 다른 목록 조회(상품, 리뷰)는 모두 `DESC` 정렬

## In-Scope
- `OrderRepository.findByUserId()` 정렬 조건을 `DESC`로 수정
- 해당 쿼리를 사용하는 API 응답 정렬 확인

## Out-of-Scope
- 주문 목록 페이징 개선
- 정렬 기준 변경 UI (향후 별도 feature)

## User Scenarios
1. 고객이 주문 내역 진입 → 최신 주문이 최상단에 표시됨
2. 고객이 주문 내역 2페이지 조회 → 시간순 내림차순 유지

## Functional Requirements
- FR-1: `OrderRepository.findByUserId()`의 정렬 조건을 `created_at DESC`로 변경한다
- FR-2: 관련 API(`GET /api/orders`)의 응답이 최신순 정렬인지 확인한다

## Derived Requirements
- 없음 (기존 코드 패턴 재사용)

## Requirement Gaps
- 없음

## Approval Preconditions
- 없음

## Initial Risk Assessment
- 낮음: 단일 쿼리 수정, 기존 패턴과 동일
