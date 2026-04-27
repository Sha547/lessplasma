// Screen Time KWin script.
// Sends active-window changes to the org.kde.ScreenTime DBus service.

function report(window) {
    if (!window) {
        return;
    }
    var appClass = "";
    if (typeof window.resourceClass === "string") {
        appClass = window.resourceClass;
    } else if (window.resourceClass && window.resourceClass.toString) {
        appClass = window.resourceClass.toString();
    }
    var caption = window.caption || "";
    if (!appClass) {
        appClass = caption || "unknown";
    }
    callDBus(
        "org.kde.ScreenTime",
        "/ScreenTime",
        "org.kde.ScreenTime",
        "RecordEvent",
        appClass,
        caption
    );
}

if (workspace.windowActivated) {
    workspace.windowActivated.connect(report);
} else if (workspace.clientActivated) {
    // Plasma 5 fallback
    workspace.clientActivated.connect(report);
}

if (workspace.activeWindow) {
    report(workspace.activeWindow);
}
