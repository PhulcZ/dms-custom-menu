import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// Context menu of an app with the same entries as in the DMS launcher.
// Deliberately not its LauncherContextMenu: that depends on launcher
// internals (Controller, ControllerUtils.js) and would break on DMS
// updates. Only public building blocks here: DContextMenu, SessionService,
// SessionData, SettingsData, AppSearchService. "Edit App" emits
// editRequested; AppEditPanel in CustomMenu does the editing.
//
// Position: just below the chip; if there is not enough room below,
// to the right of it, level with the chip.
DContextMenu {
    id: root

    property var app: null
    property string pinDockId: ""
    // Called after an action that should close CustomMenu.
    property var onLaunched: null
    // Extra entries (app groups), built by the menu for the current app
    property var groupItems: []
    // Only the extra entries (e.g. for a button, which is no app)
    property bool extraOnly: false

    signal editRequested(var app)

    readonly property string appId: app?.id || app?.execString || ""
    readonly property bool isPinned: !!appId && !!pinDockId && SessionData.getDockPins(pinDockId).includes(appId)
    readonly property bool isFlatpak: {
        if (!app)
            return false;
        const cmd0 = (app.command?.length > 0) ? String(app.command[0]).toLowerCase() : "";
        return cmd0 === "flatpak" || (app.execString || "").toLowerCase().indexOf("flatpak run ") !== -1;
    }
    readonly property string flatpakId: {
        if (!isFlatpak)
            return "";
        const args = app.command || [];
        const run = args.indexOf("run");
        for (let i = run + 1; run >= 0 && i < args.length; i++) {
            if (!String(args[i]).startsWith("-"))
                return String(args[i]);
        }
        return app.id || "";
    }

    layerNamespace: "dms:custom-menu-context-menu"
    keyboardNavigable: true

    menuItems: {
        if (!app)
            return [];
        if (extraOnly)
            return groupItems;
        const items = [];
        if (pinDockId)
            items.push({
                type: "item",
                icon: isPinned ? "keep_off" : "push_pin",
                text: isPinned ? I18n.trFor("customMenu", "Unpin from Dock") : I18n.trFor("customMenu", "Pin to Dock"),
                action: togglePin
            });
        const hidden = !!appId && SessionData.isAppHidden(appId);
        items.push({
            type: "item",
            icon: hidden ? "visibility" : "visibility_off",
            text: hidden ? I18n.trFor("customMenu", "Show App") : I18n.trFor("customMenu", "Hide App"),
            action: hidden ? () => SessionData.showApp(appId) : hideApp
        });
        items.push({
            type: "item",
            icon: "edit",
            text: I18n.trFor("customMenu", "Edit App"),
            action: () => editRequested(app)
        });
        if (groupItems.length > 0) {
            items.push({ type: "separator" });
            for (const g of groupItems)
                items.push(g);
        }
        const actions = app.actions || [];
        if (actions.length > 0) {
            items.push({ type: "separator" });
            for (const act of actions)
                items.push({
                    type: "item",
                    icon: act.icon || "play_arrow",
                    text: act.name || "",
                    action: () => launchAction(act)
                });
        }
        items.push({ type: "separator" });
        if (SessionService.nvidiaCommand)
            items.push({
                type: "item",
                icon: "memory",
                text: I18n.trFor("customMenu", "Launch on dGPU"),
                action: () => launch(true)
            });
        items.push({
            type: "item",
            icon: "launch",
            text: I18n.trFor("customMenu", "Launch"),
            action: () => launch(false)
        });
        if (isFlatpak && flatpakId)
            items.push({ type: "separator" }, {
                type: "item",
                icon: "delete",
                text: I18n.trFor("customMenu", "Uninstall") + "…",
                isDestructive: true,
                action: uninstall
            });
        return items;
    }

    // chip: the clicked tile item; screen: the popout's screen
    function showFor(chip, entry, screen) {
        if (!chip || !entry || !screen)
            return;
        app = entry;
        pinDockId = SettingsData.dockConfigForAction(screen)?.id ?? "";

        const gap = Theme.spacingXS;
        const pos = chip.mapToGlobal(0, 0);
        const x = pos.x - (screen.x || 0);
        const y = pos.y - (screen.y || 0);
        const below = y + chip.height + gap;
        // Not enough room below → to the right of the chip.
        if (below + effectiveMenuHeight + menuMargin > screen.height)
            open(screen, x + chip.width + gap, y, false);
        else
            open(screen, x, below, false);
    }

    function launch(useNvidia) {
        SessionService.launchDesktopEntry(app, useNvidia);
        AppUsageHistoryData.addAppUsage(app);
        onLaunched?.();
    }

    function launchAction(act) {
        SessionService.launchDesktopAction(app, act);
        AppUsageHistoryData.addAppUsage(app);
        onLaunched?.();
    }

    function togglePin() {
        if (!appId || !SettingsData.getDockConfig(pinDockId))
            return;
        const pins = SessionData.getDockPins(pinDockId);
        if (!isPinned)
            SettingsData.ensureDockApps(pinDockId);
        SessionData.setDockPins(pinDockId, isPinned ? pins.filter(id => id !== appId) : pins.concat([appId]));
    }

    function hideApp() {
        if (appId)
            SessionData.hideApp(appId);
    }

    function uninstall() {
        const name = app?.name || flatpakId;
        AppSearchService.requestUninstallFlatpak(appId, name, flatpakId);
        onLaunched?.();
    }
}
