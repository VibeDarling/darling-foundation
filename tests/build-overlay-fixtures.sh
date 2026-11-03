#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
: "${DARLING_SOURCE:?set DARLING_SOURCE}"
: "${SWIFT_TOOLCHAIN:?set SWIFT_TOOLCHAIN}"
: "${SWIFT_CORE_MODULES:?set SWIFT_CORE_MODULES}"
: "${SWIFT_SHIMS:?set SWIFT_SHIMS}"
: "${SWIFT_APINOTES:?set SWIFT_APINOTES}"
: "${IOS_SDK:?set IOS_SDK}"
: "${OUT:?set OUT}"
mkdir -p "$OUT/resource"
ln -sfn "$SWIFT_TOOLCHAIN/lib/swift/clang" "$OUT/resource/clang"
ln -sfn "$SWIFT_SHIMS" "$OUT/resource/shims"
ln -sfn "$SWIFT_APINOTES" "$OUT/resource/apinotes"
"$SWIFT_TOOLCHAIN/bin/swiftc" -frontend -c -parse-as-library -target arm64-apple-ios16.0 \
    -sdk "$IOS_SDK" -resource-dir "$OUT/resource" -module-cache-path "$OUT/module-cache" \
    -I "$SWIFT_CORE_MODULES" -swift-version 5 -Onone -disable-availability-checking \
    -runtime-compatibility-version none -disable-autolinking-runtime-compatibility \
    -disable-implicit-concurrency-module-import -disable-implicit-string-processing-module-import \
    -module-name AuthoredFoundationBridge "$here/foundation-overlay-bridge.swift" -o "$OUT/bridge.o"
clang -target arm64-apple-ios16.0 -isysroot "$IOS_SDK" -Wall -Wextra -Werror \
    -I"$DARLING_SOURCE/src/include" -c "$here/foundation-overlay-main.c" -o "$OUT/main.o"
ld64.lld -arch arm64 -platform_version ios 16.0 16.5 -syslibroot "$IOS_SDK" -ignore_auto_link \
    -no_fixup_chains "$OUT/main.o" "$OUT/bridge.o" -L "$IOS_SDK/usr/lib/swift" \
    -lswiftCore -lswiftObjectiveC -lswiftDarwin -lswiftCoreFoundation -lswiftDispatch \
    -lSystem -framework Foundation -lobjc -o "$OUT/BRIDGE"
clang -target arm64-apple-ios16.0 -isysroot "$IOS_SDK" -Wall -Wextra -Werror \
    -I"$DARLING_SOURCE/src/include" -fuse-ld=lld -Wl,-no_fixup_chains \
    "$here/foundation-overlay-lookup.c" -lSystem -o "$OUT/LOOKUP"
