
#!/usr/bin/env bash
set -euo pipefail

GNU_FTP="https://ftp.gnu.org/gnu/gcc"
WORKDIR="${RUNNER_TEMP:-/tmp}/gcc-build"
PREFIX="${PREFIX:-/mingw64/gcc-latest}"

# Convert Windows runner temp path to MSYS2 format
WORKDIR="$(cygpath -u "$WORKDIR")"

mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "Discovering latest stable GCC..."

VERSION="$(
  curl -fsSL "$GNU_FTP/" |
    grep -oE 'gcc-[0-9]+\.[0-9]+\.[0-9]+/' |
    sed -E 's|gcc-([0-9]+\.[0-9]+\.[0-9]+)/|\1|' |
    sort -V |
    tail -n 1
)"

if [[ -z "$VERSION" ]]; then
  echo "Could not determine GCC version"
  exit 1
fi

echo "GCC version: $VERSION"
echo "version=$VERSION" >> "$GITHUB_OUTPUT"

ARCHIVE="gcc-${VERSION}.tar.xz"

curl -fL --retry 5 \
  -o "$ARCHIVE" \
  "$GNU_FTP/gcc-${VERSION}/${ARCHIVE}"

tar -xf "$ARCHIVE"

cd "gcc-${VERSION}"
./contrib/download_prerequisites

mkdir -p "$WORKDIR/build"
cd "$WORKDIR/build"

"$WORKDIR/gcc-${VERSION}/configure" \
  --prefix="$PREFIX" \
  --build=x86_64-w64-mingw32 \
  --host=x86_64-w64-mingw32 \
  --enable-languages=c,c++ \
  --disable-multilib \
  --disable-bootstrap \
  --disable-nls \
  --enable-checking=release \
  --with-system-zlib

make ${MAKEFLAGS:--j2}
make install

"$PREFIX/bin/gcc.exe" --version
"$PREFIX/bin/g++.exe" --version

echo "Windows GCC build complete!"
