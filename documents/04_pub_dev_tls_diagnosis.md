---
title: pub.dev TLS 진단 기록
updated: 2026-10-02
status: blocked-external-network
---

# pub.dev TLS 진단 기록

## 결론

`pub.dev`에 대한 TLS 협상이 이 PC 또는 네트워크 경로에서 실패한다. 앱 코드·Dart 버전·DNS 설정만의 문제로 확인되지는 않았으며, 네트워크 보안 장비 또는 회선 경로 점검이 필요하다.

## 확인 결과

| 확인 항목 | 결과 |
|---|---|
| `pub.dev` DNS (기본/1.1.1.1/8.8.8.8) | 모두 `34.36.0.14` 반환 |
| TCP 443 | 연결 성공 |
| `curl https://pub.dev` | Schannel `SEC_E_INVALID_TOKEN` 실패 |
| OpenSSL SNI TLS | `packet length too long` 실패 |
| `www.google.com` OpenSSL TLS | TLS 1.3 정상 |
| Google Cloud Storage HTTPS | 정상 응답 |
| WinHTTP 프록시 | 직접 연결 |

## 필요한 외부 조치

1. 네트워크 관리자에게 `pub.dev:443` TLS/SNI 통과 여부와 HTTPS 검사 예외 정책을 확인 요청한다.
2. 조직 프록시가 필수라면 사용자 계정의 운영 환경 변수 대신 조직 표준 네트워크 설정으로 적용한다.
3. 조치 뒤 `flutter pub get`, `flutter analyze`, `flutter test`를 순서대로 재실행한다.

## 재시도 기록 (2026-10-02)

- `curl https://pub.dev/api/packages/camera`는 다시 `SEC_E_INVALID_TOKEN`으로 실패했다.
- `flutter pub get`은 의존성 해결 시작 후 완료하지 못했으며, `pubspec.lock`과 `.dart_tool/package_config.json`은 생성되지 않았다.
- 따라서 방화벽 또는 HTTPS 검사 정책의 실제 변경 여부를 네트워크 관리자에게 다시 확인해야 한다.

## 재시도 기록 2 (2026-10-02)

- `flutter pub get` 재실행 결과 `google_mlkit_text_recognition` 조회에서 `Got TLS error trying to find package ... at https://pub.dev`로 실패했다.
- `pub.dev` HTTPS 443의 단순 포트 허용과 별개로 TLS/SNI 또는 HTTPS 검사 예외가 여전히 적용되지 않은 것으로 판단한다.

## 복구 확인 (2026-10-02)

- `https://pub.dev/api/packages/camera` 요청이 HTTP 200으로 응답했다.
- `flutter pub get`이 성공해 `camera 0.11.4`, `google_mlkit_text_recognition 0.16.0`을 포함한 39개 의존성을 설치했다.
- 이후 정적 분석은 Flutter 도구 프로세스가 출력 없이 멈춰 종료했으므로, 별도 검증 단계에서 재실행한다.

## 보안 원칙

인증서 검증 비활성화, 임의 호스트 파일 변경, 비공식 패키지 미러, 운영 환경 변수 우회는 적용하지 않았다.
