---
title: Flutter OCR MVP 구현 기록
updated: 2026-10-01
status: implementation-review
---

# Flutter OCR MVP 구현 기록

## 구현 범위

- Flutter 앱 골격과 Android/iOS 카메라 권한 문구를 추가했다.
- 후면 카메라 미리보기, 여권 데이터면 가이드 프레임, 촬영 버튼을 구현했다.
- 촬영 이미지에 Google ML Kit Latin OCR을 적용하고 ICAO TD3 MRZ 두 줄을 파싱한다.
- 문서번호·생년월일·만료일·개인번호·복합 체크디지트를 검증한다.
- 결과 화면을 닫으면 카메라 플러그인이 생성한 임시 이미지 파일을 삭제하도록 구현했다.
- NFC 패키지·권한·버튼은 포함하지 않았다.

## 검증 현황

| 항목 | 결과 | 비고 |
|---|---|---|
| Dart 포맷 | 통과 | `dart format lib test` |
| 의존성 설치 | 보류 | `pub.dev` 연결 중 TLS 오류 (`camera` 패키지) |
| 정적 분석·단위 테스트 | 보류 | 의존성 설치 완료 후 실행 필요 |
| Android/iOS 실기기 OCR | 미실행 | 빌드 출력 경로 지정 후 수행 |

## 남은 제한

- 현재 결과 화면은 촬영한 여권 데이터면 전체 이미지를 표시한다. 얼굴 영역 자동 추출은 OCR MVP 실기기 검증 후 별도 기능으로 추가한다.
- OCR은 라틴 문자 MRZ용으로 구성했다. 한글 인적사항 OCR은 MVP 범위 밖이다.
- 실제 빌드·설치는 사용자 지정 표준 빌드 출력 경로가 정해진 뒤에만 수행한다.

## Verifier 검토 반영

- iOS 배포 대상을 ML Kit 요구사항에 맞춰 15.5로 상향하고 `ios/Podfile`에 같은 최소 버전을 지정했다.
- Verifier는 NFC 범위 미포함, 카메라 권한, OCR 서비스 분리, 체크디지트 파서, 임시 파일 정상 흐름 삭제를 확인했다.
- TLS 오류로 의존성 설치·분석·단위 테스트·실기기 검증은 아직 통과 처리하지 않는다.

## 표준 빌드 산출물 경로 (2026-10-02 확정)

사용자는 별도 `artifacts` 폴더를 만들지 않고 Flutter 기본 출력 방식을 표준으로 지정했다. 프로젝트 루트는 `C:\WorkSpaces_Codex\passport-reader-mobile`이다.

| 대상 | Debug 표준 경로 | Release 표준 경로 |
|---|---|---|
| Android APK | `C:\WorkSpaces_Codex\passport-reader-mobile\build\app\outputs\flutter-apk\app-debug.apk` | `C:\WorkSpaces_Codex\passport-reader-mobile\build\app\outputs\flutter-apk\app-release.apk` |
| Android App Bundle | 해당 없음 | `C:\WorkSpaces_Codex\passport-reader-mobile\build\app\outputs\bundle\release\app-release.aab` |
| Windows | `C:\WorkSpaces_Codex\passport-reader-mobile\build\windows\x64\runner\Debug` | `C:\WorkSpaces_Codex\passport-reader-mobile\build\windows\x64\runner\Release` |
| iOS | macOS의 Xcode DerivedData 영역 | macOS의 Xcode Archive 또는 IPA 출력 |

이 결정은 산출물 출력 위치만 지정하며, 빌드·실행·설치 권한은 각 요청에서 별도로 확인한다.

## Flutter 도구 진단 및 Android Debug 빌드 시도 (2026-10-02)

- `flutter analyze --no-pub`과 `dart analyze`는 Flutter SDK 도구 부팅 또는 분석 시작 뒤 출력·CPU 활동 없이 멈췄다.
- 잔여 Flutter 프로세스를 정리한 뒤 표준 경로의 `flutter build apk --debug`를 재시도했으나, Gradle 단계 전 Flutter SDK 도구 부팅에서 다시 멈췄다.
- 결과: `C:\WorkSpaces_Codex\passport-reader-mobile\build\app\outputs\flutter-apk\app-debug.apk`는 생성되지 않았다.
- 판단: 앱 소스·패키지 설치가 아닌 로컬 Flutter SDK 도구 실행 환경 문제로 보고 SDK 재설치 또는 보안 제품의 Dart/Flutter 실행 검사 예외를 확인한다.

## Null-safety 분석 오류 수정 (2026-10-02)

- 오류: `passport_camera_page.dart`에서 nullable `XFile?`의 `path`를 결과 화면 전달 시 직접 참조해 정적 분석 오류가 발생했다.
- 수정: `takePicture()` 결과를 non-null 지역 변수 `capturedImage`으로 분리하고, OCR·결과 화면에는 해당 변수를 사용했다. nullable 변수는 임시 파일 정리 용도로만 유지한다.
- 검증: `dart analyze lib\\pages\\passport_camera_page.dart` 결과 `No issues found!`.

## 전체 정적 분석 통과 (2026-10-02)

- 사용자 실행 결과: `flutter analyze`
- 결과: `No issues found! (ran in 40.3s)`
- 결론: Flutter 프로젝트 전체에 정적 분석 오류가 없다.

## Android Debug APK 빌드 네트워크 오류 (2026-10-02)

- 사용자 실행 `flutter build apk --debug`가 Gradle Wrapper의 HTTPS 다운로드 단계에서 `javax.net.ssl.SSLException: Unsupported or unrecognized SSL message`로 실패했다.
- 프로젝트의 `android/gradle/wrapper/gradle-wrapper.properties`는 `https://services.gradle.org/distributions/gradle-8.14-all.zip`을 사용한다.
- 로컬 HTTPS 점검도 `services.gradle.org`에 대해 `SEC_E_INVALID_TOKEN`으로 실패했다.
- 결과: Debug APK 표준 경로 `build/app/outputs/flutter-apk/app-debug.apk`에는 산출물이 생성되지 않았다.
- 조치: 네트워크 정책에서 `services.gradle.org` 및 Gradle 배포 리디렉션 호스트의 TLS/SNI HTTPS 443 통과를 확인한다.

## Gradle 캐시 접근 거부 진단 (2026-10-02)

- Gradle Wrapper 다운로드 이후 설정 조회를 실행한 결과, Flutter 플러그인 로더 오류의 실제 원인은 Gradle 캐시 이동 실패로 확인됐다.
- 근본 예외: `java.nio.file.AccessDeniedException`.
- 대상: `C:\Users\jwbaek\.gradle\caches\8.14\transforms` 아래 임시 transform 작업 영역을 최종 immutable 캐시 위치로 이동하는 과정.
- 관찰: 해당 캐시를 사용 중일 수 있는 Java 프로세스가 존재한다.
- 다음 조치: 사용자 승인을 받은 뒤 Gradle/Java 프로세스를 종료하고, 위 버전별 `transforms` 캐시만 삭제해 재생성한 뒤 빌드를 재시도한다. 전체 `.gradle` 폴더와 프로젝트 소스는 삭제하지 않는다.
