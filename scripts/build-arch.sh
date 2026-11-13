#!/usr/bin/env bash
# Build the current checkout, including local changes, without installing it.
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(sed -n 's/^project(vaela VERSION \([^ ]*\).*/\1/p' CMakeLists.txt)
top="$PWD/build/arch-package"
mkdir -p "$top" packages
archive="vaela-desktop-$version.tar.gz"
tar --exclude-vcs --exclude='./build' --exclude='./rpms' --exclude='./packages' \
    --exclude='./.devbox' --exclude='*/__pycache__' --mode=g-s \
    --transform "s,^\\.,vaela-desktop-$version," -czf "$top/$archive" .
checksum=$(sha256sum "$top/$archive" | cut -d ' ' -f 1)
sed "s/SOURCE_SHA256/$checksum/" packaging/arch/PKGBUILD > "$top/PKGBUILD"
cd "$top"
PKGDEST="$OLDPWD/packages" PACKAGER="${PACKAGER:-Vaela contributors}" makepkg --force "$@"
