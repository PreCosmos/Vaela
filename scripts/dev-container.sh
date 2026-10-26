#!/usr/bin/env bash
# Create the Fedora distrobox used to build and test Vaela, or bring its packages up to date.
# FEDORA=44 makes the Fedora 44 one (default 45). Its home lives in .devbox/ inside the
# repo, so build caches stay on this drive.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/fedora.sh

NAME=$CONTAINER
IMAGE=registry.fedoraproject.org/fedora:$FEDORA
HOME_DIR="$PWD/.devbox/home$SUFFIX"

BUILD_PKGS=(
  kf6-kservice-devel kf6-kio-devel layer-shell-qt-devel plasma-activities-devel libepoxy-devel libdrm-devel vulkan-loader-devel
  cmake extra-cmake-modules ninja-build gcc-c++ git rpm-build rpmdevtools rpmlint
  kwin-devel libplasma-devel plasma-workspace-devel
  qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtwayland-devel
  kf6-kcmutils-devel kf6-kconfig-devel kf6-kcoreaddons-devel kf6-ki18n-devel
  kf6-kglobalaccel-devel kf6-kwindowsystem-devel kf6-kpackage-devel
)
# Enough of Plasma to run a Vaela session nested in a window.
RUN_PKGS=(
  kwin plasma-workspace plasma-desktop plasma-systemsettings kscreen plasma-pa
  plasma-print-manager powerdevil kinfocenter plasma-breeze breeze-icon-theme
  xdg-desktop-portal-kde konsole dolphin dbus-daemon mesa-dri-drivers mesa-vulkan-drivers
)

mkdir -p "$HOME_DIR"
if ! distrobox list --no-color | grep -qw "$NAME"; then
  # distrobox enter waits for a "setup done" line in the container log. With the default
  # journald log driver that line can get dropped, leaving enter waiting forever.
  distrobox create --yes --name "$NAME" --image "$IMAGE" --home "$HOME_DIR" --no-entry \
    --additional-flags "--log-driver=k8s-file"
  distrobox enter "$NAME" -- true
fi
podman start "$NAME" >/dev/null
podman exec -u 0 "$NAME" dnf install -y --setopt=install_weak_deps=False \
  "${BUILD_PKGS[@]}" "${RUN_PKGS[@]}"
