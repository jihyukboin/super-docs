"""Independent container/record validation of files produced by Super Docs.
Run with the optional test dependency olefile==0.47 in a development venv.
"""
from pathlib import Path
from zipfile import ZipFile
import json
import struct
import zlib
import xml.etree.ElementTree as ET
import olefile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '.build/verification'

def read_text(path):
    if path.suffix == '.hwpx':
        with ZipFile(path) as archive:
            assert archive.read('mimetype') == b'application/hwp+zip'
            sections = [ET.fromstring(archive.read(name)) for name in archive.namelist()
                        if name.startswith('Contents/section') and name.endswith('.xml')]
            return ''.join(''.join(section.itertext()) for section in sections)
    with olefile.OleFileIO(str(path)) as storage:
        header = storage.openstream('FileHeader').read()
        assert header.startswith(b'HWP Document File')
        compressed = struct.unpack_from('<I', header, 36)[0] & 1
        text = []
        for name in storage.listdir():
            if len(name) != 2 or name[0] != 'BodyText':
                continue
            body = storage.openstream(name).read()
            if compressed:
                body = zlib.decompress(body, -15)
            offset = 0
            while offset + 4 <= len(body):
                record, = struct.unpack_from('<I', body, offset)
                offset += 4
                tag, size = record & 0x3ff, record >> 20
                if size == 0xfff:
                    size, = struct.unpack_from('<I', body, offset)
                    offset += 4
                assert offset + size <= len(body)
                if tag == 67:  # HWP_TAG_PARA_TEXT, public HWP 5 record layout
                    text.append(body[offset:offset + size].decode('utf-16le'))
                offset += size
        return ''.join(text)

results = []
for fmt in ['hwp', 'hwpx']:
    for prefix, expected in [('sample','슈퍼독스 HWP·HWPX 편집 검증 ABC 123'),
                             ('table','표 안의 한글'),
                             ('browser','한글 붙여넣기 검증')]:
        path = OUT / f'{prefix}.{fmt}'
        assert expected in read_text(path), (path.name, read_text(path))
        results.append({'file': path.name, 'independentTextCheck': True})
    with ZipFile(OUT / 'browser.hwpx') as archive:
        header = ET.fromstring(archive.read('Contents/header.xml'))
        assert any(element.tag.endswith('}bold') for element in header.iter()), 'bold formatting missing'
for name in ['native-korean.hwpx', 'native-korean.hwp']:
    path = OUT / name
    if path.exists():
        assert '슈퍼독스 한글 편집 검증' in read_text(path), (name, read_text(path))
        results.append({'file': name, 'independentTextCheck': True})
(OUT / 'independent-results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
print('PASS independent ZIP/XML and OLE/ParaText validation:', ', '.join(r['file'] for r in results))
