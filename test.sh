#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build/tests
xcrun swiftc -module-cache-path "$PWD/build/swift-cache" -swift-version 5 -parse-as-library \
    Sources/Core.swift Tests/CoreTests.swift -o build/tests/core-tests
build/tests/core-tests
if [[ "${1:-}" == '--media' ]]; then
    python3 Tests/make-fixtures.py
    xcrun swiftc -module-cache-path "$PWD/build/swift-cache" -swift-version 5 -parse-as-library \
        Sources/Core.swift Sources/Library.swift Tests/LibraryTests.swift -framework AVFoundation -o build/tests/library-tests
    build/tests/library-tests
fi
