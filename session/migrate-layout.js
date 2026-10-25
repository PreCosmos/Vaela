// SPDX-License-Identifier: GPL-2.0-or-later
// Upgrade only the panel shapes installed by Vela 0.1.
for (const panel of panels()) {
    const widgets = panel.widgets();
    const types = widgets.map(w => w.type);
    if (panel.location === "right" && types.length === 1 && types[0] === "org.kde.plasma.pager") {
        panel.remove();
    }
    if (panel.location === "top" && panel.height === 34
        && types.join(",") === "org.kde.plasma.kickoff,org.kde.plasma.showActivityManager,org.kde.plasma.panelspacer,org.kde.plasma.systemtray,org.kde.plasma.digitalclock") {
        panel.alignment = "left";
        panel.lengthMode = "custom";
        panel.minimumLength = Math.max(320, screenGeometry(panel.screen).width - 460);
        panel.maximumLength = panel.minimumLength;
    }
}
