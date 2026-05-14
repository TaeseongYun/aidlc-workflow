# Requirements Analysis

## 목표
- 사용자 요청을 기능 요구사항으로 구조화한다.
- 누락된 정책/예외/운영 조건을 질문으로 추출한다.

## 질문 추출 기준
- 누가 사용하는지 불명확한가
- 어디에 적용되는지 불명확한가
- 언제 상태가 바뀌는지 불명확한가
- 실패/취소/환불/만료 등 예외가 불명확한가
- 관리자/운영자 액션이 필요한가
- 알림/로그/감사 추적이 필요한가
- 기존 시스템과 연결 방식이 불명확한가

## 출력 형식
- Goal
- In-Scope
- Out-of-Scope
- Functional Requirements
- Derived Requirements
- Requirement Gaps
- Initial Risk Assessment

## Brownfield 추가 기준
- 기존 서비스/도메인/테이블과 연결 지점을 명시한다.
- 새 기능이 기존 흐름을 대체하는지 확장하는지 구분한다.

## Greenfield 추가 기준
- 핵심 엔티티
- 상태 전이
- 사용자 역할
- MVP 범위
- 기본 운영 모델
