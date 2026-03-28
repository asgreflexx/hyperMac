#!/bin/bash
set -e

echo "Building hyperMac..."
swift build -c release

echo "Ad-hoc signing..."
codesign --force --sign - .build/release/hyperMac

echo "Launching hyperMac..."
.build/release/hyperMac
