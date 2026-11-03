#!/usr/bin/env python3
"""Exercise hash-only overlay validation without inspecting a prebuilt payload."""
import argparse
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--overlay', type=Path, required=True)
parser.add_argument('--scratch', type=Path, required=True)
args = parser.parse_args()
helper = Path(__file__).resolve().parents[1]/'cmake/SwiftFoundationOverlay.cmake'
with tempfile.TemporaryDirectory(prefix='overlay-validation-', dir=args.scratch) as directory:
    root = Path(directory)
    script = root/'check.cmake'
    script.write_text('include("'+str(helper)+'")\nfoundation_validate_swift_overlay("${CHECK_OVERLAY}")\n')
    pointer = root/'pointer'
    pointer.write_text('version https://git-lfs.github.com/spec/v1\noid sha256:aebf3c00041c5e27b2a8620b4f8fa840fc5af2edb109b356a546c5596d083b98\nsize 11014692\n')
    wrong = root/'authored-wrong-artifact'
    wrong.write_text('Authored invalid artifact\n')
    cases = [('hydrated', args.overlay, True), ('missing', root/'missing', False),
             ('pointer', pointer, False), ('wrong', wrong, False)]
    for name, path, should_pass in cases:
        result = subprocess.run(['cmake', '-DCHECK_OVERLAY='+str(path.resolve()), '-P', str(script)],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        if (result.returncode == 0) != should_pass:
            raise SystemExit('FAIL_OVERLAY_VALIDATION_'+name.upper())
        if not should_pass and ('git lfs pull' not in result.stdout or str(path) not in result.stdout):
            raise SystemExit('FAIL_OVERLAY_DIAGNOSTIC_'+name.upper())
        print('PASS_OVERLAY_VALIDATION_'+name.upper())
