// Vela's first-login layout: a top bar, a dock that dodges windows, and a
// right-edge workspace bar that slides in when the pointer reaches the edge.
// Plasma runs this only when the user has no panel layout yet.

for (const desktop of desktopsForActivity(currentActivity())) {
    desktop.wallpaperPlugin = "org.kde.image";
}

// Top bar: launcher and activity on the left, tray and clock on the right.
// Phase 2 adds the Float / Auto Tiling / Scrollable switch at the far right.
const topBar = new Panel;
topBar.location = "top";
topBar.height = 34;
topBar.floating = false;
topBar.addWidget("org.kde.plasma.kickoff");
topBar.addWidget("org.kde.plasma.showActivityManager");
topBar.addWidget("org.kde.plasma.panelspacer");
topBar.addWidget("org.kde.plasma.systemtray");
topBar.addWidget("org.kde.plasma.digitalclock");

// Dock: centred, sized to its icons, and moves out of the way of windows.
const dock = new Panel;
dock.location = "bottom";
dock.height = 56;
dock.floating = true;
dock.lengthMode = "fit";
dock.alignment = "center";
dock.hiding = "dodgewindows";
const tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "preferred://filemanager",
    "preferred://browser",
    "applications:org.kde.konsole.desktop",
    "applications:systemsettings.desktop",
]);

// Workspace bar: hidden until the pointer touches the right edge.
// A stock pager stands in until phase 3 replaces it with Vela's tab-style list.
const workspaceBar = new Panel;
workspaceBar.location = "right";
workspaceBar.height = 220;
workspaceBar.floating = true;
workspaceBar.hiding = "autohide";
const pager = workspaceBar.addWidget("org.kde.plasma.pager");
pager.currentConfigGroup = ["General"];
pager.writeConfig("displayedText", 1); // workspace names
pager.writeConfig("showWindowIcons", true);
