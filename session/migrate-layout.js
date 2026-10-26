// SPDX-License-Identifier: GPL-2.0-or-later
// Upgrade only the panel shapes installed by earlier Vaela versions.
for (const panel of panels()) {
    const widgets = panel.widgets();
    const types = widgets.map(w => w.type);
    if (panel.location === "right" && types.length === 1 && types[0] === "org.kde.plasma.pager") {
        panel.remove();
    }
    // 0.2–0.4 shortened the top bar to make room for the layout switch; the switch now
    // opens over the bar's right end, so the stock bar spans the full width again.
    if (panel.location === "top" && panel.height === 34
        && types.join(",") === "org.kde.plasma.kickoff,org.kde.plasma.showActivityManager,org.kde.plasma.panelspacer,org.kde.plasma.systemtray,org.kde.plasma.digitalclock") {
        panel.lengthMode = "fill";
    }
}
