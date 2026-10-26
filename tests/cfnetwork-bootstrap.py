#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Evaluate Foundation's real framework declaration with only first-pass CFNetwork.

Usage: python3 tests/cfnetwork-bootstrap.py [path/to/CMakeLists.txt]
The optional path permits checking an earlier source revision without editing it.
"""
import pathlib
import re
import subprocess
import sys
import tempfile

source = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parents[1] / "CMakeLists.txt"
match = re.search(r"add_separated_framework\(Foundation\s.*?^\)", source.read_text(), re.M | re.S)
if not match:
    raise SystemExit("Foundation framework declaration not found")
fixture = r'''
cmake_minimum_required(VERSION 3.13)
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/src/external/cfnetwork/src")
file(WRITE "${CMAKE_BINARY_DIR}/src/external/cfnetwork/src/libCFNetwork_firstpass.dylib" "fixture")
function(add_separated_framework name)
  cmake_parse_arguments(FW "FAT;CURRENT_VERSION" "VERSION;LINK_FLAGS" "SOURCES;RESOURCES;DEPENDENCIES" ${ARGN})
  if(NOT "CFNetwork_firstpass" IN_LIST FW_DEPENDENCIES)
    message(FATAL_ERROR "Foundation does not depend on first-pass CFNetwork")
  endif()
  string(REGEX MATCH "-reexport_library,([^ ]*cfnetwork[^ ]*)" flag "${FW_LINK_FLAGS}")
  if(NOT flag OR NOT EXISTS "${CMAKE_MATCH_1}")
    message(FATAL_ERROR "Foundation reexports an unavailable CFNetwork artifact: ${flag}")
  endif()
endfunction()
'''
with tempfile.TemporaryDirectory(prefix="foundation-bootstrap-") as directory:
    script = pathlib.Path(directory) / "check.cmake"
    script.write_text(fixture + "\n" + match.group() + "\n")
    subprocess.run(["cmake", "-P", str(script)], cwd=directory, check=True)
print("PASS: Foundation's evaluated reexport is available before final CFNetwork exists")
