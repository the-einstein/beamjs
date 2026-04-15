#!/bin/bash
set -e

# Build BeamJS npm package
# This script builds the mix release and packages it for npm distribution.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NPM_DIR="$PROJECT_DIR/npm"

echo "==> Building NIF..."
cd "$PROJECT_DIR/apps/beamjs_nif/c_src"
make

echo "==> Building release..."
cd "$PROJECT_DIR"
MIX_ENV=prod mix release beamjs --overwrite

echo "==> Copying release tarball to npm package..."
cp "$PROJECT_DIR/_build/prod/beamjs-0.1.0.tar.gz" "$NPM_DIR/release.tar.gz"

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
echo "  npm install -g $NPM_DIR/beamjs-runtime-0.1.0.tgz"
echo ""
echo "To publish to npm:"
echo "  cd $NPM_DIR && npm publish"
