---
title: "여권 OCR 및 전자여권 NFC 판독 모바일 앱 명세"
status: draft
updated: 2026-10-01
---

# 여권 OCR 및 전자여권 NFC 판독 모바일 앱 명세

## 1. 목적과 전제

Android와 iOS에서 동작하는 하이브리드 모바일 앱으로, 카메라로 여권의 시각 정보와 MRZ를 인식하고 NFC로 전자여권 칩의 정보를 읽어 화면에서 비교·확인한다.

- 본 문서의 `NEC`는 NFC를 의미하는 것으로 해석한다.
- 카메라 OCR 결과와 전자여권 칩 데이터는 서로 다른 출처로 관리한다.
- 기본 MVP는 서버 전송이나 영구 저장 없이 앱에서 일시적으로 확인하는 흐름을 기준으로 한다.

## 2. 기능 요구사항

| ID | 기능 | 완료 기준 |
|---|---|---|
| FR-01 | 카메라 여권 촬영 | 여권 데이터면과 MRZ가 가이드 창 안에 들어온 상태에서 촬영할 수 있다. |
| FR-02 | 촬영 품질 안내 | 흐림, 반사광, 기울어짐, MRZ 미검출 상태를 안내한다. |
| FR-03 | OCR 및 MRZ 파싱 | 인적사항, 여권번호, 만료일, MRZ를 인식하고 MRZ 체크섬을 검증한다. |
| FR-04 | 카메라 결과 확인 | OCR 인적사항, 추출 사진, MRZ 원문 및 검증 상태를 표시한다. |
| FR-05 | NFC 전자여권 읽기 | NFC 위치 안내 후 BAC/PACE 절차로 전자여권 칩에 접근한다. |
| FR-06 | 전자여권 결과 확인 | DG1 인적사항, DG2 얼굴 사진, 칩 MRZ 파싱 결과를 표시한다. |
| FR-07 | 결과 비교 | 카메라 OCR과 칩 데이터의 일치·불일치를 항목별로 표시한다. |
| FR-08 | 오류 처리 | NFC 미지원, 칩 미감지, 인증 실패, 사진 디코딩 실패를 사용자에게 안내한다. |

## 3. 사용자 화면 흐름

```text
카메라 촬영
  → 품질 검사 및 OCR/MRZ 인식
  → 카메라 결과 확인
  → "전자여권 NFC 읽기" 선택
  → 휴대폰과 여권 접촉 안내
  → NFC 연결·보안 인증·칩 데이터 읽기
  → 전자여권 결과 및 카메라 결과 비교
```

### 3.1 카메라 촬영 화면

- 여권 데이터면 비율의 가이드 창을 표시한다.
- 자동 촬영 조건: 문서 경계 검출, 충분한 선명도, MRZ 영역 검출, 과도한 반사광 없음.
- 수동 촬영 버튼과 촬영 실패 안내를 제공한다.

### 3.2 카메라 결과 확인 화면

- 성명, 국적, 생년월일, 성별, 여권번호, 발급국, 만료일을 표시한다.
- 촬영 이미지에서 추출한 얼굴 영역을 표시한다.
- MRZ 원문과 체크섬 검증 결과를 표시한다.
- `전자여권 NFC 읽기` 버튼을 표시한다.

### 3.3 NFC 읽기 화면

- "휴대폰 뒷면의 NFC 위치를 여권 표지 또는 데이터면에 밀착하세요"라는 안내를 표시한다.
- 진행 상태를 `NFC 감지 → 보안 인증 → DG1 읽기 → DG2 읽기 → 검증`으로 표시한다.
- 사용자가 중단하거나 재시도할 수 있어야 한다.

### 3.4 전자여권 결과 화면

- DG1에서 파싱한 인적사항과 MRZ 데이터를 표시한다.
- DG2에서 추출한 전자여권 얼굴 사진을 표시한다.
- OCR 결과와 칩 결과의 일치·불일치를 표시한다.
- 전자서명 검증을 구현하는 단계에서는 SOD 검증 상태를 함께 표시한다.

## 4. 기술 아키텍처

### 4.1 권장 구조

| 계층 | 권장 역할 |
|---|---|
| 하이브리드 UI | Flutter 또는 React Native로 카메라, 화면, 상태 관리 구현 |
| OCR/MRZ | 기기 내 문서·텍스트 인식 엔진과 MRZ 파서·체크섬 검증 모듈 |
| Android NFC | `IsoDep` 기반 ISO 14443-4 APDU 통신 모듈 |
| iOS NFC | Core NFC의 ISO 7816 태그 세션과 entitlement/AID 설정 모듈 |
| 전자여권 프로토콜 | EF.COM, DG1, DG2, SOD, BAC/PACE, 선택적 Chip Authentication 처리 |
| 보안 | 메모리 내 일시 처리, 화면 종료 시 민감 데이터 제거, 로그 마스킹 |

하이브리드 프레임워크는 UI와 공통 업무 로직에 사용하되, NFC APDU 통신은 플랫폼별 네이티브 모듈로 구현한다.

### 4.2 권장 기술 스택

| 영역 | 권장 기술 | 선택 기준 |
|---|---|---|
| 하이브리드 앱 | Flutter (Dart) | 단일 UI 코드베이스와 카메라 오버레이 구현에 적합. React Native도 팀의 TypeScript 역량이 높다면 대안으로 사용 가능. |
| 상태 관리 | Flutter: Riverpod 또는 Bloc | 카메라·NFC의 비동기 단계와 오류·재시도 상태를 명확히 관리. |
| 카메라 | Flutter `camera` + 플랫폼 카메라 API | 실시간 프리뷰, 가이드 프레임, 자동 촬영 품질 검사. |
| OCR/MRZ | Google ML Kit Text Recognition + 자체 MRZ 파서 | 기기 내 텍스트 인식과 ICAO TD3 체크섬 검증. iOS는 Vision 보조 사용 가능. |
| Android NFC | Kotlin + Android `IsoDep` | ISO 14443-4, ISO-DEP APDU 통신과 NFC 권한 처리. |
| iOS NFC | Swift + Core NFC `NFCTagReaderSession` / `NFCISO7816Tag` | ISO 7816 APDU 통신, NFC entitlement 및 AID 설정. |
| 전자여권 프로토콜 | 검증된 eMRTD 라이브러리 또는 자체 네이티브 모듈 | BAC/PACE, LDS, DG1, DG2, SOD 처리. 라이선스·국가별 호환성을 사전 검토. |
| 사진 디코딩 | JPEG 및 JPEG2000 지원 모듈 | DG2 이미지 포맷 차이에 대응. |
| 보안 저장소 | iOS Keychain / Android Keystore | 장기 보관이 승인된 경우에만 암호화 키와 최소 메타데이터 보관. |
| 서버 연동 | MVP 제외, 필요 시 HTTPS API | 서버 전송은 개인정보 영향 평가와 보관 정책 확정 후 도입. |

### 4.3 개발·테스트 환경

| 구분 | 권장 환경 |
|---|---|
| 개발 OS | macOS 권장: iOS 빌드와 Android 개발을 한 환경에서 처리. Windows는 Android 개발만 가능. |
| IDE | Android Studio 최신 안정판, Xcode 최신 안정판, VS Code 또는 Android Studio의 Flutter/Dart 플러그인 |
| 언어 | Dart(공통 앱), Kotlin(Android NFC), Swift(iOS NFC) |
| Android 최소 환경 | Android API 26 이상을 초기 기준으로 검토, NFC 지원 실제 기기 필요 |
| iOS 최소 환경 | Core NFC를 지원하는 실제 iPhone 필요. Simulator에서는 NFC 판독 검증 불가 |
| 테스트 문서 | 개발·테스트용 유효 여권 또는 승인된 테스트 전자여권만 사용. 실제 여권 데이터는 로그·테스트 저장소에 남기지 않음 |
| CI | GitHub Actions, GitLab CI 또는 사내 CI에서 정적 분석·단위 테스트·서명 전 빌드 수행 |
| 배포 | Android App Bundle과 iOS Archive를 분리 생성. 서명 키·인증서는 비밀 관리 시스템에서 관리 |

### 4.4 데이터 출처

| 데이터 | 출처 | 처리 |
|---|---|---|
| 인적사항 OCR | 카메라 이미지 | OCR 후 MRZ 체크섬 검증 |
| 카메라 사진 | 카메라 이미지 | 얼굴 영역 추출, 품질 상태 표시 |
| 칩 인적사항 | DG1 | LDS 데이터 파싱 |
| 전자여권 사진 | DG2 | 이미지 포맷 해석 후 표시 |
| 전자여권 보안 | SOD, CSCA 인증서 | 서명·신뢰 체인 검증은 후속 단계 |

## 5. 전자여권 NFC 처리

1. 카메라에서 읽은 MRZ의 여권번호, 생년월일, 만료일을 검증한다.
2. NFC 세션을 시작하고 사용자가 여권에 휴대폰을 접촉하도록 안내한다.
3. MRZ에서 파생한 접근 정보를 사용해 BAC 또는 PACE를 수행한다.
4. 전자여권 파일 목록을 확인하고 DG1, DG2를 읽는다.
5. DG1의 인적사항과 DG2의 사진을 파싱해 화면에 표시한다.
6. 선택적으로 SOD와 신뢰할 수 있는 CSCA 인증서를 사용해 데이터 무결성과 발급국 서명을 검증한다.

ICAO Doc 9303에 따르면 칩 접근 제어는 광학적으로 읽은 MRZ 정보에 기반하며, BAC와 PACE가 전자여권의 주요 접근 제어 방식이다.

## 6. 개인정보·보안 요구사항

- 여권번호, 생년월일, 얼굴 사진, MRZ, NFC 칩 데이터는 민감한 개인정보로 취급한다.
- 사용자 동의 화면에서 처리 목적, 저장 여부, 전송 여부를 명확히 알린다.
- MVP 기본값은 기기 내 메모리에서만 처리하고 결과 화면 종료 또는 명시적 삭제 시 데이터를 제거한다.
- OCR 원문, MRZ, APDU 전문, 사진을 애플리케이션 로그에 남기지 않는다.
- 서버 연동이 필요해지면 전송 암호화, 저장 암호화, 접근 제어, 보유 기간, 삭제 절차를 별도 설계한다.

## 7. 단계별 개발 범위

| 단계 | 범위 | 결과 |
|---|---|---|
| 0 | 요구사항·개인정보 정책·지원 여권 범위 확정 | 승인된 기능 명세 |
| 1 | 카메라 가이드, OCR, MRZ 파싱·체크섬 | 카메라 결과 확인 화면 |
| 2 | Android/iOS NFC 세션, BAC/PACE, DG1 | 칩 인적사항 확인 |
| 3 | DG2 사진 디코딩·표시, OCR/칩 비교 | 통합 결과 화면 |
| 4 | SOD·CSCA 기반 전자서명 검증 | 진위·무결성 검증 상태 |
| 5 | 실제 여권·지원 기기 매트릭스 시험 | 릴리스 검증 보고서 |

## 8. 리스크와 검증 항목

| 리스크 | 대응 |
|---|---|
| NFC 미지원 기기 | 기능 시작 전 NFC 지원 여부를 확인하고 대체 안내를 표시한다. |
| iOS NFC 권한·AID 설정 누락 | 실제 iPhone에서 entitlement와 ISO 7816 AID 설정을 검증한다. |
| 국가별 여권 차이 | 초기에는 지원 국가와 여권 유형을 명시하고 실제 표본으로 검증한다. |
| DG2 사진 포맷 차이 | JPEG/JPEG2000 등 지원 범위와 디코더 정책을 정의한다. |
| OCR 오류 | MRZ 체크섬, 재촬영 안내, NFC 데이터와 비교로 보완한다. |
| 개인정보 유출 | 비저장 기본 정책, 로그 마스킹, 삭제 흐름을 적용한다. |

## 9. 구현 착수 전 결정 필요 항목

1. `NEC`가 NFC를 의미하는지 확정한다.
2. 초기 지원 대상: 한국 여권만인지, 다국가 여권까지인지 결정한다.
3. 데이터 처리 정책: 기기 내 일시 처리만인지, 서버 전송·저장이 필요한지 결정한다.
4. 하이브리드 프레임워크: Flutter 또는 React Native를 결정한다.
5. 전자서명 검증을 MVP에 포함할지 후속 단계로 둘지 결정한다.

## 10. 참고 기준

- [ICAO Doc 9303 — Machine Readable Travel Documents](https://www.icao.int/publications/doc-series/doc-9303)
- [ICAO Doc 9303 Part 11 — Security Mechanisms](https://www.icao.int/publications/documents/9303_p11_cons_en.pdf)
- [Android IsoDep API](https://developer.android.com/reference/android/nfc/tech/IsoDep)
- [Apple Core NFC](https://developer.apple.com/documentation/CoreNFC)
- [Apple NFCISO7816Tag](https://developer.apple.com/documentation/corenfc/nfciso7816tag)
- [Google ML Kit Text Recognition](https://developers.google.com/ml-kit/vision/text-recognition)
