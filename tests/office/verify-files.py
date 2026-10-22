from zipfile import ZipFile
import xml.etree.ElementTree as ET
from pathlib import Path
root = Path('.build/office-tests')
s = {'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
a = {'a':'http://schemas.openxmlformats.org/drawingml/2006/main'}
with ZipFile(root/'edited.xlsx') as z, ZipFile('tests/office/fixtures/sample.xlsx') as original:
    sheet = ET.fromstring(z.read('xl/worksheets/sheet1.xml'))
    assert sheet.find('.//s:c[@r="B2"]/s:v',s).text == '7'
    assert sheet.find('.//s:c[@r="C2"]/s:v',s).text == '1500'
    assert sheet.find('.//s:c[@r="D2"]/s:v',s).text == '10500'
    assert sheet.find('.//s:c[@r="D2"]/s:f',s).text == 'B2*C2'
    assert sheet.find('.//s:mergeCell',s).attrib['ref'] == 'A5:C5'
    assert 'xl/worksheets/sheet2.xml' in z.namelist()
    assert ET.fromstring(z.read('xl/styles.xml')).find('s:fonts/s:font/s:sz',s) is not None
    for name in original.namelist():
        if name.startswith('xl/charts/'):
            assert z.read(name) == original.read(name), f'Chart changed: {name}'
with ZipFile(root/'edited.pptx') as z, ZipFile('tests/office/fixtures/sample.pptx') as original:
    slide = ET.fromstring(z.read('ppt/slides/slide1.xml'))
    texts = [n.text for n in slide.findall('.//a:t',a)]
    assert '수정한 발표 본문' in texts
    assert '제품' in texts and '사과' in texts and '3600' in texts
    assert 'Quarterly Report' in texts
    assert z.read('ppt/slides/slide2.xml') == original.read('ppt/slides/slide2.xml')
    assert b'Preserve speaker notes' in z.read('ppt/notesSlides/notesSlide1.xml')
    for name in original.namelist():
        if name.startswith(('ppt/slideMasters/', 'ppt/slideLayouts/', 'ppt/theme/')):
            assert z.read(name) == original.read(name), f'Untouched layout changed: {name}'
print('PASS: XLSX cell edit, formulas, merges, sheets, charts; PPTX text edit, table, notes, untouched slides/masters/layouts')
