from zipfile import ZipFile
from xml.etree import ElementTree as ET

ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
with ZipFile('.build/native-tests/edited.docx') as saved, ZipFile('.build/native-tests/sample.docx') as original:
    tree = ET.fromstring(saved.read('word/document.xml'))
    text = ''.join(tree.itertext())
    assert 'DOCX edited' in text and '한글 저장 검증' in text
    assert len(tree.findall('.//w:tbl', ns)) == 1
    assert len(tree.findall('.//w:tc', ns)) == 2
    assert any('Cell edited' in ''.join(cell.itertext()) for cell in tree.findall('.//w:tc', ns))
    assert tree.find('.//w:b', ns) is not None
    assert tree.find('.//w:drawing', ns) is not None
    assert saved.read('word/media/pixel.png') == original.read('word/media/pixel.png')
print('PASS: independent ZIP/XML validation of text, bold, table, and image')
