#!/usr/bin/env python3
"""Relink own Foundation objects to an isolated negative reexport control."""
import argparse
import hashlib
import json
from pathlib import Path
import shlex
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--build', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
build = args.build.resolve()
output = args.output.resolve()
commands = subprocess.check_output(['ninja', '-C', str(build), '-t', 'commands', 'Foundation_arm64'], text=True).splitlines()
selected = []
for line in commands:
    tokens = shlex.split(line)
    if '-o' not in tokens or tokens[tokens.index('-o')+1] != 'src/external/foundation/Foundation_arm64':
        continue
    if tokens[:2] != [':', '&&']:
        raise SystemExit('UNRECOGNIZED_OWN_LINK_RULE')
    command = tokens[2:tokens.index('&&', 2)]
    flags = [token for token in command if token.startswith('-Wl,-reexport_library,') and token.endswith('/libswiftFoundation.dylib')]
    if len(flags) != 1:
        raise SystemExit('EXPECTED_ONE_REEXPORT_FLAG')
    command.remove(flags[0])
    command[command.index('-o')+1] = str(output)
    selected.append(command)
if len(selected) != 1:
    raise SystemExit('EXPECTED_ONE_OWN_FOUNDATION_RULE')
output.parent.mkdir(parents=True, exist_ok=True)
subprocess.run(selected[0], cwd=build, check=True)
with output.open('rb') as source:
    digest = hashlib.file_digest(source, 'sha256').hexdigest()
output.with_suffix('.json').write_text(json.dumps({'sha256':digest, 'omitted':'Swift Foundation reexport', 'command':selected[0]}, indent=2)+'\n')
print('BUILT_ISOLATED_NO_REEXPORT_CONTROL')
