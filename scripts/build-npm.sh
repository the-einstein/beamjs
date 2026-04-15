#!/bin/bash
set -e

# Build BeamJS npm package
# Usage: ./scripts/build-npm.sh [--local]
#   --local: build and bundle for the current platform (for local testing)
#   Without --local: just build the release (CI handles packaging)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NPM_DIR="$PROJECT_DIR/npm"

echo "==> Building NIF..."
cd "$PROJECT_DIR/apps/beamjs_nif/c_src"
make

echo "==> Building release..."
cd "$PROJECT_DIR"
MIX_ENV=prod mix release beamjs --overwrite

VERSION=$(grep 'version: "' mix.exs | head -1 | sed 's/.*version: "//;s/".*//')
echo "==> Release built: v${VERSION}"

if [ "$1" = "--local" ]; then
  echo "==> Copying release tarball to npm package..."
  cp "$PROJECT_DIR/_build/prod/beamjs-${VERSION}.tar.gz" "$NPM_DIR/release.tar.gz"

  echo "==> Making bin executable..."
  chmod +x "$NPM_DIR/bin/beamjs"

  echo "==> Creating npm tarball..."
  cd "$NPM_DIR"
  npm pack

  echo ""
  echo "Done! npm package built:"
  ls -lh "$NPM_DIR"/*.tgz
  echo ""
  echo "To install globally:"
  echo "  npm install -g $NPM_DIR/beamjs-runtime-${VERSION}.tgz"
else
  echo ""
  echo "Release built at: _build/prod/beamjs-${VERSION}.tar.gz"
  echo ""
  echo "To build the npm package locally, run:"
  echo "  $0 --local"
fi
