#!/usr/bin/env python3
"""Manage MenuShelf's per-user launch agent; no administrator access needed."""
import argparse
import os
import plistlib
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('action', choices=['enable', 'disable', 'status'])
args = parser.parse_args()
label = 'local.menushelf.login'
domain = f'gui/{os.getuid()}'
target = f'{domain}/{label}'
path = Path.home() / 'Library/LaunchAgents' / f'{label}.plist'
app = Path.home() / 'Applications/MenuShelf.app'

def loaded():
    return subprocess.run(['launchctl', 'print', target], stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL).returncode == 0

if args.action == 'enable':
    if not (app / 'Contents/MacOS/MenuShelf').is_file():
        parser.error('Install MenuShelf in ~/Applications first.')
    if loaded():
        subprocess.run(['launchctl', 'bootout', target], check=True)
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        'Label': label,
        'ProgramArguments': ['/usr/bin/open', '-a', str(app), '--args', '--background'],
        'RunAtLoad': True,
    }
    temporary = path.with_suffix('.tmp')
    temporary.write_bytes(plistlib.dumps(payload))
    temporary.replace(path)
    subprocess.run(['launchctl', 'bootstrap', domain, str(path)], check=True)
    print('MenuShelf will start quietly at login.')
elif args.action == 'disable':
    if loaded():
        subprocess.run(['launchctl', 'bootout', target], check=True)
    path.unlink(missing_ok=True)
    print('MenuShelf login launch disabled. The current app may still be running.')
else:
    print(f'Launch agent installed: {path.is_file()}')
    print(f'Launch agent loaded: {loaded()}')
