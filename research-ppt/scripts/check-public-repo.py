"""Inspect staged Git content, never private working directories. Run before commit/push."""
import hashlib
import json
from pathlib import PurePosixPath
import re
import subprocess
import sys

# Reviewed official demo exports. A replacement requires reviewing the files
# and updating these hashes; other generated or binary files remain blocked.
PUBLIC_EXPORTS = {
    'research-ppt/decks/demo/exports/v1.0.0/demo-v1.0.0.pdf':
        '3b7a73fb76e8cd46bac43b32512ddd7e309c0745ddc7ea913e8a4d4a748530e9',
    'research-ppt/decks/demo/exports/v1.0.0/demo-v1.0.0-editable.pptx':
        'c504b1de2b34c08e56da62263e61ebc58436d0f4cfc32825d3116ae54c594be5',
}


def git(*args):
    return subprocess.check_output(['git', *args])


def allowed(path):
    root_files = {'.gitignore', '.gitattributes', 'AGENTS.md', 'README.md',
                  'PPTMaker.ps1', 'THIRD_PARTY_NOTICES.md'}
    engine_files = {'package.json', 'package-lock.json'}
    if path in root_files:
        return True
    if path.startswith('docs/'):
        return path.endswith('.md')
    if not path.startswith('research-ppt/'):
        return False
    rel = path.removeprefix('research-ppt/')
    return rel in engine_files or rel.startswith(('scripts/', 'config/', 'decks/demo/'))


def main():
    root = git('rev-parse', '--show-toplevel').decode().strip()
    # All paths below are repository-relative, independent of invocation directory.
    import os
    os.chdir(root)
    paths = [p.decode('utf-8') for p in git('ls-files', '-z').split(b'\0') if p]
    if not paths:
        raise SystemExit('No tracked/staged files. Stage the intended public files first.')
    names, findings = set(paths), []
    if names.intersection(PUBLIC_EXPORTS):
        for missing in PUBLIC_EXPORTS.keys() - names:
            findings.append({'path': missing, 'issue': 'public demo export pair is incomplete'})
    blocked_parts = {'node_modules', 'screenshots', 'exports', 'versions', 'archive', '.agents', '__pycache__'}
    for name in paths:
        if name in PUBLIC_EXPORTS:
            if hashlib.sha256(git('show', ':' + name)).hexdigest() != PUBLIC_EXPORTS[name]:
                findings.append({'path': name, 'issue': 'demo export changed; review and update approved SHA256'})
            continue
        parts = PurePosixPath(name).parts
        if not allowed(name) or blocked_parts.intersection(parts) or name.endswith(('.pptx', '.pdf', '.zip', '.ttf', '.otf', '.woff', '.woff2', '.pyc', '.export.lock', '.creating')):
            findings.append({'path': name, 'issue': 'not in public file policy'})
            continue
        data = git('show', ':' + name)
        if len(data) > 2_000_000:
            findings.append({'path': name, 'issue': 'unexpectedly large file'})
        try:
            text = data.decode('utf-8-sig')
        except UnicodeDecodeError:
            findings.append({'path': name, 'issue': 'binary file requires explicit public policy review'})
            continue
        patterns = {
            'absolute local path': r'(?i)(?:[a-z]:[\\/](?:users|grokcv|home)[\\/]|/[U]sers/|/[h]ome/[^/]+/)',
            'private key': r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
            'credential value': r'(?i)(?:api[_-]?key|access[_-]?token|password)\s*[=:]\s*[\x22\x27][A-Za-z0-9_+/=-]{16,}',
        }
        for issue, pattern in patterns.items():
            if re.search(pattern, text):
                findings.append({'path': name, 'issue': issue})
        if name.endswith('.md'):
            prose = re.sub(r'```.*?```', '', text, flags=re.S)
            for target in re.findall(r'\]\(([^)\s]+)(?:\s+[^)]*)?\)', prose):
                if target.startswith(('http:', 'https:', 'mailto:', '#')):
                    continue
                from posixpath import normpath, join
                from urllib.parse import unquote
                link = normpath(join(str(PurePosixPath(name).parent), unquote(target.split('#')[0])))
                if link not in names:
                    findings.append({'path': name, 'issue': 'link missing from public index', 'target': target})
    print(json.dumps({'tracked_files': len(paths), 'findings': findings, 'status': 'failed' if findings else 'passed'}, ensure_ascii=False, indent=2))
    return bool(findings)


if __name__ == '__main__':
    sys.exit(main())
