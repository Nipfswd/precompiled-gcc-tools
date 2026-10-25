
#!/usr/bin/env bash
set -euo pipefail

GNU_FTP="https://ftp.gnu.org/gnu/gcc"
WORKDIR="${RUNNER_TEMP:-/tmp}/gcc-build"
PREFIX="${PREFIX:-/opt/gcc-latest}"

mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "Discovering latest stable GCC release..."

VERSION="$(
  curl -fsSL "$GNU_FTP/" |
    grep -oE 'gcc-[0-9]+\.[0-9]+\.[0-9]+/' |
    sed -E 's|gcc-([0-9]+\.[0-9]+\.[0-9]+)/|\1|' |
    sort -V |
    tail -n 1
)"

if [[ -z "$VERSION" ]]; then
  echo "ERROR: Unable to discover GCC version"
  exit 1
fi

echo "Latest GCC version: $VERSION"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "version=$VERSION" >> "$GITHUB_OUTPUT"
fi

ARCHIVE="gcc-${VERSION}.tar.xz"
URL="$GNU_FTP/gcc-${VERSION}/${ARCHIVE}"

echo "Downloading $URL"

curl -fL \
  --retry 5 \
  --retry-delay 10 \
  -o "$ARCHIVE" \
  "$URL"

echo "Extracting GCC source..."
tar -xf "$ARCHIVE"

cd "gcc-${VERSION}"

echo "Downloading GCC prerequisites..."
./contrib/download_prerequisites

mkdir -p "$WORKDIR/build"
cd "$WORKDIR/build"

echo "Configuring GCC..."

"$WORKDIR/gcc-${VERSION}/configure" \
  --prefix="$PREFIX" \
  --enable-languages=c,c++ \
  --disable-multilib \
  --disable-bootstrap \
  --disable-nls \
  --enable-checking=release \
  --with-system-zlib

echo "Building GCC..."

JOBS="${MAKEFLAGS:--j2}"

make $JOBS

echo "Installing GCC..."
sudo make install

echo "Checking installed compiler..."

"$PREFIX/bin/gcc" --version
"$PREFIX/bin/g++" --version

echo "GCC $VERSION built successfully!"
