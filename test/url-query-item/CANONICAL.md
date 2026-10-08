# Canonical Foundation runtime verification

Use the existing `query-item.m` once, without the `--candidate` build option.
This produces an executable whose NSURLQueryItem references resolve to the
selected runtime Foundation. Do not link the extracted implementation, rename
classes, pass a candidate dylib, preload, inject, or replace shared Foundation.
The same executable bytes must run against both the old and incoming images.

## Source and build

The regression source is committed in Foundation PR121, implementation commit
`0343872388937b4f4abdbb6e97810c1e8db93208`. The incoming image must contain
Foundation PR121 and PR122, plus CoreFoundation PR32; verify their actual
integrated source revisions from the runtime owner's manifest. PR numbers alone
are not artifact provenance. The parent owns the single combined runtime build.

The already-built original-name executable is available to the coordinator at:
`/home/cristi/tmp-opencode/messages-20261008/lib-idsfoundation/reviewed-baseline/query-item`.
Its SHA-256 is
`9dd114d34355723137846228a838e2acb3f8d7379c6c1d74e1e7f3f6f24a6072`.
Build commands and headers are in the sibling `commands.json` and `test.d`.
The existing binary can be used directly; no additional build is needed.

To reproduce it, use the committed build helper and independently pinned headers:

```sh
flock -n /tmp/agent-locks/darling-heavy-build.lock \
  python3 foundation/test/url-query-item/build.py \
  --headers-root source \
  --runtime-root /home/cristi/tmp-opencode/metal-resume/runtime-display-link-e68d60cb/image/usr/local/libexec/darling \
  --linker /home/cristi/tmp-opencode/metal-resume/build/host-tools-build/ld64/aarch64-apple-darwin20-ld \
  --build-dir canonical-build
```

Record the resulting hash once, then reuse that binary for both runs. The linker
remaps dependency lookup at build time; guest dependency install names remain the
standard Foundation/objc/libSystem paths. The test includes no replacement class.

## Private runtime runs

Obtain each immutable image's manifest, non-setuid launcher, and install prefix
from its owner. Allocate a separate absent/empty DPREFIX for each image, under the
test owner's scratch directory. Do not reuse a prefix across images. Before the
test, bootstrap `darling shell true` and replace the eight generated private home
symlinks (Desktop, Documents, Downloads, LinuxHome, Movies, Music, Pictures,
Public) with empty directories. Unlink the symlinks only; never follow or remove
host targets. If bootstrap/health-check fails, record that failure rather than
interpreting an empty test log. The test reads only synthetic in-memory values.

For each image, set QUERY_LAUNCHER to its verified non-setuid launcher,
QUERY_INSTALL to its immutable image's `usr/local`, and QUERY_PREFIX to the newly
sanitized prefix. Run from the original owner's scratch location:

```sh
: "${QUERY_LAUNCHER:?owner must supply the non-setuid launcher}"
: "${QUERY_INSTALL:?owner must supply the immutable install prefix}"
: "${QUERY_PREFIX:?owner must supply the private sanitized prefix}"
DPREFIX="$QUERY_PREFIX" DARLING_INSTALL_PREFIX="$QUERY_INSTALL" \
  "$QUERY_LAUNCHER" shell \
  /Volumes/SystemRoot/home/cristi/tmp-opencode/messages-20261008/lib-idsfoundation/reviewed-baseline/query-item
```

Record the binary hash, launcher/image/manifest paths and hashes, source revisions,
prefix, exact command, stdout/stderr and exit status for each run. Shutdown only
that prefix with the same launcher/environment and `darling shutdown` afterward.
No shared install, user message/history/keychain access, accounts or services.

## Expected results and coverage

Old immutable e68d60cb image: exit 1, `FAIL query item:` followed by an
unrecognized `+[NSURLQueryItem queryItemWithName:value:]` selector. This has
already been observed with the identical executable. It fails before the later
assertions; do not claim their execution on the old image.

Incoming combined image: exit 0 with exactly this success line:

```text
PASS query item factory, ownership, nil/empty, copy, equality, secure archive and unkeyed rejection
```

This validates original-class factory/init; mutable name/value input isolation;
absent versus empty values (including secure archive round trips); empty names;
literal Unicode, plus, percent, ampersand and equals preservation; retained copy
lifetime; value equality/hash; NSSecureCoding; invalid input types; and unkeyed
coding rejection. Any exit 1 is an exception and exit 2 an assertion failure.
The incoming canonical run remains pending until the image is ready. No Messages
launch, NSURLComponents integration scenario, or private IDSServerBag is covered.

## Bounded test registration proposal

Existing `Foundation/test/CMakeLists.txt` is enabled only by `ENABLE_TESTS` and
currently adds the nsxpc guest tests. It has no CTest or guest execution runner.
A separate follow-up could add `add_subdirectory(url-query-item)` and a
`test/url-query-item/CMakeLists.txt` containing:

```cmake
add_darling_executable(url_query_item_test query-item.m)
target_link_libraries(url_query_item_test Foundation)
install(TARGETS url_query_item_test DESTINATION libexec/darling/usr/libexec)
```

This reuses the exact existing harness and the existing installed guest-test
pattern. It requires coordinator ownership approval for the parent test file and
verification in the combined configured build; no registration/configuration
change is included here. Do not register a host CTest that executes a Mach-O
binary directly. The focused helper remains useful for unchanged-binary A/B
runtime testing even if this installed test target is added later.
