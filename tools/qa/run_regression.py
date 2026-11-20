import concurrent.futures
import json
import os
import subprocess
import sys
import time
from pathlib import Path

import argparse
parser = argparse.ArgumentParser()
parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
parser.add_argument("--output", default="qa/results")
parser.add_argument("--graphical-import", action="store_true",
                    help="import with OpenGL on a display instead of Godot's dummy renderer")
args = parser.parse_args()
project = Path(__file__).resolve().parents[2]
destination = Path(args.output).resolve()
destination.mkdir(parents=True, exist_ok=True)
engine = args.godot
environment = os.environ.copy()
environment['PATH'] = str(Path(engine).parent) + ':' + environment.get('PATH', '')
environment['TMPDIR'] = str(destination / 'tmp')
Path(environment['TMPDIR']).mkdir(exist_ok=True)
tasks = [
    ('structure', [sys.executable, 'tests/validate_project.py'], 60),
    ('android_version', [sys.executable, 'tests/test_android_version.py'], 60),
    ('assets', [sys.executable, 'tests/validate_assets.py'], 60),
    ('proxy', [sys.executable, 'tests/test_render_entrypoint.py'], 60),
]
def run(task):
    name, command, timeout = task
    started = time.monotonic()
    task_environment = environment.copy()
    # Each test can write settings or sessions without racing another test or
    # reading the user's local profile. Keep these outside the exported source.
    task_environment["XDG_DATA_HOME"] = str(destination / "tmp" / name / "data")
    task_environment["XDG_CONFIG_HOME"] = str(destination / "tmp" / name / "config")
    try:
        result = subprocess.run(command, cwd=project, env=task_environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        output = result.stdout.decode(errors='replace')
        code = result.returncode
    except subprocess.TimeoutExpired as exc:
        output = (exc.stdout or b'').decode(errors='replace')
        code = 124
    (destination / (name + '.log')).write_text(output)
    result = {'name': name, 'exit_code': code, 'seconds': round(time.monotonic()-started, 3), 'script_errors': 'SCRIPT ERROR:' in output, 'engine_error_count': output.count('\nERROR:')}
    print(json.dumps(result), flush=True)
    return result
results = [run(task) for task in tasks]
import_options = ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy"] if args.graphical_import else ["--headless"]
results.append(run(("import", [engine, *import_options, "--editor", "--path", ".", "--import"], 180)))
tasks = [(path.stem, [engine, '--headless', '--path', '.', '--script', str(path.relative_to(project))], 480 if 'map_flow.gd' in path.name else 150) for path in sorted((project/'tests').glob('test_*.gd'))]
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    results.extend(pool.map(run, tasks))
results.append(run(('live_proxy', [sys.executable, 'tests/test_live_websocket_proxy.py'], 60)))
(destination/'results.json').write_text(json.dumps(results, indent=2))
sys.exit(1 if any(r['exit_code'] or r['script_errors'] or r['engine_error_count'] for r in results) else 0)
