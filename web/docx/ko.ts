// Missing advanced-dialog strings fall back to the engine's English catalogue.
export const ko = {
  common: { cancel: '취소', apply: '적용', close: '닫기', dismiss: '닫기', comment: '메모' },
  toolbar: { open: '열기', save: '저장', image: '그림', table: '표', insertTable: '표 삽입' },
  formattingBar: {
    label: '서식 도구', undo: '실행 취소', undoShortcut: '실행 취소 (⌘Z)', redo: '다시 실행', redoShortcut: '다시 실행 (⇧⌘Z)',
    bold: '굵게', boldShortcut: '굵게 (⌘B)', italic: '기울임', italicShortcut: '기울임 (⌘I)', underline: '밑줄', underlineShortcut: '밑줄 (⌘U)',
    strikethrough: '취소선', fontColor: '글자 색', highlightColor: '강조 색', insertLink: '링크 삽입', insertLinkShortcut: '링크 삽입 (⌘K)',
    superscript: '위 첨자', subscript: '아래 첨자', clearFormatting: '서식 지우기', formatPainter: '서식 복사', more: '더 보기',
    imageProperties: '그림 속성', imageWrap: '텍스트 배치', altText: '대체 텍스트', paragraphMarks: '문단 기호 표시', showBookmarks: '책갈피 표시',
    groups: { history: '편집 이력', zoom: '확대/축소', styles: '스타일', font: '서체', textFormatting: '글자 서식', script: '첨자', alignment: '정렬', direction: '글 방향', listFormatting: '목록', format: '서식', image: '그림', table: '표' },
  },
  alignment: { alignLeft: '왼쪽 정렬', center: '가운데 정렬', alignRight: '오른쪽 정렬', justify: '양쪽 정렬' },
  font: { selectAriaLabel: '서체 선택', search: '서체 검색', documentFonts: '문서 서체', sansSerif: '고딕체', serif: '명조체', monospace: '고정폭' },
  fontSize: { decrease: '글자 작게', increase: '글자 크게', label: '글자 크기', listLabel: '글자 크기' },
  titleBar: { untitled: '제목 없음', documentNameAriaLabel: '문서 이름', menuBarAriaLabel: '메뉴' },
  editingMode: { label: '편집 모드', editing: '편집', editingHint: '문서 편집', suggesting: '제안', suggestingHint: '변경 제안', viewing: '읽기', viewingHint: '읽기 전용' },
  viewer: { pageIndicator: '{current} / {total}쪽' },
  navigation: {
    ariaLabel: '문서 탐색', title: '탐색', openAriaLabel: '문서 탐색 열기', openTitle: '탐색', openShortcutTitle: '탐색 ({shortcut})', closeAriaLabel: '탐색 닫기', closeTitle: '탐색 닫기',
    tabs: { headings: '제목', find: '찾기', goto: '책갈피' },
    find: { placeholder: '문서 검색', inputAriaLabel: '문서 검색', clearAriaLabel: '검색 지우기', previousAriaLabel: '이전 결과', nextAriaLabel: '다음 결과', matchCase: '대소문자 구분', wholeWord: '단어 단위로', optionsAriaLabel: '검색 옵션', resultsAriaLabel: '검색 결과', noResults: '검색 결과 없음', searching: '검색 중…', counter: '{current} / {total}', counterTruncated: '{current} / {total}+', total: '{total}개 결과', totalTruncated: '{total}개 이상 결과' },
  },
  zoom: { ariaLabel: '확대/축소: {label}', zoomOut: '축소', zoomIn: '확대', zoomLevel: '확대/축소', automatic: '자동', fitWidth: '폭 맞춤' },
  styles: { normalText: '본문', selectAriaLabel: '문단 스타일 선택' },
  editor: { documentContent: 'DOCX 문서 편집', documentViewport: '문서 페이지', fontSubstitutionNotice: '사용할 수 없는 서체를 대체하여 표시합니다: {fonts}' },
};
