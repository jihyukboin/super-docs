# 기여 안내

Super Docs는 개인이 개발·관리하는 오픈소스 프로젝트입니다. MIT 라이선스에 따라 코드를 읽고, 수정하고, 포크하여 자신의 버전을 만들 수 있습니다. 다만 모든 외부 코드 기여를 수용하는 프로젝트는 아닙니다.

## Issue에서 먼저 논의해 주세요

버그 수정이나 기능 추가를 구현하기 전에 기존 Issue를 검색하고, 관련 Issue에서 관리자와 범위 및 접근 방법을 논의해 주세요. 사전 합의가 없는 PR은 검토 없이 닫힐 수 있습니다. 번역·오탈자·작은 문서 수정은 사전 논의 없이 제안할 수 있습니다.

버그 보고에는 macOS 버전, Mac 모델과 칩, 앱 버전, 재현 단계, 기대한 결과와 실제 결과를 포함해 주세요. 문서가 필요하면 개인정보와 기밀을 제거한 최소 재현 파일만 첨부해 주세요.

## Pull request

- 관련 Issue와 합의한 변경 범위를 적어 주세요.
- 현재 문제를 해결하는 최소한의 변경으로 유지해 주세요.
- 변경에 맞는 검증을 실행하고 결과 및 미검증 항목을 적어 주세요. `npm ci`, `npm run build`, `npm test`, `bash scripts/test-native.sh` 순서로 빌드·테스트할 수 있습니다. Apple Silicon Mac, macOS 14 이상, Xcode Command Line Tools, Node.js 24와 Google Chrome이 필요합니다.
- 원본 문서, 인증서, 비밀정보, 빌드 산출물은 커밋하지 마세요.
- 새 의존성이나 리소스의 라이선스를 확인하고 필요한 고지를 유지해 주세요.

코드 기여는 프로젝트의 MIT 라이선스로 제공됩니다. 병합 여부와 릴리스 일정은 관리자가 결정하며, 응답·수정 일정을 보장하지 않습니다.

## 배포 빌드

Developer ID Application 인증서와 개인키, 검증된 `notarytool` 키체인 프로필이 필요합니다. 다음 명령은 앱과 DMG의 서명·공증·티켓 부착 및 Gatekeeper 검증을 수행합니다. 결과는 `dist/release/<버전>/`에 생성되며 자동 업로드하지 않습니다.

```sh
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='super-docs-notary' \
bash scripts/release-macos.sh
```

인증서 파일은 Git에서 제외된 `secrets/`에 보관하고 개인키와 공증 암호는 macOS 키체인에 보관합니다.
