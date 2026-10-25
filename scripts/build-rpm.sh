#!/usr/bin/env bash
# Build the vela-desktop RPM from this checkout (uncommitted changes included).
# Runs inside the vela-dev container; the RPMs land in rpms/.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -e /run/.containerenv ] || exec distrobox enter vela-dev -- "$PWD/scripts/build-rpm.sh" "$@"

SPEC=packaging/vela-desktop.spec
VERSION=$(sed -n 's/^Version: *//p' "$SPEC")
TOP="$PWD/build/rpmbuild"
rm -rf "$TOP"
mkdir -p "$TOP/SOURCES" rpms
# Folders on this drive carry the setgid bit; keep it out of the build tree and the tarball
# so the packaged directories come out as plain 0755.
chmod -R g-s "$TOP"

tar --exclude-vcs --exclude=./build --exclude=./rpms --exclude=./.devbox \
    --mode=g-s --transform "s,^\.,vela-desktop-$VERSION," \
    -czf "$TOP/SOURCES/vela-desktop-$VERSION.tar.gz" .

rpmbuild -ba --define "_topdir $TOP" "$SPEC"
cp "$TOP"/RPMS/*/*.rpm "$TOP"/SRPMS/*.rpm rpms/
ls -1 rpms/
