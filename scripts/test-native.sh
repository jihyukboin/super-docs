#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/native-tests
cp tests/AssetServerSmoke.swift .build/native-tests/main.swift
swiftc -swift-version 5 Sources/SuperDocs/AssetServer.swift .build/native-tests/main.swift -o .build/native-tests/asset-server
.build/native-tests/asset-server
