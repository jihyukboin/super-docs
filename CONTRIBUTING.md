# 기여 안내

Super Docs는 개인이 개발·관리하는 오픈소스 프로젝트입니다. MIT 라이선스에 따라 코드를 읽고, 수정하고, 포크하여 자신의 버전을 만들 수 있습니다. 다만 모든 외부 코드 기여를 수용하는 프로젝트는 아닙니다.

## Issue에서 먼저 논의해 주세요

버그 수정이나 기능 추가를 구현하기 전에 기존 Issue를 검색하고, 관련 Issue에서 관리자와 범위 및 접근 방법을 논의해 주세요. 사전 합의가 없는 PR은 검토 없이 닫힐 수 있습니다. 번역·오탈자·작은 문서 수정은 사전 논의 없이 제안할 수 있습니다.

버그 보고에는 macOS 버전, Mac 모델과 칩, 앱 버전, 재현 단계, 기대한 결과와 실제 결과를 포함해 주세요. 문서가 필요하면 개인정보와 기밀을 제거한 최소 재현 파일만 첨부해 주세요.

## Pull request

- 관련 Issue와 합의한 변경 범위를 적어 주세요.
- 현재 문제를 해결하는 최소한의 변경으로 유지해 주세요.
- 변경에 맞는 검증을 실행하고 결과 및 미검증 항목을 적어 주세요. `npm ci`, `npm run build`, `npm test`, `bash scripts/test-native.sh`, `python3 tests/release/test_release.py`로 빌드·테스트할 수 있습니다. Apple Silicon Mac, macOS 14 이상, Xcode Command Line Tools, Node.js 24와 Google Chrome이 필요합니다.
- 원본 문서, 인증서, 비밀정보, 빌드 산출물은 커밋하지 마세요.
- 새 의존성이나 리소스의 라이선스를 확인하고 필요한 고지를 유지해 주세요.

코드 기여는 프로젝트의 MIT 라이선스로 제공됩니다. 병합 여부와 릴리스 일정은 관리자가 결정하며, 응답·수정 일정을 보장하지 않습니다.

## 디렉토리와 책임

- `Sources/SuperDocs/App/`: 앱 생명주기, macOS 메뉴, 업데이트 및 오류 표시.
- `Sources/SuperDocs/Documents/`: 문서 열기 경로, 파일 상태·저장, 편집기와 창 사이의 최소 계약.
- `Sources/SuperDocs/Windows/`: 공통 문서 창, 저장 패널, 변경 사항 확인.
- `Sources/SuperDocs/Formats/HWP/`: HWP/HWPX 타입과 빈 문서 리소스 로딩.
- `Sources/SuperDocs/Formats/DOCX/`: DOCX 타입.
- `Sources/SuperDocs/Web/`: 로컬 자산 서버, 공통 WebKit 편집기와 클립보드 연결.
- `web/hwp/`: RHWP Studio에 삽입하는 브리지, 붙여넣기 패치와 스타일. 독립 실행형 웹 앱이 아닙니다.
- `web/docx/`, `scripts/docx/`, `tests/docx/`: DOCX 편집기 브리지·한국어 도구, 번들링·라이선스 수집, 저장 왕복 검증.
- `Resources/HWP/`: HWP 전용 서식. 앱 아이콘·Info.plist·라이선스는 `Resources/`에 둡니다.
- `scripts/hwp/`: 고정된 RHWP 소스 취득·패치·번들링 및 빈 문서 생성.
- `tests/native/`, `tests/hwp/`, `tests/release/`: 네이티브 문서·서버, HWP 엔진·브라우저, 배포 테스트.

`main.swift`는 앱 실행만 담당합니다. `DocumentOpener`가 형식별 편집기를 선택하고, `DocumentWindowController`는 `DocumentEditor`를 통해 편집기를 사용합니다. 파일 상태와 원자적 쓰기·외부 변경 검사는 `DocumentSession`이, 문서 직렬화와 RHWP 내부 호출은 `WebDocumentEditor`와 포맷별 웹 브리지가 담당합니다. 저장은 파일 쓰기와 편집기의 저장 완료 처리가 성공한 뒤 변경 상태를 해제합니다.

Swift 파일은 주 타입 이름으로, 웹 파일과 빌드 스크립트는 기존의 소문자 하이픈 형식으로 명명합니다. `scripts/build-app.sh`는 Swift 하위 디렉토리를 재귀적으로 수집합니다. 빌드 산출물은 `.build/`와 `dist/`에만 둡니다.

새 형식은 실제 구현 시 `Formats/` 아래에 추가하고 `DocumentOpener`에 연결합니다. 웹 엔진을 사용할 때만 `web/<형식>/`이 필요합니다. 아직 지원하지 않는 형식의 빈 폴더나 플러그인 체계는 만들지 않습니다. 보기 전용 지원은 해당 형식을 구현할 때 메뉴·저장 가능 여부와 함께 계약을 보완합니다.

기존 명령 `npm run build`, `npm test`, `bash scripts/test-native.sh`는 그대로 사용합니다. 배포 테스트는 `python3 tests/release/test_release.py`, HWP 파일의 독립 포맷 검증은 `python3 tests/hwp/verify-files.py`입니다. 독립 포맷 검증에는 별도 개발 환경의 `olefile==0.47`이 필요하며, `npm test`가 생성한 파일을 검사합니다.

## 배포 빌드

Developer ID Application 인증서와 개인키, 검증된 `notarytool` 키체인 프로필이 필요합니다. 다음 명령은 앱과 DMG의 빌드·서명·공증·티켓 부착 및 Gatekeeper 검증을 수행합니다. 결과는 `dist/release/<버전>/`에 생성되며 자동 업로드하지 않습니다. 로컬 배포 전에는 위 빌드·테스트를 먼저 실행하세요.

```sh
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='super-docs-notary' \
SPARKLE_KEY_FILE="$PWD/secrets/sparkle-ed25519.key" \
bash scripts/release-macos.sh
```

인증서 파일은 Git에서 제외된 `secrets/`에 보관하고 개인키와 공증 암호는 macOS 키체인에 보관합니다.

## dev → main 자동 배포

1. `dev`에서 작업하고 CI를 통과한 뒤 같은 저장소의 `dev → main` PR을 병합합니다.
2. `Release macOS`는 Linux에서 최신 공개 태그 이후의 변경을 확인합니다. 문서만 바뀌었다면 macOS 작업과 새 릴리스를 생략합니다. 앱 변경이 있으면 병합 커밋을 빌드하고, 최신 공개 태그의 패치 버전을 하나 올립니다. `CFBundleVersion`과 표시 버전에 같은 버전을 넣습니다. 소스의 `package.json` 버전은 로컬 빌드의 기본값입니다.
3. Sparkle 프레임워크 내부 도구부터 앱까지 Developer ID로 서명하고, 앱·DMG를 Apple에 공증 제출합니다. 티켓·Gatekeeper 검사 후 DMG의 Sparkle EdDSA 서명과 `appcast.xml`을 생성합니다.
4. DMG·SHA-256·appcast를 초안 릴리스에 업로드한 뒤 모두 준비되면 공개합니다. 앱은 `https://github.com/jihyukboin/super-docs/releases/latest/download/appcast.xml`에서 업데이트를 확인합니다.

`main` 직접 푸시, 병합하지 않고 닫은 PR, 다른 브랜치·포크 PR은 배포하지 않습니다. 실패한 작업은 재실행하거나 `main`에서 수동 실행할 수 있습니다. 이미 공개한 커밋은 재배포하지 않고, 더 최신 병합이 있으면 오래된 작업을 건너뜁니다. 진행 중인 배포는 취소하지 않습니다.

GitHub repository Secrets:

- `MACOS_CERTIFICATE_P12_BASE64`: Developer ID Application 인증서와 개인키를 담은 암호화된 P12의 Base64
- `MACOS_CERTIFICATE_PASSWORD`: P12 암호
- `APPLE_NOTARY_PASSWORD`: IMGOBOT 팀의 Apple 계정 공증용 앱 전용 암호
- `SPARKLE_PRIVATE_KEY`: `SUPublicEDKey`와 짝을 이루는 EdDSA 키

작업은 임시 키체인을 만들고 마지막 단계에서 키체인과 임시 키 파일을 삭제합니다. Sparkle 2.10.0 배포 파일의 SHA-256은 빌드 스크립트에 고정되어 있습니다. 프레임워크를 올릴 때 체크섬과 라이선스도 함께 갱신하세요. 기존 사용자에게 업데이트를 제공하려면 EdDSA 키를 유지해야 합니다.

CI는 `dev` 또는 `main`으로 향하는 PR에서 한 번 실행하며 새 커밋이 올라오면 이전 실행을 취소합니다. 기능 기여 PR은 `dev`를 대상으로 해 주세요. `main` PR은 같은 저장소의 `dev`만 허용합니다. 배포 단계에서는 이미 통과한 테스트를 반복하지 않고 서명·공증·Gatekeeper·업데이트 서명과 공개 파일 검사를 수행합니다.

`main` 보호 규칙은 [.github/main-protection.json](.github/main-protection.json)에 기록합니다. 최신 `main` 기준 CI 통과와 PR 병합, 대화 해결을 요구하고 관리자에게도 적용합니다. 강제 푸시·삭제는 금지하며, 1인 운영을 위해 다른 사람의 승인 수는 0입니다. `build-and-test`는 GitHub Actions가 제공한 검사만 인정합니다.

Apple CloudKit 연결 오류(68)는 티켓 부착 때 제한적으로 재시도합니다. `stapler validate`도 서버에 접속하므로 중복 호출하지 않습니다. 잘못되었거나 취소된 티켓은 재시도로 무시하지 않습니다.

참고: [Sparkle 설정](https://sparkle-project.org/documentation/), [프로그램에서 초기화](https://sparkle-project.org/documentation/programmatic-setup/), [내부 도구 서명](https://sparkle-project.org/documentation/sandboxing/), [GitHub PR 병합 이벤트](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#running-your-pull_request-workflow-when-a-pull-request-merges).

### CI 실행 시간

문서 전용 변경은 Linux에서 분류·배포 정책 테스트를 실행하고 동일한 필수 검사 이름 `build-and-test`로 결과를 보고합니다. `README.md`, `CONTRIBUTING.md`, `AGENTS.md`, Issue/PR 템플릿, `docs/*.md`만 예외입니다. 앱에 포함되는 라이선스·리소스, 코드·의존성·워크플로·테스트 변경과 알 수 없는 파일은 전체 macOS 검증을 실행합니다. 분류 실패는 필수 검사 실패로 처리하며, 수동 CI는 항상 전체 검증합니다.

macOS CI는 기존 npm 캐시와 전체 빌드·테스트를 유지합니다. 외부 소스 캐시와 테스트 병렬화는 측정에서 단축 효과가 확인되지 않아 적용하지 않습니다. 배포의 앱·DMG 공증, 티켓 부착, Gatekeeper 및 Sparkle 서명 검증도 유지합니다.

문서 전용 배포 생략은 해당 PR만 비교하지 않고 최신 공개 태그와 비교합니다. 따라서 아직 릴리스되지 않은 앱 변경이 누적되어 있으면, 마지막 PR이 문서 변경이어도 앱을 배포합니다. 실행 시간은 러너 대기와 Apple 공증 응답에 따라 달라지며, 일반 앱 빌드의 단축은 보장하지 않습니다.
