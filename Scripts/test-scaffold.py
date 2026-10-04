#!/usr/bin/env python3
"""Validate generated code in a disposable project, without installing a saver."""
import importlib.util
import plistlib
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('scaffold', Path(__file__).with_name('new-saver.py'))
scaffold = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scaffold)
with tempfile.TemporaryDirectory(prefix='screensavers-scaffold-') as temp:
    root = Path(temp) / 'Quiet Orbit'
    scaffold.create('Quiet Orbit', 'net.example.quiet-orbit', root)
    try:
        scaffold.create('Quiet Orbit', 'net.example.quiet-orbit', root)
        raise AssertionError('Overwrote existing project')
    except ValueError:
        pass
    for name, identifier in [('Bad;Name', 'net.example.test'), ('Good', 'com.someoneintexas.screensavers.citydrift'), ('Good', '../escape')]:
        try:
            scaffold.create(name, identifier, Path(temp) / 'invalid')
            raise AssertionError('Accepted unsafe name or identifier')
        except ValueError:
            pass
    subprocess.run(['./build.sh'], cwd=root, check=True)
    subprocess.run(['build/Preview.app/Contents/MacOS/Preview', '--smoke'], cwd=root, check=True)
    bundle = root / 'build/Quiet Orbit.saver'
    info = plistlib.loads((bundle / 'Contents/Info.plist').read_bytes())
    assert info['CFBundleIdentifier'] == 'net.example.quiet-orbit'
    subprocess.run(['codesign', '--verify', '--strict', str(bundle)], check=True)
    header = subprocess.check_output(['otool', '-hv', str(bundle / 'Contents/MacOS' / info['CFBundleExecutable'])], text=True)
    assert 'BUNDLE' in header
print('Scaffold validation passed.')
