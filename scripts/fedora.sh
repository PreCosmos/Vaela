# SPDX-License-Identifier: GPL-2.0-or-later
# Sourced by the other scripts. FEDORA picks the Fedora release to build for (default 45);
# each release has its own dev container, container home and build folders.
FEDORA=${FEDORA:-45}
SUFFIX=
[ "$FEDORA" = 45 ] || SUFFIX="-f$FEDORA"
CONTAINER="vela-dev$SUFFIX"

# Re-run the calling script inside the dev container. podman exec is used because
# distrobox enter can wait forever for a container log line that never arrives.
run_in_container() {
  [ -e /run/.containerenv ] && return 0
  podman start "$CONTAINER" >/dev/null
  # distrobox's init mounts the host's drives a moment after the container starts.
  for _ in $(seq 100); do podman exec "$CONTAINER" test -e "$PWD/scripts/$1" && break; sleep .3; done
  exec podman exec -u "$(id -u)" -e FEDORA="$FEDORA" -e LANG "$CONTAINER" "$PWD/scripts/$1" "${@:2}"
}
