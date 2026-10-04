#!/usr/bin/env python3
"""Create a standalone personal saver without editing collection release targets."""
import argparse
import hashlib
import plistlib
import re
from pathlib import Path


def create(name, identifier, output):
    if not re.fullmatch(r'[A-Z][A-Za-z0-9]*(?: [A-Za-z0-9]+)*', name):
        raise ValueError('Name must start with an uppercase letter and contain only ASCII letters, digits and spaces.')
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z][A-Za-z0-9-]*){2,}', identifier):
        raise ValueError('Use a unique reverse-DNS identifier, such as net.example.mysaver.')
    if identifier.startswith('com.someoneintexas.screensavers.'):
        raise ValueError('Use your own identifier namespace to avoid replacing a collection saver.')
    output = Path(output).resolve()
    if output.exists():
        raise ValueError('Output already exists; choose a new directory. Nothing was overwritten.')
    class_name = name.replace(' ', '') + hashlib.sha256(identifier.encode()).hexdigest()[:12]
    templates = Path(__file__).resolve().parent / 'Templates' / 'PersonalSaver'
    files = {p.name: p.read_text().replace('__CLASS__', class_name).replace('__TITLE__', name) for p in templates.iterdir() if p.is_file()}
    output.mkdir(parents=True)
    for filename, text in files.items():
        (output / filename).write_text(text)
    for filename, bundle_name, bundle_id, executable, principal, kind in [
        ('Saver.plist', name, identifier, class_name, class_name + 'View', 'BNDL'),
        ('Preview.plist', name + ' Preview', identifier + '.preview', 'Preview', 'NSApplication', 'APPL'),
    ]:
        (output / filename).write_bytes(plistlib.dumps(dict(CFBundleName=bundle_name, CFBundleIdentifier=bundle_id,
            CFBundleExecutable=executable, CFBundlePackageType=kind, CFBundleShortVersionString='0.1.0',
            CFBundleVersion='0.1.0', LSMinimumSystemVersion='14.6', NSPrincipalClass=principal, NSHighResolutionCapable=True)))
    (output / 'build.sh').chmod(0o755)
    (output / 'LICENSE').write_text((Path(__file__).resolve().parent.parent / 'LICENSE').read_text())
    (output / '.gitignore').write_text('build/\n.DS_Store\n')
    (output / 'AGENTS.md').write_text('''# Personal screen saver

Edit Scene.swift for artwork. View.swift is the native ScreenSaverView entry point;
main.swift previews the same scene. Keep its unique Objective-C class and bundle ID.
Use monotonic active time, relative geometry, and cancel work on stop. No AI or
network dependency is needed. Build with ./build.sh, then run
build/Preview.app/Contents/MacOS/Preview --smoke and open build/Preview.app.
Inspect motion, portrait/wide sizes and small previews. Do not install automatically.
To install, the owner can double-click the generated .saver in build/.
This is an independent personal project; no contribution or upstream changes required.
''')
    print(f'Created {output}\nRun ./build.sh there, then open build/Preview.app. Edit Scene.swift to make it yours.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--name', required=True)
    parser.add_argument('--identifier', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    try:
        create(args.name, args.identifier, args.output)
    except ValueError as error:
        parser.error(str(error))
