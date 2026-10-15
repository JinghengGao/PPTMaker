"""Check three versioned deliverables using Python's standard library."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import re
import zipfile
import xml.etree.ElementTree as ET

P = '{http://schemas.openxmlformats.org/presentationml/2006/main}'
A = '{http://schemas.openxmlformats.org/drawingml/2006/main}'


def inspect_pptx(path):
    with zipfile.ZipFile(path) as archive:
        if archive.testzip():
            raise ValueError('PPTX ZIP integrity check failed')
        presentation = ET.fromstring(archive.read('ppt/presentation.xml'))
        pages = [n for n in archive.namelist() if re.fullmatch(r'ppt/slides/slide\d+\.xml', n)]
        if not pages or len(presentation.find(f'{P}sldIdLst')) != len(pages):
            raise ValueError('Invalid slide count in presentation')
        native_text = pictures = backgrounds = tables = 0
        for name in pages:
            root = ET.fromstring(archive.read(name))
            backgrounds += int(root.find(f'.//{P}bg//{A}blip') is not None)
            for shape in root.iter():
                if shape.tag in (f'{P}sp', f'{P}graphicFrame'):
                    native_text += int(any((t.text or '').strip() for t in shape.iter(f'{A}t')))
                pictures += int(shape.tag == f'{P}pic')
                tables += int(shape.tag == f'{A}tbl')
        return {'slides': len(pages), 'native_text_objects': native_text,
                'pictures': pictures, 'background_images': backgrounds, 'tables': tables,
                'zip_integrity': 'passed'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--deck', required=True, type=Path)
    parser.add_argument('--version', required=True)
    parser.add_argument('--directory', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r'\d+\.\d+\.\d+', args.version):
        parser.error('Version must be X.Y.Z')
    deck = args.deck.resolve()
    folder = args.directory or deck / f'exports/v{args.version}'
    stem = f'{deck.name}-v{args.version}'
    names = [f'{stem}.pdf', f'{stem}.pptx', f'{stem}-editable.pptx']
    if sorted(p.name for p in folder.iterdir()) != sorted(names):
        raise ValueError('Version directory must contain exactly PDF, PPTX and editable PPTX')
    records = []
    for name in names:
        path = folder / name
        data = path.read_bytes()
        if len(data) < 1024:
            raise ValueError(f'Empty or incomplete deliverable: {path}')
        record = {'file': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
        if path.suffix == '.pdf':
            if not data.startswith(b'%PDF-') or b'%%EOF' not in data[-1024:]:
                raise ValueError('PDF header/trailer check failed')
            record['structure_check'] = 'header and EOF passed; native rendering is a separate check'
        else:
            record.update(inspect_pptx(path))
        records.append(record)
    if records[1]['slides'] != records[2]['slides']:
        raise ValueError('Ordinary and editable PPTX slide counts differ')
    report = {'deck': deck.name, 'version': args.version,
              'checked_at': datetime.datetime.now(datetime.timezone.utc).astimezone().isoformat(),
              'output_directory': f'exports/v{args.version}', 'slides': records[1]['slides'],
              'source_sha256': hashlib.sha256((deck / 'slides.md').read_bytes()).hexdigest(),
              'outputs': records, 'status': 'integrity checked; visual QA requires rendering'}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'version': args.version, 'slides': report['slides'], 'files': len(records),
                      'native_text_objects': records[2]['native_text_objects']}, ensure_ascii=False))


if __name__ == '__main__':
    main()

