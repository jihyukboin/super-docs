# 기여 안내

Super Docs는 개인이 개발·관리하는 오픈소스 프로젝트입니다. MIT 라이선스에 따라 코드를 읽고, 수정하고, 포크하여 자신의 버전을 만들 수 있습니다. 다만 모든 외부 코드 기여를 수용하는 프로젝트는 아닙니다.

## Issue에서 먼저 논의해 주세요

버그 수정이나 기능 추가를 구현하기 전에 기존 Issue를 검색하고, 관련 Issue에서 관리자와 범위 및 접근 방법을 논의해 주세요. 사전 합의가 없는 PR은 검토 없이 닫힐 수 있습니다. 번역·오탈자·작은 문서 수정은 사전 논의 없이 제안할 수 있습니다.

버그 보고에는 macOS 버전, Mac 모델과 칩, 앱 버전, 재현 단계, 기대한 결과와 실제 결과를 포함해 주세요. 문서가 필요하면 개인정보와 기밀을 제거한 최소 재현 파일만 첨부해 주세요.

## Pull request

- 관련 Issue와 합의한 변경 범위를 적어 주세요.
- 현재 문제를 해결하는 최소한의 변경으로 유지해 주세요.
- 변경에 맞는 검증을 실행하고 결과 및 미검증 항목을 적어 주세요. `npm ci`, `npm run build`, `npm test`, `bash scripts/test-native.sh`, `python3 tests/test-release.py`로 빌드·테스트할 수 있습니다. Apple Silicon Mac, macOS 14 이상, Xcode Command Line Tools, Node.js 24와 Google Chrome이 필요합니다.
- 원본 문서, 인증서, 비밀정보, 빌드 산출물은 커밋하지 마세요.
- 새 의존성이나 리소스의 라이선스를 확인하고 필요한 고지를 유지해 주세요.

코드 기여는 프로젝트의 MIT 라이선스로 제공됩니다. 병합 여부와 릴리스 일정은 관리자가 결정하며, 응답·수정 일정을 보장하지 않습니다.

## 배포 빌드

Developer ID Application 인증서와 개인키, 검증된 `notarytool` 키체인 프로필이 필요합니다. 다음 명령은 앱과 DMG의 서명·공증·티켓 부착 및 Gatekeeper 검증을 수행합니다. 결과는 `dist/release/<버전>/`에 생성되며 자동 업로드하지 않습니다.

```sh
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='super-docs-notary' \
SPARKLE_KEY_FILE="$PWD/secrets/sparkle-ed25519.key" \
bash scripts/release-macos.sh
```

인증서 파일은 Git에서 제외된 `secrets/`에 보관하고 개인키와 공증 암호는 macOS 키체인에 보관합니다.

## dev → main 자동 배포

1. `dev`에서 작업하고 CI를 통과한 뒤 같은 저장소의 `dev → main` PR을 병합합니다.
2. `Release macOS`가 병합 커밋을 빌드하고, 최신 공개 태그의 패치 버전을 하나 올립니다. `CFBundleVersion`과 표시 버전에 같은 버전을 넣습니다. 소스의 `package.json` 버전은 로컬 빌드의 기본값입니다.
3. Sparkle 프레임워크 내부 도구부터 앱까지 Developer ID로 서명하고, 앱·DMG를 Apple에 공증 제출합니다. 티켓·Gatekeeper 검사 후 DMG의 Sparkle EdDSA 서명과 `appcast.xml`을 생성합니다.
4. DMG·SHA-256·appcast를 초안 릴리스에 업로드한 뒤 모두 준비되면 공개합니다. 앱은 `https://github.com/jihyukboin/super-docs/releases/latest/download/appcast.xml`에서 업데이트를 확인합니다.

`main` 직접 푸시, 병합하지 않고 닫은 PR, 다른 브랜치·포크 PR은 배포하지 않습니다. 실패한 작업은 재실행하거나 `main`에서 수동 실행할 수 있습니다. 이미 공개한 커밋은 재배포하지 않고, 더 최신 병합이 있으면 오래된 작업을 건너뜁니다. 진행 중인 배포는 취소하지 않습니다.

GitHub repository Secrets:

- `MACOS_CERTIFICATE_P12_BASE64`: Developer ID Application 인증서와 개인키를 담은 암호화된 P12의 Base64
- `MACOS_CERTIFICATE_PASSWORD`: P12 암호
- `APPLE_NOTARY_PASSWORD`: IMGOBOT 팀의 Apple 계정 공증용 앱 전용 암호
- `SPARKLE_PRIVATE_KEY`: `SUPublicEDKey`와 짝을 이루는 EdDSA 키

작업은 임시 키체인을 만들고 마지막 단계에서 키체인과 임시 키 파일을 삭제합니다. Sparkle 2.10.0 배포 파일의 SHA-256은 빌드 스크립트에 고정되어 있습니다. 프레임워크를 올릴 때 체크섬과 라이선스도 함께 갱신하세요. 기존 사용자에게 업데이트를 제공하려면 EdDSA 키를 유지해야 합니다.

참고: [Sparkle 설정](https://sparkle-project.org/documentation/), [프로그램에서 초기화](https://sparkle-project.org/documentation/programmatic-setup/), [내부 도구 서명](https://sparkle-project.org/documentation/sandboxing/), [GitHub PR 병합 이벤트](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#running-your-pull_request-workflow-when-a-pull-request-merges).
