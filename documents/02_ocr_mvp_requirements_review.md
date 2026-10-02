---
title: "Flutter OCR MVP 요구사항 검토본"
status: review-required
updated: 2026-10-01
---

# Flutter OCR MVP 요구사항 검토본

## 1. 검토 목적

이 문서는 구현 착수 전 사용자 확인용 요구사항 검토본이다. Flutter 소스 코드, 카메라 기능, NFC 기능은 아직 구현하지 않는다.

## 2. 확정된 방향

| 항목 | 결정 |
|---|---|
| 하이브리드 프레임워크 | Flutter |
| 1차 구현 범위 | 카메라 가이드, OCR, MRZ 파싱·체크섬, 결과 확인 화면 |
| NFC 전자여권 | OCR MVP를 실제 기기에 설치·기동·테스트 완료한 뒤 2차로 진행 |
| 작업 방식 | Coordinator, Builder, Verifier의 3롤 하네스 적용 |
| NFC 용어 | 기존 NEC 표기는 NFC로 해석 |

## 3. MVP 저장·서버 연동 정책

### 권장안: 앱 메모리 일시 처리

여권번호, 생년월일, 얼굴 사진, MRZ는 앱이 열려 있는 동안에만 메모리에 보관한다. 사용자가 취소·뒤로가기·삭제를 선택하거나 앱을 종료하면 결과를 제거한다.

- 서버에 전송하지 않는다.
- 휴대폰 파일·사진첩·데이터베이스에 저장하지 않는다.
- OCR 원문, MRZ, 사진, NFC APDU 전문을 로그에 남기지 않는다.
- 사용자는 이전 촬영 결과를 다시 조회할 수 없다.

| 선택지 | 설명 | MVP 적용 |
|---|---|---|
| A. 앱 메모리 일시 처리 | 앱 실행 중 확인만 가능하며 종료 시 삭제 | **채택 권장** |
| B. 기기 암호화 저장 | 기기에서 재조회 가능하지만 삭제·분실·백업 정책 필요 | 미적용 |
| C. 서버 전송·저장 | 업무 연계·관리자 조회가 가능하지만 동의·암호화·접근제어·보유기간 설계 필요 | 미적용 |

## 4. 1차 Flutter OCR MVP 범위

1. Android와 iOS에서 실행되는 Flutter 앱 골격
2. 카메라 권한 요청 및 실시간 카메라 프리뷰
3. 여권 데이터면과 MRZ 위치를 안내하는 가이드 창
4. 흐림, 반사광, 기울어짐, MRZ 미검출 상태 안내
5. 기기 내 OCR 및 MRZ TD3 파싱·체크섬 검증
6. 성명, 국적, 생년월일, 성별, 여권번호, 만료일, MRZ 원문 결과 화면
7. 촬영 이미지에서 얼굴 사진 영역을 보여주는 확인 화면
8. 취소·재촬영·오류 안내

### OCR 단계의 NFC 처리

NFC 칩 읽기 기능은 구현하지 않는다. NFC 버튼은 사용자 혼동을 막기 위해 1차 MVP에서는 표시하지 않는 방안을 권장한다.

## 5. 3롤 하네스 적용

| 역할 | 책임 | 파일 수정 권한 |
|---|---|---|
| Coordinator | 요구사항, 범위, 완료 기준, 승인 경계 관리 | 없음 |
| Builder | Flutter OCR 기능 구현, 테스트, 문서 갱신 | 있음 |
| Verifier | 독립 검증, 개인정보 비저장 확인, 회귀 확인 | 없음 |

작업 순서: `Coordinator → Builder → Verifier → Coordinator`

## 6. NFC 2차 착수 조건

아래 항목이 모두 통과되기 전에는 NFC 전자여권 기능을 시작하지 않는다.

- Android 실제 기기에 앱 설치·기동·카메라 OCR 수동 테스트 통과
- iPhone 실제 기기에 앱 설치·기동·카메라 OCR 수동 테스트 통과
- 카메라 가이드, 촬영, MRZ 검증, 결과 화면 테스트 통과
- 앱 종료 또는 취소 뒤 여권 정보와 사진이 남지 않음 확인
- Verifier 독립 검증 통과
- Coordinator의 OCR 단계 완료 확인

## 7. 검토가 필요한 결정

1. 초기 지원 범위를 한국 여권으로 제한할지 결정한다.
2. 얼굴 사진 영역은 단순 표시만 할지, 품질 평가까지 할지 결정한다.
3. OCR 단계에서 NFC 버튼을 숨길지, `준비 중`으로 표시할지 결정한다.
4. 테스트에 사용할 실제 여권·승인된 테스트 문서·기기 목록을 정한다.

## 8. 참고

- [기술 전체 명세](01_passport_reader_mobile_spec.md)
- [ICAO Doc 9303](https://www.icao.int/publications/doc-series/doc-9303)
- [Android ML Kit OCR](https://developer.android.com/codelabs/mlkit-android-translate)
- [Apple Core NFC](https://developer.apple.com/documentation/CoreNFC)
- [개인정보 수집·이용 동의서 기준](https://law.go.kr/LSW/flDownload.do?bylClsCd=200203&flNm=%5B%EB%B3%84%EC%A7%80+9%5D+%EA%B0%9C%EC%9D%B8%EC%A0%95%EB%B3%B4+%EC%88%98%EC%A7%91%C2%B7%EC%9D%B4%EC%9A%A9+%EB%8F%99%EC%9D%98%EC%84%9C%28%EC%84%9C%EC%8B%9D%29&flSeq=144642827)
