# Super Docs

HWP·HWPX 문서를 열고 편집·저장하는 macOS 앱입니다. Swift/AppKit 창 안에서 로컬로 포함한 RHWP 0.8.7 편집기를 실행합니다.

무료 오픈소스 프로젝트이며 [MIT 라이선스](LICENSE)로 공개합니다. 현재는 소스에서 직접 빌드하는 초기 개발 버전입니다.

## 실행

- 요구 환경: Apple Silicon Mac, macOS 14 이상
- 앱: `dist/Super Docs.app`
- 파일 메뉴 또는 상단 ‘열기’로 HWP·HWPX를 선택합니다.
- `⌘S`로 저장하고, `⇧⌘S`로 이름과 HWP/HWPX 형식을 선택해 저장합니다.
- 본문·표·서식 편집, 실행 취소/다시 실행, 클립보드 붙여넣기를 지원합니다.
- 여러 문서를 각각의 창에서 열 수 있으며, 저장하지 않은 변경은 닫기·종료 전에 확인합니다.

실행 중 인터넷 연결은 필요하지 않습니다. 웹 편집기 자산만 임의 토큰이 있는 루프백 주소에서 제공하며, 문서 내용은 네이티브 앱과 WKWebView 사이에서 전달합니다.

## 빌드

Xcode Command Line Tools, Node.js 22.12 이상과 Git이 필요합니다. 첫 빌드는 npm 및 GitHub에서 의존성을 내려받습니다.

```sh
npm ci
npm run build
open "dist/Super Docs.app"
```

빌드할 때마다 편집기와 Swift 앱을 함께 생성합니다. 현재 번들은 arm64 대상이며 로컬 실행용 ad-hoc 서명입니다. 배포용 Developer ID 서명·공증은 포함하지 않습니다.

## 검증

먼저 `npm run build`로 웹 자산과 앱을 생성한 뒤 실행합니다.

```sh
npm test
bash scripts/test-native.sh
```

브라우저 검증에는 `/Applications/Google Chrome.app`이 필요합니다. 테스트는 두 형식의 한글 본문·표 생성과 저장·재열기, 실제 브라우저 키 입력·붙여넣기·실행 취소·서식 적용, 기존 HWP/HWPX 샘플 열기를 확인합니다. 네이티브 테스트는 루프백 서버의 자산 제공·MIME·경로 제한을 확인합니다.

독립 파일 형식 검사는 Python 환경에 `olefile==0.47`을 설치한 뒤 실행합니다.

```sh
python3 -m venv .build/verify-env
.build/verify-env/bin/pip install olefile==0.47
.build/verify-env/bin/python scripts/verify-files.py
```

검증 산출물은 `.build/verification/`에 저장됩니다. 실제 앱에서 저장한 `native-korean.hwp`, `native-korean.hwpx`도 존재하면 별도 OLE 레코드/ZIP XML 파서로 확인합니다. 네이티브 UI에서 문서 열기·한글 붙여넣기·저장·종료 취소 및 저장 후 종료도 확인했습니다. 물리 키보드의 한글 IME 조합 입력은 별도 검증하지 않았습니다.

## 구조와 한계

- `Sources/SuperDocs`: AppKit 메뉴·문서 창·파일 저장·WKWebView·루프백 서버
- `web/native-bridge.ts`, `web/native-paste.ts`: 편집 엔진과 네이티브 호스트의 연결
- `scripts/build-web.mjs`: RHWP 소스와 WASM을 동일한 커밋에 고정하여 번들 생성
- 엔진 버전: RHWP 0.8.7, 커밋 `1a76570e833917d15817415a53c09ad61ab3203f` (MIT)

한컴 앱 분석 결과는 UI와 문서 엔진의 책임 분리를 참고하는 데 사용했습니다. 문서 처리는 공개 RHWP 엔진을 사용하며 한컴의 바이너리를 포함하지 않습니다. 라이선스는 앱의 ‘오픈소스 라이선스’ 메뉴 및 `Resources/THIRD_PARTY_NOTICES.txt`에서 확인할 수 있습니다.

복잡한 문서의 배치·글꼴·일부 개체는 한컴 앱과 다를 수 있습니다. 암호 문서의 저장은 지원하지 않으며, 엔진이 내용 손실을 보고하는 내보내기는 차단합니다. 원본이 다른 앱에서 변경되면 덮어쓰기를 막고 다른 이름으로 저장하도록 안내합니다.

## 저장소 운영과 기여

개인 관리자가 개발 방향과 병합 여부를 결정합니다. 소스는 공개하지만, 기능 추가와 버그 수정 PR은 먼저 Issue에서 논의해 주세요. 사전 합의가 없는 PR은 검토 없이 닫힐 수 있습니다. 번역·오탈자·작은 문서 수정은 예외입니다. 자세한 내용은 [기여 안내](CONTRIBUTING.md)를 참고하세요.

- 기본 브랜치: `main`
- 버그 보고·기능 제안: [GitHub Issues](https://github.com/jihyukboin/super-docs/issues)
- CI: `main` 푸시와 PR에서 macOS 앱 빌드, 엔진·브라우저·네이티브 서버 테스트 실행
- 버전 배포: 향후 배포 시 `v0.1.0` 형태의 태그와 GitHub Releases 사용. 현재 설치 파일 릴리스와 자동 배포는 제공하지 않습니다.

## 라이선스

Super Docs 자체 코드는 [MIT](LICENSE)입니다. RHWP 및 포함 리소스의 라이선스는 각각 유지되며 [서드파티 고지](Resources/THIRD_PARTY_NOTICES.txt)를 참고하세요.
