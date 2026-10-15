"""Check the versioned PDF and editable PPTX using Python's standard library."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import re
import tempfile
from urllib.parse import urlsplit
import zipfile
import xml.etree.ElementTree as ET

P = '{http://schemas.openxmlformats.org/presentationml/2006/main}'
A = '{http://schemas.openxmlformats.org/drawingml/2006/main}'
REL = 'http://schemas.openxmlformats.org/package/2006/relationships'
SLIDE_REL = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide'


def local_slide_target(target):
    """Recognize Slidev's temporary print links, leaving ordinary URLs intact."""
    url = urlsplit(target)
    if url.scheme in ('http', 'https') and url.hostname in ('localhost', '127.0.0.1', '::1') and url.path == '/print':
        match = re.fullmatch(r'/?([1-9]\d*)', url.fragment)
        if match:
            return int(match[1])
    return None


def repair_slide_links(path):
    """Turn Slidev print URLs into portable PowerPoint slide jumps, atomically."""
    replacements = {}
    with zipfile.ZipFile(path) as archive:
        names = set(archive.namelist())
        for name in names:
            if not re.fullmatch(r'ppt/slides/_rels/slide\d+\.xml.rels', name):
                continue
            root = ET.fromstring(archive.read(name))
            changed = set()
            for rel in root:
                page = local_slide_target(rel.get('Target', '')) if rel.get('TargetMode') == 'External' else None
                if page is None:
                    continue
                if f'ppt/slides/slide{page}.xml' not in names:
                    raise ValueError('Slidev hyperlink points to a missing slide')
                rel.set('Target', f'slide{page}.xml')
                rel.set('Type', SLIDE_REL)
                rel.attrib.pop('TargetMode', None)
                changed.add(rel.get('Id'))
            if not changed:
                continue
            ET.register_namespace('', REL)
            replacements[name] = ET.tostring(root, encoding='utf-8', xml_declaration=True)
            slide_name = name.replace('/_rels/', '/').removesuffix('.rels')
            # Keep unrelated namespace declarations and drawing XML untouched.
            def jump(match):
                tag = match.group()
                rid = re.search(r'\br:id="([^"]+)"', tag)
                if not rid or rid[1] not in changed:
                    return tag
                action = 'action="ppaction://hlinksldjump"'
                if re.search(r'\baction="[^"]*"', tag):
                    return re.sub(r'\baction="[^"]*"', action, tag)
                return tag[:-1] + ' ' + action + '>'
            xml = archive.read(slide_name).decode('utf-8')
            replacements[slide_name] = re.sub(r'<a:hlink(?:Click|MouseOver)\b[^>]*>', jump, xml).encode('utf-8')
        if not replacements:
            return
        with tempfile.NamedTemporaryFile(dir=path.parent, suffix='.pptx.tmp', delete=False) as temporary:
            pending = Path(temporary.name)
        try:
            with zipfile.ZipFile(pending, 'w') as output:
                for info in archive.infolist():
                    output.writestr(info, replacements.get(info.filename, archive.read(info.filename)))
        except BaseException:
            pending.unlink(missing_ok=True)
            raise
    try:
        pending.replace(path)
    finally:
        pending.unlink(missing_ok=True)


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
        if not native_text:
            raise ValueError('Editable PPTX has no native text objects; visual-only slides do not pass editable-text validation')
        for name in archive.namelist():
            if name.endswith('.rels'):
                for rel in ET.fromstring(archive.read(name)):
                    if rel.get('TargetMode') == 'External' and local_slide_target(rel.get('Target', '')) is not None:
                        raise ValueError('PPTX still contains temporary Slidev print links; re-export to repair them')
        return {'slides': len(pages), 'native_text_objects': native_text,
                'pictures': pictures, 'background_images': backgrounds, 'tables': tables,
                'zip_integrity': 'passed'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--deck', required=True, type=Path)
    parser.add_argument('--version', required=True)
    parser.add_argument('--directory', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--prepare', action='store_true', help='Repair temporary Slidev links before validating staged exports')
    args = parser.parse_args()
    if not re.fullmatch(r'\d+\.\d+\.\d+', args.version):
        parser.error('Version must be X.Y.Z')
    deck = args.deck.resolve()
    deck_id = deck.name
    if not re.fullmatch(r'[a-z0-9]+(?:-[a-z0-9]+)*', deck_id):
        parser.error('Invalid deck ID')
    folder = args.directory or deck / f'exports/v{args.version}'
    stem = f'{deck_id}-v{args.version}'
    names = [f'{stem}.pdf', f'{stem}-editable.pptx']
    if sorted(p.name for p in folder.iterdir()) != sorted(names):
        raise ValueError('Version directory must contain exactly PDF and editable PPTX')
    records = []
    for name in names:
        path = folder / name
        if args.prepare and path.suffix == '.pptx':
            repair_slide_links(path)
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
    report = {'deck': deck_id, 'version': args.version,
              'checked_at': datetime.datetime.now(datetime.timezone.utc).astimezone().isoformat(),
              'output_directory': f'exports/v{args.version}', 'slides': records[1]['slides'],
              'source_sha256': hashlib.sha256((deck / 'slides.md').read_bytes()).hexdigest(),
              'outputs': records, 'status': 'integrity checked; visual QA requires rendering'}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'version': args.version, 'slides': report['slides'], 'files': len(records),
                      'native_text_objects': records[1]['native_text_objects']}, ensure_ascii=False))


if __name__ == '__main__':
    main()

