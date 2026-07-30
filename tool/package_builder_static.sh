#!/usr/bin/env bash
# Builds the production bundle and packages it as builder_static.zip —
# the exact artifact name HoloUI's BuilderServer downloads from the latest
# GitHub release (index.html must sit at the ZIP root).
set -euo pipefail
cd "$(dirname "$0")/.."

pkill -f build_daemon >/dev/null 2>&1 || true

dart pub get
dart run jaspr_cli:jaspr build

rm -f builder_static.zip
(
  cd build/jaspr
  rm -rf .dart_tool .DS_Store
  zip -qr ../../builder_static.zip . -x ".*"
  # .nojekyll matters for GitHub Pages but is excluded by the dot-glob above;
  # re-add it explicitly.
  [ -f .nojekyll ] && zip -q ../../builder_static.zip .nojekyll
)

echo "Packaged:"
unzip -l builder_static.zip | head -8
echo "..."
echo "Release checklist: tag must be BARE semver (e.g. 3.0.0 — a leading 'v' breaks the plugin's version parser),"
echo "asset must be named exactly builder_static.zip."
