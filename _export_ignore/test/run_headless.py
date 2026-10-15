#!/usr/bin/env python3
"""Build an isolated project with GDSh and the gdsh_lib tui lib and run its runtime tests (Python 3, Godot 4.6+)."""
import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

MODULES = [Path('addons/_lib/gdsh'), Path('addons/_lib/util_r'), Path('addons/_lib/gdsh_lib/tui')]
TEST_DIR = Path('addons/_lib/gdsh_lib/tui/_export_ignore/test')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--export', action='store_true', help='Also export and run the tests from a PCK with binary scripts')
    parser.add_argument('--keep', action='store_true', help='Keep the temporary project for inspection')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[6]
    project = Path(tempfile.mkdtemp(prefix='gdsh-lib-tui-runtime-'))
    print(f'Isolated project: {project}', flush=True)
    try:
        # Tests live under each module's _export_ignore, so skip those and copy ours back in.
        for module in MODULES + [TEST_DIR]:
            shutil.copytree(repo / module, project / module, dirs_exist_ok=True,
                            ignore=shutil.ignore_patterns('.git', 'export_ignore', '_export_ignore', '__pycache__', '*.py'))
        # Copy in whatever else the scripts reach: which deps a package may carry is the
        # exporter's concern, not this suite's. An unknown UID is still a broken reference.
        uid_paths = {p.read_text().strip(): p.with_suffix('') for p in (repo / 'addons').rglob('*.uid')}
        scripts = list(project.rglob('*.gd'))
        pending = list(scripts)
        while pending:
            source = pending.pop()
            for path in re.findall(r'(?:preload|load)\("([^"\n]+)"\)|extends\s+"([^"\n]+)"', source.read_text()):
                path = path[0] or path[1]
                if path.startswith('uid://'):
                    dependency = uid_paths.get(path)
                    if dependency is None:
                        raise RuntimeError(f'Unknown UID {path} in {source.relative_to(project)}')
                    path = str(dependency.relative_to(repo))
                elif path.startswith('res://'):
                    path = path.removeprefix('res://')
                else:
                    continue
                dest = project / path
                if dest.exists() or not (repo / path).is_file():
                    continue
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(repo / path, dest)
                uid = repo / (path + '.uid')
                if uid.exists():
                    shutil.copy2(uid, project / (path + '.uid'))
                if dest.suffix == '.gd':
                    scripts.append(dest)
                    pending.append(dest)
        (project / 'project.godot').write_text('''config_version=5
[application]
config/name="GDSh tui runtime tests"
[rendering]
renderer/rendering_method="gl_compatibility"
''')
        test = f'res://{TEST_DIR}/runtime_test.gd'
        commands = [
            [args.godot, '--headless', '--path', str(project), '--editor', '--import'],
            [args.godot, '--headless', '--path', str(project), '--script', test],
        ]
        if args.export:
            (project / 'export_presets.cfg').write_text('''[preset.0]
name="Runtime"
platform="Linux"
runnable=true
export_filter="all_resources"
include_filter="*.gdsh,*.txt"
exclude_filter=""
script_export_mode=2
[preset.0.options]
binary_format/architecture="x86_64"
''')
            pack = project / 'runtime.pck'
            packed_run = project / 'packed_run'
            packed_run.mkdir()
            commands.extend([
                [args.godot, '--headless', '--path', str(project), '--export-pack', 'Runtime', str(pack)],
                [args.godot, '--headless', '--path', str(packed_run), '--main-pack', str(pack), '--script', test],
            ])
        for command in commands:
            result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
            quiet = ('--editor' in command or '--export-pack' in command) and not result.returncode and 'ERROR:' not in result.stdout
            print(('PASS: project export' if '--export-pack' in command else 'PASS: project import') if quiet else re.sub(r'\x1b\[[0-9;]*m', '', result.stdout), flush=True)
            if result.returncode or 'SCRIPT ERROR:' in result.stdout or 'Parse Error:' in result.stdout:
                return 1
        print(f'PASS: runtime isolation; {len(scripts)} scripts reached from GDSh, gdsh_lib/tui and its tests')
        return 0
    finally:
        if not args.keep:
            shutil.rmtree(project)


if __name__ == '__main__':
    raise SystemExit(main())
