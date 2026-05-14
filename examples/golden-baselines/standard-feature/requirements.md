<!-- workflow-step: STEP-5 | gate: GATE-2 | producer: ctx-aidlc-run -->
# Feature Requirements

## Goal
재구매 고객에게 자동으로 할인 쿠폰을 발급하여 재방문율과 2차 구매 전환율을 높인다.

## Background
- 현재 쿠폰은 관리자가 수동 발급만 가능
- 마케팅팀에서 재구매 유도 캠페인을 요청
- 기존 `coupon` 도메인과 `order` 도메인이 존재

## In-Scope
- 재구매 기준 정의 (최근 N일 내 구매 이력 보유)
- 쿠폰 자동 발급 배치 또는 이벤트 트리거
- 쿠폰 사용 조건: 최소 주문 금액, 1인 1회, 유효기간
- 관리자 캠페인 ON/OFF 기능
- 발급/사용 현황 조회 API

## Out-of-Scope
- 푸시 알림 / 이메일 발송 (별도 feature로 분리)
- 쿠폰 디자인 / 프론트엔드 UI
- 기존 수동 발급 쿠폰과의 통합 (1차 범위 밖)

## User Scenarios
1. 고객 A가 3일 전 주문 완료 → 시스템이 재구매 쿠폰 자동 발급 → 고객 A가 쿠폰함에서 확인
2. 고객 B가 쿠폰 적용하여 재주문 → 최소 주문 금액 이상 → 할인 적용
3. 고객 C가 이미 쿠폰을 사용함 → 중복 사용 차단
4. 관리자가 캠페인을 OFF로 변경 → 신규 발급 중단, 기발급 쿠폰은 유효기간까지 사용 가능

## Functional Requirements
- FR-1: 재구매 기준은 "최근 N일 내 주문 완료 이력 1건 이상"으로 정의한다 (N은 캠페인 설정값)
- FR-2: 캠페인 활성 시 기준 충족 고객에게 쿠폰을 자동 발급한다
- FR-3: 쿠폰은 1인당 캠페인당 1회만 발급한다
- FR-4: 쿠폰 사용 조건: 최소 주문 금액 이상, 유효기간 내
- FR-5: 관리자 API로 캠페인 생성/수정/ON/OFF가 가능하다
- FR-6: 발급/사용 현황 조회 API를 제공한다

## Derived Requirements
- DR-1: 쿠폰 발급 이력 테이블 필요 (campaign_id, user_id, issued_at, used_at)
- DR-2: 캠페인 설정 테이블 필요 (campaign_id, period_days, min_order_amount, discount_amount, active)
- DR-3: 기존 order 도메인에서 구매 이력 조회 API 또는 쿼리 제공 필요

## Requirement Gaps
- RG-1: 할인 금액이 정률인지 정액인지 미확정 → Q1 참조
- RG-2: 쿠폰과 다른 프로모션 중복 적용 가능 여부 미확정 → Q2 참조

## Approval Preconditions
- 할인 방식(정률/정액) 확정 필요
- 쿠폰 중복 적용 정책 확정 필요

## Initial Risk Assessment
- 대량 발급 시 배치 성능 → M 규모 UOW로 분리
- 기존 쿠폰 도메인과 캠페인 쿠폰 간 충돌 가능성 → 테이블 분리로 대응
