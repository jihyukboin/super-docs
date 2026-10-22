<p align="center">
  <a href="https://github.com/jihyukboin/super-docs/releases/latest">
    <img src="Resources/icon_256x256.png" width="120" alt="Super Docs 아이콘">
  </a>
</p>

<h1 align="center">Super Docs</h1>

<p align="center">
  <strong>Mac에서 한글 문서와 Word 문서를 함께.</strong><br>
  HWP · HWPX · DOCX를 열고, 편집하고, 저장하는 무료 오픈소스 문서 편집기
</p>

<p align="center">
  <a href="https://github.com/jihyukboin/super-docs/releases/latest"><img src="https://img.shields.io/github/v/release/jihyukboin/super-docs?label=download&color=6366f1" alt="최신 릴리스 다운로드"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-333333?logo=apple&logoColor=white" alt="macOS 14 이상">
  <img src="https://img.shields.io/badge/Apple_Silicon-M1%2B-333333" alt="Apple Silicon M1 이상">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-2563eb" alt="MIT 라이선스"></a>
</p>

<p align="center">
  <a href="https://github.com/jihyukboin/super-docs/releases/latest"><strong>다운로드</strong></a> ·
  <a href="https://jihyuk.tech/super-docs">웹사이트</a> ·
  <a href="#사용법">사용법</a> ·
  <a href="https://github.com/jihyukboin/super-docs/issues">문제 신고 · 기능 제안</a>
</p>

## 주요 기능

- **세 가지 문서 형식** — HWP·HWPX·DOCX의 본문, 표, 글자 서식을 편집합니다.
- **PDF 뷰어** — 페이지 이동, 확대·축소, 페이지 맞춤, 텍스트 검색·복사를 지원합니다.
- **오프라인 편집** — 문서 편집에 인터넷 연결이 필요하지 않습니다.
- **Mac에 익숙한 작업 흐름** — 여러 문서를 각각의 창에서 열고, 시스템 파일 선택창과 단축키로 작업합니다.
- **안전한 저장 흐름** — 저장하지 않은 변경 사항을 알리고, 다른 앱이 원본을 변경하면 덮어쓰기를 막습니다.
- **앱 내 업데이트** — 새 버전을 확인하고 설치를 안내합니다.

## 지원 형식과 환경

| 형식 | 열람 · 편집 | 저장 |
| --- | --- | --- |
| HWP | 지원 | HWP 또는 HWPX |
| HWPX | 지원 | HWPX 또는 HWP |
| DOCX | 지원 | DOCX |
| PDF | 열람 전용 | 지원하지 않음 |

**Apple Silicon Mac (M1 이상) · macOS 14 이상**에서 사용할 수 있습니다. 새 문서는 HWPX로 시작합니다. 형식별 제약은 [알아두세요](#알아두세요)를 확인해 주세요.

## 설치

1. [다운로드](https://github.com/jihyukboin/super-docs/releases/latest)에서 `.dmg` 파일을 받습니다.
2. DMG를 열고 **Super Docs**를 **Applications** 폴더로 드래그합니다.
3. 응용 프로그램 폴더에서 Super Docs를 실행합니다.

## 사용법

- **파일 → 열기** (`⌘O`): HWP·HWPX·DOCX·PDF 문서 열기
- **파일 → 새 문서** (`⌘N`): 새 문서 만들기
- **저장** (`⌘S`): 편집한 문서 저장
- **다른 이름으로 저장** (`⇧⌘S`): 파일 이름과 저장 형식 선택 (HWP/HWPX 간 변환, DOCX는 DOCX로 저장)

본문·표·서식을 편집하고 여러 문서를 각각의 창에서 열 수 있습니다. 문서 편집에는 인터넷 연결이 필요하지 않습니다.

PDF는 읽기 전용으로 열립니다. 상단 도구 막대에서 페이지를 이동하거나 배율을 조절하고, `⌘F`로 텍스트를 찾을 수 있습니다. 암호로 잠긴 PDF는 잠금을 해제한 후 열어 주세요.

## 업데이트

새 버전을 자동으로 확인하고 설치를 안내합니다. **Super Docs → 업데이트 확인…** 메뉴에서도 확인할 수 있습니다. 업데이트 확인과 다운로드에는 인터넷 연결이 필요합니다.

0.1.0을 사용 중이라면 위 다운로드 링크에서 새 버전을 한 번 설치해 주세요. 이후부터 앱에서 업데이트할 수 있습니다.

## 알아두세요

복잡한 문서의 배치·글꼴·일부 개체는 한컴 앱이나 Microsoft Word와 다르게 표시될 수 있습니다. DOCX의 기본 본문·서식·표 편집을 지원하며, 변경 내용 추적과 메모 편집은 지원하지 않습니다. 암호 문서의 저장은 지원하지 않습니다. 중요한 문서는 원본을 보관하고 복사본으로 작업해 주세요.

## 문제 신고와 기능 제안

[GitHub Issues](https://github.com/jihyukboin/super-docs/issues)에 macOS 버전, Mac 모델, 앱 버전과 재현 방법을 남겨 주세요. 첨부 문서에는 개인정보와 기밀이 없는지 확인해 주세요.

## 오픈소스

[RHWP](https://github.com/edwardkim/rhwp)와 [DOCX Editor](https://github.com/eigenpal/docx-editor) 기반의 독립적인 앱입니다. Super Docs는 [MIT 라이선스](LICENSE)로 공개하며, 포함된 오픈소스의 고지는 [여기](Resources/THIRD_PARTY_NOTICES.txt)에서 확인할 수 있습니다. 코드 기여는 [기여 안내](CONTRIBUTING.md)를 참고해 주세요.
