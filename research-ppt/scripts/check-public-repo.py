"""Inspect staged Git content, never private working directories. Run before commit/push."""
import json
from pathlib import PurePosixPath
import re
import subprocess
import sys


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
    blocked_parts = {'node_modules', 'screenshots', 'exports', 'versions', 'archive', '.agents', '__pycache__'}
    for name in paths:
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
