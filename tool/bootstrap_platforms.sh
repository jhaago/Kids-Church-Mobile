#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is required: https://docs.flutter.dev/get-started/install"
  exit 1
fi

flutter create --platforms=android,ios --org au.org.pottershousebeechboro .
flutter pub get
flutter analyze
flutter test

