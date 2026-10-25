# Vela

A Wayland desktop that looks and works like the Vivaldi browser, built on KWin.
It shows up as its own **Vela** session on the login screen and reuses Plasma's
services and settings pages wherever they already do the job.

## Status

Phase 1: the Vela session, its default layout and the RPM. Logging into Vela gives
a top bar, a dock that dodges windows and an auto-hiding workspace bar on the right.

## Roadmap

| Phase | What lands |
|---|---|
| 1 | Session at the login screen, default layout, RPM, dev container |
| 2 | KWin script for Float / Auto Tiling / Scrollable per activity, and the switch at the top right of the top bar |
| 3 | Workspace bar: workspaces as vertical tabs with stacks, colours and previews |
| 4 | KWin plugin: mouse gestures, pie menu on a 1-second right-click hold, mouse-button and wheel shortcuts |
| 5 | Pie menu and Quick Commands |
| 6 | Vela Settings (shortcuts with a mouse column, gestures, layouts), White and Black themes |

HDR, sound, printers, keyboard, mouse, power and system info come from Plasma's own
settings pages, which Vela Settings opens.

## Layout

| Path | Contents |
|---|---|
| `session/` | `startvela` and the `vela.desktop` login session |
| `config/xdg/` | Config defaults used only in the Vela session |
| `lookandfeel/org.vela.desktop/` | Plasma look-and-feel package, including the first-login panel layout |
| `packaging/` | RPM spec |
| `scripts/` | Dev container, RPM build and nested test run |
| `docs/mockup/` | The original interactive HTML mockup, for reference |

## Developing

Everything builds and runs in a Fedora 45 distrobox called `vela-dev`, whose home is
`.devbox/home` in this folder.

```bash
./scripts/dev-container.sh
```

Run Vela in a window on your current desktop, with a throwaway home:

```bash
./scripts/run-nested.sh --fresh
```

Build the RPM into `rpms/`:

```bash
./scripts/build-rpm.sh
```

## Installing on Bazzite / Fedora Atomic

```bash
rpm-ostree install ./rpms/vela-desktop-0.1.0-1.fc45.noarch.rpm
```

Reboot, then pick **Vela** on the login screen. Remove it again with
`rpm-ostree uninstall vela-desktop`. Installing pulls in KWin and the parts of
Plasma that Vela uses.
