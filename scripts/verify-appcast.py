"""Validate generated/public Sparkle metadata against its immutable release artifact."""
import base64
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

feed, archive, version = sys.argv[1:]
ns = {'s': 'http://www.andymatuschak.org/xml-namespaces/sparkle'}
items = ET.parse(feed).findall('./channel/item')
assert len(items) == 1, 'Expected one current update'
item = items[0]
assert item.findtext('s:version', namespaces=ns) == version
assert item.findtext('s:shortVersionString', namespaces=ns) == version
assert item.findtext('s:minimumSystemVersion', namespaces=ns) in ('14.0', '14.0.0')
enclosure = item.find('enclosure')
assert enclosure is not None
assert enclosure.get('url') == f'https://github.com/jihyukboin/super-docs/releases/download/v{version}/{Path(archive).name}'
assert int(enclosure.get('length', '0')) == Path(archive).stat().st_size
assert len(base64.b64decode(enclosure.get(f"{{{ns['s']}}}edSignature", ''), validate=True)) == 64
print('PASS: Sparkle version, URL, minimum macOS, size and EdDSA signature metadata')
