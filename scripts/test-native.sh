#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/native-tests
cp tests/native/AssetServerSmoke.swift .build/native-tests/main.swift
swiftc -swift-version 5 Sources/SuperDocs/Web/AssetServer.swift .build/native-tests/main.swift -o .build/native-tests/asset-server
.build/native-tests/asset-server
cp tests/native/DocumentSessionTests.swift .build/native-tests/main.swift
swiftc -swift-version 5 Sources/SuperDocs/App/AppError.swift Sources/SuperDocs/Documents/DocumentSession.swift .build/native-tests/main.swift -o .build/native-tests/document-session
.build/native-tests/document-session
