import { en as xlsxEnglish } from '@betteroffice/xlsx-i18n';
import { en as pptxEnglish } from '@betteroffice/pptx-i18n';
const words: Record<string, string> = {
  'Save': '저장', 'Undo': '실행 취소', 'Redo': '다시 실행', 'History': '편집 이력',
  'Bold': '굵게', 'Italic': '기울임', 'Underline': '밑줄', 'Strikethrough': '취소선',
  'Font family': '글꼴', 'Font size': '글자 크기', 'Font': '글꼴', 'Text formatting': '글자 서식',
  'Text color': '글자 색', 'Fill color': '채우기 색', 'Colors': '색상', 'Borders': '테두리',
  'Border color': '테두리 색', 'Border width': '테두리 두께', 'No border': '테두리 없음', 'No fill': '채우기 없음',
  'Increase font size': '글자 크게', 'Decrease font size': '글자 작게',
  'Zoom': '확대/축소', 'Zoom: {value}': '확대/축소: {value}', 'Fit': '화면 맞춤', 'Mixed': '혼합',
  'More': '더 보기', 'More toolbar items': '도구 더 보기', 'File': '파일', 'File actions': '파일 작업',
  'Print': '인쇄', 'Search': '찾기', 'Search menus': '메뉴 찾기', 'Paint format': '서식 복사',
  'Spreadsheet actions': '스프레드시트 도구', 'Spreadsheet editor': '스프레드시트 편집기',
  "Couldn't open this workbook": '통합 문서를 열지 못했습니다', 'Sheets': '시트',
  'Formula bar': '수식 입력줄', 'Name box': '셀 주소', 'Enter a value or formula': '값 또는 수식 입력',
  'Number formats': '표시 형식', 'More number formats': '표시 형식 더 보기', 'Automatic': '자동',
  'Plain text': '텍스트', 'Number': '숫자', 'Percent': '백분율', 'Scientific': '지수', 'Currency': '통화',
  'Date': '날짜', 'Time': '시간', 'Custom number format…': '사용자 지정 표시 형식…',
  'Format as currency': '통화 형식', 'Format as percent': '백분율 형식',
  'Decrease decimal places': '소수 자릿수 줄이기', 'Increase decimal places': '소수 자릿수 늘리기',
  'Merge cells': '셀 병합', 'Merge all': '전체 병합', 'Merge horizontally': '가로 병합', 'Merge vertically': '세로 병합', 'Unmerge': '병합 해제',
  'Horizontal alignment': '가로 정렬', 'Vertical alignment': '세로 정렬', 'Text wrapping': '텍스트 줄바꿈',
  'Alignment': '정렬', 'Left': '왼쪽', 'Center': '가운데', 'Right': '오른쪽', 'Top': '위', 'Middle': '가운데', 'Bottom': '아래',
  'Overflow': '넘치기', 'Wrap': '줄바꿈', 'Clip': '자르기',
  'All borders': '모든 테두리', 'Inner borders': '안쪽 테두리', 'Outer borders': '바깥 테두리', 'Clear borders': '테두리 지우기',
  'Horizontal borders': '가로 테두리', 'Vertical borders': '세로 테두리', 'Left border': '왼쪽 테두리', 'Top border': '위쪽 테두리', 'Right border': '오른쪽 테두리', 'Bottom border': '아래쪽 테두리',
  'Solid border': '실선', 'Dashed border': '파선', 'Dotted border': '점선', 'Double border': '이중선',
  'Presentation formatting toolbar': '프레젠테이션 서식 도구', 'Present': '발표', 'Slides': '슬라이드',
  'Add slide': '슬라이드 추가', 'Delete slide': '슬라이드 삭제', 'New slide': '새 슬라이드', 'New slide with layout': '레이아웃으로 새 슬라이드', 'Layout {number}': '레이아웃 {number}',
  'Objects': '개체', 'Add text box': '텍스트 상자 추가', 'Insert image': '그림 삽입', 'Text box': '텍스트 상자',
  'Tools': '도구', 'Shape': '도형', 'Shape formatting': '도형 서식', 'Align Left': '왼쪽 정렬', 'Align Right': '오른쪽 정렬', 'Justify': '양쪽 정렬',
  'Undo (⌘Z)': '실행 취소 (⌘Z)', 'Redo (⇧⌘Z)': '다시 실행 (⇧⌘Z)', 'Bold (⌘B)': '굵게 (⌘B)', 'Italic (⌘I)': '기울임 (⌘I)', 'Underline (⌘U)': '밑줄 (⌘U)', 'Select (Esc)': '선택 (Esc)',
  'Corner radius': '모서리 반경', 'Shape adjustment': '도형 조정', 'Arrange': '배치', 'Bring to front': '맨 앞으로', 'Bring forward': '앞으로', 'Send backward': '뒤로', 'Send to back': '맨 뒤로',
  'Rectangle': '사각형', 'Rounded rectangle': '둥근 사각형', 'Ellipse': '타원', 'Triangle': '삼각형', 'Right triangle': '직각삼각형', 'Diamond': '마름모',
  'Parallelogram': '평행사변형', 'Trapezoid': '사다리꼴', 'Pentagon': '오각형', 'Hexagon': '육각형', 'Octagon': '팔각형', '5-point star': '별',
  'Right arrow': '오른쪽 화살표', 'Left arrow': '왼쪽 화살표', 'Up arrow': '위쪽 화살표', 'Down arrow': '아래쪽 화살표', 'Chevron': '갈매기형',
  'Slide {number}': '슬라이드 {number}', 'Slide {current} of {total}': '슬라이드 {current} / {total}',
  'Slide {current} of {total}; selected object {name}': '슬라이드 {current} / {total}; 선택한 개체 {name}',
  'Presentation slide editor': '프레젠테이션 편집기', 'Opening presentation…': '프레젠테이션 여는 중…', 'No slides': '슬라이드 없음', 'Open a PPTX file': 'PPTX 파일을 열어 주세요',
  'Speaker notes': '발표자 메모', 'Add speaker notes…': '발표자 메모 입력…', 'Slide presentation': '슬라이드 발표', 'Exit presentation (Esc)': '발표 종료 (Esc)', 'Previous slide': '이전 슬라이드', 'Next slide': '다음 슬라이드',
};
function translate<T>(value: T): T {
  if (typeof value === 'string') return (words[value] ?? value) as T;
  if (Array.isArray(value)) return value.map(translate) as T;
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, key === '_lang' ? 'ko' : translate(item)])) as T;
  return value;
}
export const xlsxKo = translate(xlsxEnglish);
export const pptxKo = translate(pptxEnglish);
