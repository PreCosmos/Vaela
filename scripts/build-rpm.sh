#!/usr/bin/env bash
# Build the vaela-desktop RPM from this checkout (uncommitted changes included).
# Runs inside the dev container for FEDORA (default 45); the RPMs land in rpms/.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/fedora.sh
run_in_container build-rpm.sh "$@"

SPEC=packaging/vaela-desktop.spec
VERSION=$(sed -n 's/^Version: *//p' "$SPEC")
TOP="$PWD/build/rpmbuild$SUFFIX"
rm -rf "$TOP"
mkdir -p "$TOP/SOURCES" rpms
# Folders on this drive carry the setgid bit; keep it out of the build tree and the tarball
# so the packaged directories come out as plain 0755.
chmod -R g-s "$TOP"

tar --exclude-vcs --exclude='*/__pycache__' --exclude=./build --exclude=./rpms --exclude=./.devbox \
    --mode=g-s --transform "s,^\.,vaela-desktop-$VERSION," \
    -czf "$TOP/SOURCES/vaela-desktop-$VERSION.tar.gz" .

rpmbuild -ba --define "_topdir $TOP" "$SPEC"
cp "$TOP"/RPMS/*/*.rpm "$TOP"/SRPMS/*.rpm rpms/
ls -1 rpms/
