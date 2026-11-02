import QtQuick
import QtQuick.Controls as QQC
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.DCommon.Common as DC
import qs.Modules.Plugins
import qs.Modals.DLauncherV2 as Launcher
import "Defaults.js" as Defaults
import "LayoutFit.js" as LayoutFit
import "TileLayout.js" as TileLayout
import "Templates.js" as Templates
import "ColorRoles.js" as ColorRoles
import "./components/menu"
import "./components/common"
import "root:/Common/GridLayout.js" as GridUtils

PluginComponent {
    id: root

    // Settings as used everywhere below: stored values over the values of
    // the chosen template (Templates.js); the defaults come after that.
    // ── Instances (DMS plugin variants) ─────────────────────────────────
    // The plugin can be added several times: the main instance (no variant)
    // keeps its data in the plugin data, each variant { id, name, data }
    // in DMS' variant list. Everything below reads instanceData and saves
    // through saveKey/saveKeys. Own profiles (userTemplates) are shared.
    property var variantId: null
    // The main instance is a variant too ("variant_main": DMS lists a plugin
    // with variants only by its variants, as "CustomMenu - <variant name>",
    // so the name is not the plugin's); its data stays in the plugin data
    readonly property bool isMain: !variantId || variantId === "variant_main"
    readonly property string instanceId: isMain ? "" : String(variantId)
    // Once: the main variant exists and the bar uses it instead of the
    // plain widget id (the plain widget then shows as unknown in DMS)
    function migrateMainVariant() {
        if (variantId || !pluginService)
            return;
        const variants = pluginService.getPluginVariants(pluginId) ?? [];
        if (!variants.some(v => v.id === "variant_main"))
            SettingsData.setPluginSetting(pluginId, "variants", [{ "id": "variant_main", "name": I18n.trFor("customMenu", "Main menu") }].concat(variants));
        const fullId = pluginId + ":variant_main";
        const swap = w => typeof w === "string" ? (w === pluginId ? fullId : w) : (w?.id === pluginId ? Object.assign({}, w, { "id": fullId }) : w);
        const isPlain = w => (typeof w === "string" ? w : w?.id) === pluginId;
        for (const bar of SettingsData.barConfigs ?? []) {
            const updates = {};
            for (const side of ["leftWidgets", "centerWidgets", "rightWidgets"]) {
                const list = bar[side] ?? [];
                if (list.some(isPlain))
                    updates[side] = list.map(swap);
            }
            if (Object.keys(updates).length > 0)
                SettingsData.updateBarConfig(bar.id, updates);
        }
        pluginService.pluginDataChanged(pluginId);
    }
    // Read on every data change: DMS changes a variant inside its list in
    // place, so the list property (variants) may not signal the change
    property int dataRevision: 0
    property string lastSnapshot: ""
    function dataSnapshot() {
        const all = SettingsData.pluginSettings[pluginId] ?? {};
        const own = instanceId ? ((all.variants ?? []).find(v => v.id === instanceId)?.data ?? {}) : Object.assign({}, all, { "variants": undefined });
        return JSON.stringify([own, all.userTemplates ?? null]);
    }
    Connections {
        target: root.pluginService
        function onPluginDataChanged(changedId) {
            if (changedId !== root.pluginId)
                return;
            // Only when this instance's data (or the shared profiles) changed:
            // the settings page signals a change also when it only switches
            // the instance it edits, and every menu working everything out
            // again made that switch take seconds
            const snapshot = root.dataSnapshot();
            if (snapshot === root.lastSnapshot)
                return;
            root.lastSnapshot = snapshot;
            root.dataRevision++;
        }
    }
    readonly property var instanceData: {
        dataRevision;
        if (!instanceId)
            return pluginData;
        const list = SettingsData.getPluginSetting(pluginId, "variants", []) ?? [];
        return list.find(v => v.id === instanceId)?.data ?? {};
    }
    function saveKeys(changes) {
        if (!instanceId) {
            const updated = JSON.parse(JSON.stringify(SettingsData.pluginSettings));
            const own = updated[pluginId] ?? {};
            for (const k of Object.keys(changes)) {
                if (changes[k] === undefined)
                    delete own[k];
                else
                    own[k] = changes[k];
            }
            updated[pluginId] = own;
            SettingsData.pluginSettings = updated;
            SettingsData.savePluginSettings();
            PluginService.pluginDataChanged(pluginId);
            return;
        }
        const data = JSON.parse(JSON.stringify(pluginService?.getPluginVariantData(pluginId, instanceId)?.data ?? {}));
        for (const k of Object.keys(changes)) {
            if (changes[k] === undefined)
                delete data[k];
            else
                data[k] = changes[k];
        }
        pluginService?.updatePluginVariant(pluginId, instanceId, { "data": data });
    }
    function saveKey(key, value) {
        if (!instanceId) {
            pluginService?.savePluginData(pluginId, key, value);
            return;
        }
        const c = {};
        c[key] = value;
        saveKeys(c);
    }

    // Settings as used everywhere below: stored values over the values of
    // the chosen template (Templates.js); the defaults come after that.
    readonly property string activeTemplate: instanceData.activeTemplate ?? "standard"
    readonly property var templateValues: Templates.valuesOf(activeTemplate, pluginData.userTemplates)
    readonly property var rawCfg: Object.assign({}, templateValues, instanceData)
    // Menu surface opaque because windows are open ("transparency only
    // without windows") and "normal text then" on: the colours of texts,
    // icons and headings back to their defaults (readable on the opaque
    // surface); everything else as set
    readonly property bool opaqueNormalText: (rawCfg.menuSurfaceTransparentEmptyOnly ?? false) && (rawCfg.menuSurfaceNormalTextWithWindows ?? false) && menuScreenHasWindows
    readonly property var cfg: {
        if (!opaqueNormalText)
            return rawCfg;
        const c = Object.assign({}, rawCfg);
        for (const key of Object.keys(c)) {
            if (/(Text|Icon|Title|Placeholder)ColorMode$/.test(key))
                delete c[key];
        }
        return c;
    }

    // Requested size from the plugin settings: exact pixels (default),
    // percent of the screen or "full" (the whole free room, Fullscreen
    // template). A template with its own size over the instance's
    // (Templates.isOverlay: Fullscreen, a mini menu) decides it alone while
    // active; the instance's own size stays stored underneath.
    readonly property bool sizeFromTemplate: Templates.isOverlay(activeTemplate, pluginData.userTemplates)
    // (changes to that size: profileSize, a change against the template)
    readonly property var sizeCfg: sizeFromTemplate ? Object.assign({}, templateValues, instanceData.profileSize ?? {}) : cfg
    readonly property string menuSizeMode: Defaults.sizeModeOf(sizeCfg)
    readonly property int menuWidth: menuSizeMode === "full" ? maxMenuWidth : menuSizeMode === "percent" ? Math.round(screenWidth * (sizeCfg.menuWidthPercent ?? Defaults.menuWidthPercent) / 100) : (sizeCfg.menuWidth ?? Defaults.menuWidth)
    readonly property int menuHeight: menuSizeMode === "full" ? maxMenuHeight : menuSizeMode === "percent" ? Math.round(screenHeight * (sizeCfg.menuHeightPercent ?? Defaults.menuHeightPercent) / 100) : (sizeCfg.menuHeight ?? Defaults.menuHeight)
    // For the settings: the size shown, so switching modes starts there
    readonly property var shownMenuSize: ({ "w": popoutWidth, "h": popoutHeight, "screenW": screenWidth, "screenH": screenHeight })
    readonly property bool sizeShownInSettings: (PluginService.globalVars[pluginId]?.editInstance ?? "") === instanceId
    // Plugin-wide variable for the settings page, only when its content
    // changed: every write makes all menus and the settings page evaluate
    // again, and identical writes (a new array with the same entries) went
    // back and forth between the menus for seconds after an instance switch
    function publishVar(name, value) {
        const current = PluginService.globalVars[pluginId]?.[name];
        if (current !== undefined && JSON.stringify(current) === JSON.stringify(value))
            return;
        PluginService.setGlobalVar(pluginId, name, value);
    }
    function publishMenuSize() {
        if (sizeShownInSettings)
            publishVar("menuSize", shownMenuSize);
    }
    // One tick later: writing the global values while they are being read
    // would be a binding loop
    onShownMenuSizeChanged: Qt.callLater(publishMenuSize)
    onSizeShownInSettingsChanged: {
        Qt.callLater(publishMenuSize);
        Qt.callLater(publishLookColors);
    }

    // Space on this bar's screen: screen minus margin on both sides, and
    // across the bar additionally minus the bar and its spacing.
    readonly property real screenWidth: parentScreen?.width ?? 1920
    readonly property real screenHeight: parentScreen?.height ?? 1080
    readonly property real barSpace: barThickness + barSpacing
    // DMS' frame (frame mode) takes its thickness on the other sides
    function frameInset(side) {
        return SettingsData.frameEnabled && parentScreen ? (SettingsData.frameEdgeInsetForSide(parentScreen, side) ?? 0) : 0;
    }
    // With the frame the menu reaches it directly (as at the side opposite
    // the bar), without DMS' popup distance
    readonly property real maxMenuWidth: isVertical ? screenWidth - 2 * Theme.popupDistance - barSpace : (SettingsData.frameEnabled ? screenWidth - frameInset("left") - frameInset("right") : screenWidth - 2 * Theme.popupDistance)
    readonly property real maxMenuHeight: !isVertical ? screenHeight - 2 * Theme.popupDistance - barSpace : (SettingsData.frameEnabled ? screenHeight - frameInset("top") - frameInset("bottom") : screenHeight - 2 * Theme.popupDistance)

    // The setting can exceed this screen (other monitor, resolution
    // changed); clamp to the available space then.
    // The tile editor needs room (chips beside the rows): while it is
    // open, a smaller menu takes the whole available space, then returns
    // to its size
    readonly property bool editorWantsRoom: editingActions !== "" && (Math.min(menuWidth, maxMenuWidth) < 1000 || Math.min(menuHeight, maxMenuHeight) < 640)
    // Settings open beside a menu too wide for both: the menu gives up
    // settingsShrink px of its width (set while placing the settings
    // window), at least down to minShrunkWidth; back when they close
    property real settingsShrink: 0
    // For the settings page (notice "menu shown smaller"); one tick later,
    // as the size publishing above
    onSettingsShrinkChanged: Qt.callLater(() => PluginService.setGlobalVar(pluginId, "menuShrunk", { "instance": instanceId, "shrunk": settingsShrink > 0 }))
    readonly property real minShrunkWidth: 400
    readonly property real fullMenuWidth: Math.min(menuWidth, maxMenuWidth)
    popoutWidth: editorWantsRoom ? maxMenuWidth : previewActive && settingsShrink > 0 ? Math.max(Math.min(fullMenuWidth, minShrunkWidth), fullMenuWidth - settingsShrink) : fullMenuWidth
    popoutHeight: editorWantsRoom ? maxMenuHeight : Math.min(menuHeight, maxMenuHeight)

    // Card colour following DMS' surface settings: "default" follows the
    // DMS card colour, otherwise a theme role or a custom colour.
    // Transparency: off = fully opaque, on = custom transparency in percent.
    readonly property string cardColorMode: cfg.cardColorMode ?? "default"
    readonly property string cardCustomColor: cfg.cardCustomColor ?? ""
    readonly property bool cardTransparent: cfg.cardTransparent ?? Defaults.cardTransparent
    readonly property int cardTransparency: cfg.cardTransparency ?? Defaults.cardTransparency
    // Own icon colours of apps (symbol icons only): { appKey: "#rrggbb" }.
    // Plugin data, not DMS' app override: that has no colour field.
    readonly property var appIconColors: cfg.appIconColors ?? ({})

    // ── Tile elements ────────────────────────────────────────────────────
    // Element type "tiles" (several allowed, id "tiles:<n>"; former ones
    // "shortcuts:<n>" and "actions:<n>"): apps and buttons, independent of
    // category and search, either on an inner grid of unit-sized cells like
    // the Windows 10 start tiles, or flowing row by row (tileMode).
    // Data: shortcuts[id] = { title, tiles: [{ app: appKey, size }] }; the
    // order of the tiles decides the placement (packed first-fit).
    // Without stored data: the contents of the default layout's shortcuts
    // and buttons elements (Defaults.defaultShortcuts)
    readonly property var shortcutsData: cfg.shortcuts ?? Defaults.defaultShortcuts
    // Two tile sizes: small (1 × 1 inner cells) and large (2 × 2). Former
    // medium/wide count as small.
    readonly property var tileSizes: TileLayout.tileSizes

    // columns: inner cells per row (set by the element width in edit mode,
    // default 4); the element itself sizes to its content
    function scData(elementId) {
        const d = shortcutsData[elementId];
        return { "title": d?.title ?? "", "tiles": d?.tiles ?? [], "columns": d?.columns ?? 4 };
    }
    function saveSc(elementId, data) {
        undoCheckpoint();
        const next = Object.assign({}, shortcutsData);
        const old = shortcutsData[elementId];
        // Merge: a partial save (only the definitions, only the tiles) keeps
        // the rest of the element (title, tiles, columns, definitions)
        next[elementId] = Object.assign({ "title": "", "tiles": [], "columns": 4, "defs": {} }, old ?? {}, data);
        saveKey("shortcuts", next);
    }
    function dropShortcutsData(elementId) {
        const next = Object.assign({}, shortcutsData);
        delete next[elementId];
        saveKey("shortcuts", next);
    }
    function scSetTitle(elementId, title) {
        const d = scData(elementId);
        saveSc(elementId, { "title": title.trim(), "tiles": d.tiles });
    }
    function tileDims(tile, columns) {
        return TileLayout.tileDims(tile, columns);
    }

    // Tile placement: TileLayout.js
    function packTiles(tiles, columns) {
        return TileLayout.packTiles(tiles, columns);
    }

    function flowTiles(tiles, columns) {
        return TileLayout.flowTiles(tiles, columns);
    }
    // Arrangement of a tile element: "grid" (fixed places on the inner
    // grid, the element sizes itself) or "flow" (row by row in their order,
    // the element is sized freely). Former button elements flow.
    function tileMode(elementId) {
        return shortcutsData[elementId]?.arrangement ?? (String(elementId).startsWith("actions:") ? "flow" : "grid");
    }
    function isFlowElement(elementId) {
        return isTileElement(elementId) && tileMode(elementId) === "flow";
    }
    // Tile elements are sized freely (like the apps element); their inner
    // columns follow the width and are reported here by the element
    property var flowColumns: ({})
    // Rows that fit into a tile element (reported like the columns)
    property var tileFitRows: ({})
    function tileColumns(elementId) {
        return Math.max(1, flowColumns[elementId] ?? scData(elementId).columns);
    }

    // "Center the content" (buttons in the settings, Tiles): grid elements
    // move their occupied tiles so their block sits in the middle of the
    // cells on that axis (the alignment, set by the settings page, centres
    // the cells themselves; rows: the alignment alone does it).
    // ids: tile elements, axis "h" or "v"
    function centerTiles(ids, axis) {
        const next = JSON.parse(JSON.stringify(shortcutsData));
        let changed = false;
        for (const id of ids) {
            if (!next[id] || isFlowElement(id))
                continue;
            const cols = tileColumns(id);
            const placed = packFor(id, scData(id).tiles.filter(t => !!tileObject(id, t.app)), cols);
            if (placed.length === 0)
                continue;
            const c0 = Math.min(...placed.map(p => p.col)), c1 = Math.max(...placed.map(p => p.col + p.w));
            const r0 = Math.min(...placed.map(p => p.row)), r1 = Math.max(...placed.map(p => p.row + p.h));
            const rows = Math.max(r1, tileFitRows[id] ?? r1);
            const dx = axis === "h" ? Math.floor((cols - (c1 - c0)) / 2) - c0 : 0;
            const dy = axis === "v" ? Math.max(0, Math.floor((rows - (r1 - r0)) / 2)) - r0 : 0;
            if (dx === 0 && dy === 0)
                continue;
            // Stored positions = the placed ones, moved
            next[id].tiles = next[id].tiles.map(t => {
                const p = placed.find(q => q.tile.app === t.app);
                return p ? Object.assign({}, t, { "col": p.col + dx, "row": p.row + dy }) : t;
            });
            changed = true;
        }
        if (changed)
            saveKey("shortcuts", next);
    }
    // Request from the settings: { instance, scope ("" = all), axis, stamp }
    readonly property var centerTilesRequest: PluginService.globalVars[pluginId]?.centerTilesRequest ?? null
    onCenterTilesRequestChanged: {
        const r = centerTilesRequest;
        if (r && r.instance === instanceId && Date.now() - r.stamp < 2000)
            Qt.callLater(() => centerTiles(r.scope ? [r.scope] : shortcutsElements, r.axis));
    }
    function packFor(elementId, tiles, columns) {
        return isFlowElement(elementId) ? flowTiles(withSpans(elementId, tiles), columns) : packTiles(tiles, columns);
    }
    // Spacer buttons: length in px (0 = none), for the flow in cells
    // (px / cell step). Former ones in whole cells.
    function spacerPx(elementId, key) {
        const d = shortcutsData[elementId]?.defs?.[key];
        if (d?.kind !== "spacer")
            return -1;
        const look = lookOf(elementId);
        const step = look.unit + look.spacing;
        // 0–100 px (larger values from before count as 100)
        return Math.max(0, Math.min(100, d.px ?? (d.cells ?? 1) * step));
    }
    function withSpans(elementId, tiles) {
        const step = Math.max(1, lookOf(elementId).unit + lookOf(elementId).spacing);
        return tiles.map(t => {
            const px = spacerPx(elementId, t.app);
            return px >= 0 ? Object.assign({}, t, { "span": px / step }) : t;
        });
    }
    function storedTiles(placed) {
        return placed.map(p => ({ "app": p.tile.app, "size": p.tile.size, "col": p.col, "row": p.row }));
    }
    // Flow: order index for a drop at inner cell (col, row) = the tiles
    // (without the dropped one) that come before that cell
    function flowDrop(elementId, tiles, columns, app, size, col, row) {
        const others = tiles.filter(t => t.app !== app);
        const before = flowTiles(withSpans(elementId, others), columns).filter(p => p.row + p.h <= row || (p.row <= row && p.col + p.w / 2 <= col)).length;
        const old = tiles.find(t => t.app === app);
        others.splice(before, 0, Object.assign({}, old ?? {}, { "app": app, "size": size }));
        return storedTiles(flowTiles(withSpans(elementId, others), columns));
    }

    // Tiles after dropping `app` (size) at inner cell (col, row): it takes
    // that cell (moved inside the columns), tiles it covers move to the
    // nearest free cell. Used for the drop and for the live preview.
    function tilesWithDrop(tiles, columns, app, size, col, row) {
        const d = tileDims({ "size": size }, columns);
        const c = Math.max(0, Math.min(columns - d.w, col)), r = Math.max(0, row);
        const placed = packTiles(tiles.filter(t => t.app !== app), columns);
        const overlaps = p => p.col < c + d.w && p.col + p.w > c && p.row < r + d.h && p.row + p.h > r;
        const next = [{ "app": app, "size": size, "col": c, "row": r }];
        for (const p of placed)
            next.push(overlaps(p) ? { "app": p.tile.app, "size": p.tile.size, "wantCol": p.col, "wantRow": p.row } : { "app": p.tile.app, "size": p.tile.size, "col": p.col, "row": p.row });
        // Displaced ones: nearest free cell to where they were
        const fixed = packTiles(next.map(t => t.wantCol !== undefined ? { "app": t.app, "size": t.size, "col": t.wantCol, "row": t.wantRow, "displaced": true } : t).sort((a, b) => (a.displaced ? 1 : 0) - (b.displaced ? 1 : 0)), columns);
        return fixed.map(p => ({ "app": p.tile.app, "size": p.tile.size, "col": p.col, "row": p.row }));
    }

    // Stored with positions, so nothing moves by itself afterwards
    function scSaveTiles(elementId, tiles) {
        const d = scData(elementId);
        saveSc(elementId, { "title": d.title, "tiles": storedTiles(packFor(elementId, tiles, tileColumns(elementId))) });
    }
    function scAddApp(elementId, key, index, size) {
        const d = scData(elementId);
        if (d.tiles.some(t => t.app === key))
            return;
        scSaveTiles(elementId, d.tiles.concat([{ "app": key, "size": size || "small" }]));
    }
    function scRemoveApp(elementId, key) {
        const d = scData(elementId);
        const tiles = storedTiles(packFor(elementId, d.tiles.filter(t => t.app !== key), tileColumns(elementId)));
        // Action buttons: their definition goes with the tile (one save)
        const defs = Object.assign({}, shortcutsData[elementId]?.defs ?? {});
        delete defs[key];
        saveSc(elementId, { "tiles": tiles, "defs": defs });
    }

    // ── Buttons ──────────────────────────────────────────────────────────
    // Tiles "act:<n>" in a tile element are buttons, defined in shortcuts[id].defs
    // = { key: { kind, label, icon, path, command, confirm } }. Empty label
    // or icon = the kind's default.
    readonly property var actionKinds: ({
        "lock": { "icon": "lock", "label": I18n.trFor("customMenu", "Lock"), "confirm": false },
        "logout": { "icon": "logout", "label": I18n.tr("Log out"), "confirm": true, "power": true },
        "suspend": { "icon": "bedtime", "label": I18n.trFor("customMenu", "Suspend"), "confirm": false, "power": true },
        "hibernate": { "icon": "downloading", "label": I18n.trFor("customMenu", "Hibernate"), "confirm": true, "power": true },
        "reboot": { "icon": "restart_alt", "label": I18n.tr("Reboot", "verb, power menu action"), "confirm": true, "power": true },
        "poweroff": { "icon": "power_settings_new", "label": I18n.trFor("customMenu", "Shut down"), "confirm": true, "power": true },
        "dmsSettings": { "icon": "settings", "label": I18n.trFor("customMenu", "DMS settings"), "confirm": false },
        "dmsRestart": { "icon": "refresh", "label": I18n.trFor("customMenu", "Restart DMS"), "confirm": false },
        "launcher": { "icon": "apps", "label": I18n.trFor("customMenu", "DMS launcher"), "confirm": false },
        "menuSettings": { "icon": "tune", "label": I18n.trFor("customMenu", "CustomMenu settings"), "confirm": false },
        "menuEdit": { "icon": "edit", "label": I18n.trFor("customMenu", "Edit CustomMenu"), "confirm": false },
        "path": { "icon": "folder", "label": I18n.trFor("customMenu", "Open folder or file"), "confirm": false },
        "command": { "icon": "terminal", "label": I18n.trFor("customMenu", "Custom command"), "confirm": false },
        // Empty space between buttons (cells: its length in the flow)
        "spacer": { "icon": "space_bar", "label": I18n.trFor("customMenu", "Spacer"), "confirm": false }
    })
    readonly property var actionKindOrder: ["lock", "logout", "suspend", "hibernate", "reboot", "poweroff", "dmsSettings", "dmsRestart", "launcher", "menuSettings", "menuEdit", "path", "command", "spacer"]

    function actionDef(elementId, key) {
        const d = shortcutsData[elementId]?.defs?.[key];
        if (!d)
            return null;
        const kind = actionKinds[d.kind] ?? actionKinds.command;
        return {
            "kind": d.kind,
            "label": d.label || kind.label,
            "icon": d.icon || kind.icon,
            "path": d.path ?? "",
            "command": d.command ?? "",
            // Confirmation like DMS' power menu (hold), only where DMS confirms too
            "confirm": (d.confirm ?? kind.confirm) && SettingsData.powerActionConfirm
        };
    }

    // What a tile shows: an app, or a button as app-like object for AppTile
    function tileObject(elementId, key) {
        if (!String(key).startsWith("act:"))
            return allAppsByKey[key] ?? null;
        const d = actionDef(elementId, key);
        if (!d)
            return null;
        return { "id": key, "name": d.label, "icon": d.icon.startsWith("/") ? "image:" + d.icon : (d.icon.indexOf(":") >= 0 ? d.icon : "material:" + d.icon) };
    }

    function runAction(elementId, key) {
        const d = actionDef(elementId, key);
        // A spacer does nothing (it is not shown either)
        if (!d || d.kind === "spacer")
            return;
        // The menu settings keep the menu open (it is their preview)
        if (d.kind !== "menuEdit" && d.kind !== "menuSettings")
            closePopout();
        switch (d.kind) {
        case "lock":
            Quickshell.execDetached(["dms", "ipc", "call", "lock", "lock"]);
            break;
        case "logout":
        case "suspend":
        case "hibernate":
        case "reboot":
        case "poweroff":
            SessionService.executePowerAction(d.kind);
            break;
        case "dmsSettings":
            PopoutService.openSettings();
            break;
        case "dmsRestart":
            Quickshell.execDetached(["dms", "restart"]);
            break;
        case "launcher":
            Quickshell.execDetached(["dms", "ipc", "call", "launcher", "toggle"]);
            break;
        case "menuSettings":
            openSettingsAt("", true);
            break;
        case "menuEdit":
            layoutEditing = true;
            break;
        case "path":
            if (d.path)
                SessionService.openPath(d.path.replace(/^~/, Quickshell.env("HOME") || "~"));
            break;
        default:
            if (d.command)
                Quickshell.execDetached(["sh", "-c", d.command]);
        }
    }

    // Definition and tile in one save (two saves in a row could each start
    // from the old data)
    function addActionButton(elementId, kind) {
        const key = "act:" + Date.now();
        const d = scData(elementId);
        const defs = Object.assign({}, shortcutsData[elementId]?.defs ?? {});
        defs[key] = kind === "spacer" ? { "kind": kind, "px": Defaults.btSpacerPx } : { "kind": kind };
        const tiles = storedTiles(flowTiles(d.tiles.concat([{ "app": key, "size": "small" }]), tileColumns(elementId)));
        saveSc(elementId, { "tiles": tiles, "defs": defs });
    }
    // Grid ↔ row: the tiles are placed anew (grid: first free cells in their
    // order, at the current number of columns)
    function setTileMode(elementId, mode) {
        if (tileMode(elementId) === mode)
            return;
        const d = scData(elementId);
        const columns = tileColumns(elementId);
        const tiles = d.tiles.map(t => ({ "app": t.app, "size": mode === "flow" ? "small" : t.size }));
        const placed = mode === "flow" ? flowTiles(withSpans(elementId, tiles), columns) : packTiles(tiles.filter(t => (shortcutsData[elementId]?.defs?.[t.app]?.kind ?? "") !== "spacer"), columns);
        saveSc(elementId, { "arrangement": mode, "columns": columns, "tiles": storedTiles(placed) });
    }
    function updateActionButton(elementId, key, changes) {
        const defs = Object.assign({}, shortcutsData[elementId]?.defs ?? {});
        defs[key] = Object.assign({}, defs[key] ?? {}, changes);
        saveSc(elementId, { "defs": defs });
    }
    // Buttons editor: move the button at `from` to index `to` (drag & drop)
    function moveActionButtonTo(elementId, from, to) {
        const d = scData(elementId);
        const tiles = d.tiles.slice();
        if (from < 0 || from >= tiles.length || to < 0 || to >= tiles.length || from === to)
            return;
        tiles.splice(to, 0, tiles.splice(from, 1)[0]);
        saveSc(elementId, { "tiles": storedTiles(flowTiles(withSpans(elementId, tiles), tileColumns(elementId))) });
    }
    // Buttons editor: move a button by `delta` places in the order
    function moveActionButton(elementId, key, delta) {
        const d = scData(elementId);
        const tiles = d.tiles.slice();
        const i = tiles.findIndex(t => t.app === key);
        const j = i + delta;
        if (i < 0 || j < 0 || j >= tiles.length)
            return;
        tiles.splice(j, 0, tiles.splice(i, 1)[0]);
        saveSc(elementId, { "tiles": storedTiles(flowTiles(tiles, tileColumns(elementId))) });
    }
    // Panel (card wide) to manage the buttons of an actions element
    property string editingActions: ""
    // Category editor (element pen of the categories element), card wide
    property bool editingCategories: false
    // New size: the tile stays at its cell, covered tiles move aside
    function scSetSize(elementId, key, size) {
        const d = scData(elementId);
        const cols = Math.max(1, d.columns);
        if (isFlowElement(elementId)) {
            scSaveTiles(elementId, d.tiles.map(t => t.app === key ? Object.assign({}, t, { "size": size }) : t));
            return;
        }
        const p = packTiles(d.tiles, cols).find(x => x.tile.app === key);
        if (!p)
            return;
        saveSc(elementId, { "title": d.title, "tiles": tilesWithDrop(d.tiles, cols, key, size, p.col, p.row) });
    }

    // Live preview while an app is dragged over a shortcuts element:
    // { elementId, col, row } of the inner cell under the mouse
    property var dragHover: null
    // Preview positions { app: { col, row, w, h } } while an app hovers
    // over this element (null otherwise). The tiles keep existing (the
    // dragged one holds the mouse grab) and only move.
    function previewPositions(elementId) {
        const appId = appKey(dragApp);
        if (!dragHover || dragHover.elementId !== elementId || !appId)
            return null;
        const d = scData(elementId);
        const size = (dragFrom ? scData(dragFrom.elementId).tiles.find(t => t.app === appId)?.size : null) ?? "small";
        const map = {};
        if (isFlowElement(elementId)) {
            const cols = tileColumns(elementId);
            for (const t of flowDrop(elementId, d.tiles, cols, appId, size, dragHover.col, dragHover.row)) {
                // Spacers take no area of their own
                const dims = spacerPx(elementId, t.app) >= 0 ? { "w": 0, "h": 0 } : tileDims(t, cols);
                map[t.app] = { "col": t.col, "row": t.row, "w": dims.w, "h": dims.h };
            }
            return map;
        }
        // While dragging one column more: the element can grow to the right
        const cols = Math.max(1, d.columns) + 1;
        for (const p of packTiles(tilesWithDrop(d.tiles, cols, appId, size, dragHover.col, dragHover.row), cols))
            map[p.tile.app] = { "col": p.col, "row": p.row, "w": p.w, "h": p.h };
        return map;
    }

    Component.onCompleted: Qt.callLater(() => {
        migrateMainVariant();
        registerScreen(true);
        migrateShortcuts();
        Qt.callLater(fixTilePositions);
        Qt.callLater(seedFavorites);
        publishVar("categoryChoices_" + (instanceId || "main"), categoryChoices);
        Qt.callLater(publishMenuSize);
    })

    // Tiles from before fixed positions: store where they are shown now,
    // so moving one later does not shift the others
    function fixTilePositions() {
        for (const id of Object.keys(shortcutsData)) {
            const tiles = shortcutsData[id]?.tiles ?? [];
            if (tiles.some(t => t.col === undefined || t.row === undefined || (t.size !== "small" && t.size !== "large")))
                scSaveTiles(id, tiles.map(t => Object.assign({}, t, { "size": t.size === "large" ? "large" : "small" })));
        }
    }

    // Former data ({ groups: [...] }): each group becomes an element of its
    // own (first group keeps the element), apps as medium tiles
    function migrateShortcuts() {
        const data = cfg.shortcuts;
        if (!data)
            return;
        const ids = Object.keys(data).filter(id => Array.isArray(data[id]?.groups));
        if (ids.length === 0)
            return;
        const next = Object.assign({}, data);
        let layout = storedLayout.slice();
        let n = 0;
        for (const id of ids) {
            const groups = data[id].groups;
            const base = layout.find(i => i.id === id);
            groups.forEach((g, gi) => {
                const tiles = g.apps.map(k => ({ "app": k, "size": "medium" }));
                if (gi === 0) {
                    next[id] = { "title": g.title || "", "tiles": tiles };
                    return;
                }
                const newId = "shortcuts:" + (Date.now() + (++n));
                next[newId] = { "title": g.title || "", "tiles": tiles };
                if (base)
                    layout.push({ "id": newId, "col": base.col, "row": base.row + base.h, "w": base.w, "h": base.h });
            });
        }
        saveKey("shortcuts", next);
        if (layout.length !== storedLayout.length)
            saveLayout(fitLayout(layout).items);
    }

    // All apps by key (unfiltered: shortcuts ignore category, search and
    // hiding), with DMS' app overrides
    readonly property var allAppsByKey: {
        AppSearchService.cacheVersion;
        const map = {};
        for (const a of AppSearchService.applications)
            map[appKey(a)] = AppSearchService.applyAppOverride(a);
        return map;
    }

    // Tile elements in the layout, numbered for titles ("Tiles 2")
    readonly property var shortcutsElements: storedLayout.filter(i => isTileElement(i.id)).map(i => i.id)

    // Right click on an app: in the apps element "Add to: <tile element>",
    // on a tile size (grid only)/remove. menuContext says where it came from.
    property var menuContext: null
    function contextMenuItems(app) {
        const key = appKey(app);
        if (!key || !menuContext)
            return [];
        const items = [];
        if (menuContext.type === "shortcut") {
            const id = menuContext.elementId;
            const current = scData(id).tiles.find(t => t.app === key)?.size === "large" ? "large" : "small";
            const sizes = [["small", I18n.trFor("customMenu", "Small")], ["large", I18n.trFor("customMenu", "Large")]];
            // The element's tile editor (as its pen in edit mode)
            items.push({ "type": "item", "icon": "edit", "text": I18n.trFor("customMenu", "Edit tiles"), "action": () => root.editingActions = id });
            items.push({ "type": "separator" });
            // In a row all tiles are small
            if (!isFlowElement(id)) {
                for (const sz of sizes)
                    items.push({ "type": "item", "icon": sz[0] === current ? "check" : "aspect_ratio", "text": I18n.trFor("customMenu", "Size: %1").arg(sz[1]), "action": () => root.scSetSize(id, key, sz[0]) });
                items.push({ "type": "separator" });
            }
            items.push({ "type": "item", "icon": "remove_circle", "text": I18n.trFor("customMenu", "Remove tile"), "action": () => root.scRemoveApp(id, key) });
            return items;
        }
        for (const id of shortcutsElements) {
            if (scData(id).tiles.some(t => t.app === key))
                continue;
            const name = scData(id).title || elementTitle(id);
            items.push({ "type": "item", "icon": "bookmark_add", "text": I18n.trFor("customMenu", "Add to: %1").arg(name), "action": () => root.scAddApp(id, key, -1, "small") });
        }
        return items;
    }

    // Look of the tile elements (prefix "tl", settings section "Tiles"):
    // shared values, each element may override them (tileLooks[id], set in
    // the settings for one element). Inner grid: unit px cells with spacing
    // between; icons fill the tile up to the edge distance; names only on
    // large tiles. alignX/Y: where flowing tiles sit in a bigger element.
    function makeTileLook(own) {
        const p = "tl";
        const c = own ? Object.assign({}, cfg, own) : cfg;
        const v = (key, def) => c[p + key] ?? def;
        return {
            "alignX": alignShare(v("AlignH", Defaults.tlAlignH)),
            "alignY": alignShare(v("AlignV", Defaults.tlAlignV)),
            "showLabels": v("ShowLabels", Defaults.scShowLabels),
            "tooltips": v("Tooltips", Defaults.scTooltips),
            "unit": v("Unit", Defaults.scUnit),
            "spacing": v("Spacing", Defaults.scSpacing),
            "iconPadSmall": v("IconPadSmall", Defaults.scIconPadSmall),
            "iconPadLarge": v("IconPadLarge", Defaults.scIconPadLarge),
            "textSize": inherit(p + "TextSize", "allPieceTextSize", Defaults.scTextSize, c),
            "textWeight": fontWeight(inherit(p + "TextWeight", "allPieceTextWeight", "normal", c)),
            "textColor": catColor(p + "Text", Theme.surfaceText, "allPieceText", c),
            // Colour of all symbol icons (buttons, symbol app icons); "" =
            // unchanged. Own choice, else Appearance › Level 4 › Icon
            "iconColor": (c[p + "IconColorMode"] ?? "default") !== "default" || (c["allPieceIconColorMode"] ?? "default") !== "default" ? String(catColor(p + "Icon", Theme.surfaceText, "allPieceIcon", c)) : "",
            "tileColor": catSurface(p + "Tile", Theme.chipSurfaceNested, "allPiece", c),
            "tileRadius": inherit(p + "TileRadius", "allPieceRadius", Theme.cornerRadius, c),
            "tileBorderWidth": inherit(p + "TileBorderWidth", "allPieceBorderWidth", 0, c),
            "tileBorderColor": catColor(p + "TileBorder", Theme.outlineVariant, "allPieceBorder", c),
            "titleSize": v("TitleSize", Defaults.scTitleSize),
            "titleColor": catColor(p + "Title", Theme.surfaceText, undefined, c),
            // Title band: side (top/bottom/left/right), alignment along it
            // (start/center/end), gap on both sides of the text
            "titleSide": v("TitleSide", Defaults.scTitleSide),
            "titleAlign": v("TitleAlign", Defaults.scTitleAlign),
            "titleGap": v("TitleGap", Defaults.scTitleGap)
        };
    }
    readonly property var tileLook: makeTileLook(null)
    // Own values per tile element (settings › Tiles, chosen element)
    readonly property var tileLookValues: cfg.tileLooks ?? ({})
    readonly property var tileLooks: {
        const out = {};
        for (const id of shortcutsElements) {
            const own = tileLookValues[id];
            out[id] = own && Object.keys(own).length > 0 ? makeTileLook(own) : tileLook;
        }
        return out;
    }
    function lookOf(elementId) {
        return tileLooks[elementId] ?? tileLook;
    }

    TextMetrics {
        id: scTitleMetrics
        font.weight: Theme.fontWeightMedium
    }
    // Size of the title band: { w, h } (one of them 0)
    function scTitleBand(title, look) {
        if (!title)
            return { "w": 0, "h": 0 };
        scTitleMetrics.font.pixelSize = look.titleSize;
        scTitleMetrics.text = title;
        const side = look.titleSide === "left" || look.titleSide === "right";
        return side ? { "w": Math.ceil(scTitleMetrics.advanceWidth) + look.titleGap * 2, "h": 0 } : { "w": 0, "h": Math.ceil(scTitleMetrics.height) + look.titleGap * 2 };
    }

    // The apps element shows one flat list
    // Searching: the sections of DMS' launcher (apps, files, built-in
    // launchers, launcher plugins), otherwise the apps of the category
    readonly property var appSections: searching ? searchSections : categorySections

    // ── Sub-categories ───────────────────────────────────────────────────
    // Per category (any, incl. All and the favourites) an ordered list
    // { categoryKey: [{ id, name, apps: [appKey, …] }] }. Shown like the
    // search sections: first the category's apps that are in none of its
    // sub-categories (no heading), then one section per sub-category. An
    // app is in at most one sub-category of a category; it is dragged in
    // (a sub-category may also take apps from outside the category).
    // The list may hold { id: "__rest" }: where the remaining apps (in none
    // of the sub-categories) stand; without it they come first.
    readonly property var subcategories: cfg.subcategories ?? ({})
    function subsOf(cat) {
        return Array.isArray(subcategories[cat]) ? subcategories[cat] : [];
    }
    function realSubsOf(cat) {
        return subsOf(cat).filter(x => x.id !== "__rest");
    }
    // Order of the sub-categories and the rest (empty without sub-categories)
    function subOrder(cat) {
        const raw = subsOf(cat);
        if (!raw.some(x => x.id !== "__rest"))
            return [];
        return raw.some(x => x.id === "__rest") ? raw : [{ "id": "__rest" }].concat(raw);
    }
    function saveSubs(cat, list) {
        const next = Object.assign({}, subcategories);
        if (list.some(x => x.id !== "__rest"))
            next[cat] = list;
        else
            delete next[cat];
        saveKey("subcategories", next);
    }
    function addSubcategory(cat) {
        const base = I18n.trFor("customMenu", "New subcategory");
        const subs = subsOf(cat);
        let name = base, n = 2;
        while (subs.some(x => x.name === name))
            name = base + " " + n++;
        saveSubs(cat, subs.concat([{ "id": "s" + Date.now(), "name": name, "apps": [] }]));
    }
    function renameSubcategory(cat, id, name) {
        if (name.trim())
            saveSubs(cat, subsOf(cat).map(x => x.id === id ? Object.assign({}, x, { "name": name.trim() }) : x));
    }
    function deleteSubcategory(cat, id) {
        saveSubs(cat, subsOf(cat).filter(x => x.id !== id));
    }
    function moveSubcategoryTo(cat, from, to) {
        const subs = subOrder(cat).slice();
        if (from < 0 || from >= subs.length || to < 0 || to >= subs.length || from === to)
            return;
        subs.splice(to, 0, subs.splice(from, 1)[0]);
        saveSubs(cat, subs);
    }
    // subId "" = out of all sub-categories (back to the top part)
    function moveAppToSubcategory(cat, subId, key) {
        if (!key || String(key).startsWith("act:"))
            return;
        const subs = subsOf(cat).map(x => x.id === "__rest" ? x : Object.assign({}, x, { "apps": (x.apps ?? []).filter(a => a !== key) }));
        const target = subs.find(x => x.id === subId);
        if (target)
            target.apps = target.apps.concat([key]);
        saveSubs(cat, subs);
    }
    // Visible apps (not hidden), sorted like the lists, for sub-categories
    readonly property var visibleAppsSorted: dmsLists.visibleApps.filter(a => localHiddenApps.indexOf(appKey(a)) < 0).slice().sort((a, b) => (a.name || "").localeCompare(b.name || ""))
    readonly property var categorySections: {
        const order = subOrder(currentCategory);
        if (order.length === 0)
            return [{ "id": "__flat", "name": "", "apps": apps, "group": false, "sub": "" }];
        const inSub = {};
        for (const x of order)
            for (const k of x.apps ?? [])
                inSub[k] = true;
        const rest = apps.filter(a => !inSub[appKey(a)]);
        // The rest: no heading when it comes first, else "Other apps"
        return order.map((x, i) => x.id === "__rest" ? { "id": "__rest", "name": i === 0 ? "" : I18n.trFor("customMenu", "Other apps"), "apps": rest, "group": true, "sub": "", "rest": true } : {
            "id": "sub:" + x.id, "name": x.name, "group": true, "sub": x.id,
            "apps": visibleAppsSorted.filter(a => (x.apps ?? []).indexOf(appKey(a)) >= 0)
        });
    }
    // The plugins filter shows the plugin list also without text
    readonly property bool searching: searchQuery.trim() !== "" || searchScope === "plugins"

    // ── Search like DMS' launcher ────────────────────────────────────────
    // Its controller does the work: the same results, ranking, triggers
    // ("/" files, plugin triggers) and settings (DMS › Launcher). Files come
    // from dsearch. Apps are shown and launched as in the rest of the menu;
    // other results run through the controller.
    Launcher.Controller {
        id: launcher
        active: root.menuOpen
        onItemExecuted: root.closePopout()
        onSearchQueryRequested: query => root.searchQuery = query
    }
    // (not via "searching": that binding may not be updated yet here)
    onSearchQueryChanged: {
        navResetSelection();
        if (searchQuery.trim() !== "" || searchScope === "plugins")
            launcher.setSearchQuery(searchQuery);
    }

    // Launcher result → tile object: apps as they are, everything else as an
    // app-like object for AppTile (the result in launcherItem)
    function resultTile(item) {
        if (item.type === "app" && !item.isCore && !item.data?.isAction)
            return item.data;
        const icon = item.icon || "";
        const iconName = item.iconType === "material" ? "material:" + icon : item.iconType === "unicode" ? "material:help" : icon;
        const tile = { "id": "__launcher:" + item.section + ":" + item.id, "name": item.name, "comment": item.subtitle || "", "icon": iconName, "launcherItem": item };
        if (item.type === "file" && searchPathShow) {
            const where = pathDescription(item.subtitle || "");
            const info = item.data?.is_dir && searchFolderCount ? folderInfo[item.data.path] : null;
            tile.isFileResult = true;
            tile.badge = where.badge;
            tile.comment = [where.text, info ? folderInfoText(info) : ""].filter(t => t).join(" · ");
        }
        return tile;
    }

    // File and folder results: where they are as description (Search
    // settings): the last N parent folders, "~" for the home folder, a
    // "Nextcloud" badge instead of the path up to the Nextcloud folder, for
    // folders their number of files and subfolders. Badges (setting):
    // [{ path, label }], the longest matching path wins.
    readonly property bool searchPathShow: cfg.searchPathShow ?? Defaults.searchPathShow
    readonly property int searchPathDepth: cfg.searchPathDepth ?? Defaults.searchPathDepth
    readonly property bool searchFolderCount: cfg.searchFolderCount ?? Defaults.searchFolderCount
    readonly property string homePath: Quickshell.env("HOME") || ""
    readonly property var searchPathBadges: (Array.isArray(cfg.searchPathBadges) ? cfg.searchPathBadges : []).map(b => ({
        "path": String(b?.path ?? "").trim().replace(/^~(?=\/|$)/, homePath).replace(/\/+$/, ""),
        "label": String(b?.label ?? "").trim()
    })).filter(b => b.path !== "" && b.label !== "").sort((a, b) => b.path.length - a.path.length)

    function pathDescription(dir) {
        const inside = (root, path) => root !== "" && (path === root || path.startsWith(root + "/"));
        let badge = "", base = "", rest = dir;
        const match = searchPathBadges.find(b => inside(b.path, dir));
        if (match) {
            badge = match.label;
            rest = dir.slice(match.path.length);
        } else if (inside(homePath, dir)) {
            base = "~";
            rest = dir.slice(homePath.length);
        } else {
            base = "";
        }
        const parts = rest.split("/").filter(x => x);
        const shown = parts.slice(-Math.max(1, searchPathDepth));
        let text;
        if (shown.length < parts.length)
            text = "…/" + shown.join("/");
        else if (badge)
            text = shown.join("/");
        else
            text = (base || "") + "/" + shown.join("/");
        return { "badge": badge, "text": text === "~/" ? "~" : text };
    }

    property var folderInfo: ({})
    function folderInfoText(info) {
        const parts = [];
        if (info.files > 0)
            parts.push(info.files === 1 ? I18n.trFor("customMenu", "1 file") : I18n.trFor("customMenu", "%1 files").arg(info.files));
        if (info.dirs > 0)
            parts.push(info.dirs === 1 ? I18n.trFor("customMenu", "1 folder") : I18n.trFor("customMenu", "%1 folders").arg(info.dirs));
        return parts.length ? parts.join(", ") : I18n.trFor("customMenu", "empty");
    }
    // Counts for the folders among the results (once per folder and menu
    // opening; hidden entries do not count, like in the index)
    property int folderInfoRun: 0
    function fetchFolderInfo() {
        if (!searchPathShow || !searchFolderCount)
            return;
        const dirs = [];
        for (const sec of launcher.sections ?? []) {
            for (const it of sec.items ?? []) {
                if (it.type === "file" && it.data?.is_dir && folderInfo[it.data.path] === undefined && dirs.indexOf(it.data.path) < 0)
                    dirs.push(it.data.path);
            }
        }
        if (!dirs.length)
            return;
        const script = 'for d in "$@"; do f=$(find "$d" -mindepth 1 -maxdepth 1 ! -name ".*" -type f 2>/dev/null | wc -l); s=$(find "$d" -mindepth 1 -maxdepth 1 ! -name ".*" -type d 2>/dev/null | wc -l); printf "%s\\t%s\\t%s\\n" "$f" "$s" "$d"; done';
        Proc.runCommand("customMenu-folderInfo-" + (++folderInfoRun), ["sh", "-c", script, "sh"].concat(dirs), (out, code) => {
            const next = Object.assign({}, folderInfo);
            for (const line of String(out).split("\n")) {
                const cols = line.split("\t");
                if (cols.length >= 3)
                    next[cols.slice(2).join("\t")] = { "files": parseInt(cols[0]) || 0, "dirs": parseInt(cols[1]) || 0 };
            }
            folderInfo = next;
        });
    }
    Connections {
        target: launcher
        function onSectionsChanged() {
            Qt.callLater(root.fetchFolderInfo);
        }
    }

    // Order and visibility from the settings (empty order = DMS' order;
    // sections not in the stored order keep DMS' order after the others)
    readonly property var searchSectionOrder: Array.isArray(cfg.searchSectionOrder) ? cfg.searchSectionOrder : []
    readonly property var searchSectionHidden: Array.isArray(cfg.searchSectionHidden) ? cfg.searchSectionHidden : []
    readonly property var searchSections: {
        const list = (launcher.sections ?? []).filter(s => (s.items ?? []).length > 0 && searchSectionHidden.indexOf(s.id) < 0);
        const rank = (s, i) => {
            const o = searchSectionOrder.indexOf(s.id);
            return o >= 0 ? o : searchSectionOrder.length + i;
        };
        // Only one section (e.g. scope "Apps"): no heading
        return list.map((s, i) => ({ "s": s, "r": rank(s, i) })).sort((a, b) => a.r - b.r).map(x => ({
            "id": x.s.id, "name": list.length > 1 ? (x.s.title || "") : "", "apps": x.s.items.map(resultTile), "group": true
        }));
    }
    // Section headings (Search › Result sections)
    readonly property real secTitleSize: cfg.secTitleSize ?? textSize + 2
    readonly property int secTitleWeight: fontWeight(cfg.secTitleWeight ?? "medium")
    readonly property color secTitleColor: catColor("secTitle", appTextColor)
    readonly property bool secLineShow: cfg.secLineShow ?? true
    readonly property color secLineColor: catColor("secLine", Theme.withAlpha(appTextColor, 0.25))
    readonly property real secGap: cfg.secGap ?? appRowSpacing
    readonly property real secTitleGap: cfg.secTitleGap ?? Defaults.secTitleGap
    // Sub-category headings: like the result sections unless set
    // (Categories › Sub-categories)
    readonly property real subTitleSize: cfg.subTitleSize ?? secTitleSize
    readonly property int subTitleWeight: cfg.subTitleWeight ? fontWeight(cfg.subTitleWeight) : secTitleWeight
    readonly property color subTitleColor: catColor("subTitle", secTitleColor)
    readonly property bool subLineShow: cfg.subLineShow ?? secLineShow
    readonly property color subLineColor: catColor("subLine", secLineColor)
    readonly property real subGap: cfg.subGap ?? secGap
    readonly property real subTitleGap: cfg.subTitleGap ?? secTitleGap
    // Search scope (in the search element, chips or dropdown like the
    // categories): everything, apps, files or folders = the launcher's
    // modes; back to everything when the menu closes
    readonly property bool searchScopeShow: cfg.searchScopeShow ?? Defaults.searchScopeShow
    readonly property string searchScopeStyle: cfg.searchScopeStyle ?? Defaults.searchScopeStyle
    readonly property var searchScopes: [
        { "key": "all", "text": I18n.trFor("customMenu", "Everything"), "icon": "search" },
        { "key": "apps", "text": I18n.trFor("customMenu", "Apps"), "icon": "apps" },
        { "key": "files", "text": I18n.trFor("customMenu", "Files"), "icon": "description" },
        { "key": "dirs", "text": I18n.trFor("customMenu", "Folders"), "icon": "folder" },
        // DMS' launcher plugins: without text their list, with text their results
        { "key": "plugins", "text": I18n.trFor("customMenu", "Plugins"), "icon": "extension" }
    ]
    property string searchScope: "all"
    // List of the scope chip in the search field (drawn on the card)
    property bool scopeListOpen: false
    property point scopeListPos: Qt.point(0, 0)
    // Height of the switcher below the field (reported by the element)
    property real searchScopeHeight: catChipHeight
    // "field": a chip in the search field opens the list; "chips": a row
    // of chips outside the field, on one of its sides (top/bottom make the
    // element higher, left/right narrow the field), aligned along it
    readonly property bool searchScopeInField: searchScopeShow && searchScopeStyle !== "chips"
    readonly property bool searchScopeBelow: searchScopeShow && searchScopeStyle === "chips"
    readonly property string searchScopeSide: cfg.searchScopeSide ?? Defaults.searchScopeSide
    readonly property string searchScopeAlign: cfg.searchScopeAlign ?? Defaults.searchScopeAlign
    readonly property bool searchScopeAcross: searchScopeSide === "top" || searchScopeSide === "bottom"
    // Width of the chips row beside the field (reported by the element)
    property real searchScopeWidth: 0
    readonly property real searchScopeExtra: !searchScopeBelow ? 0 : searchScopeAcross ? Theme.spacingS + searchScopeHeight : Math.max(0, searchScopeHeight - searchHeight)
    readonly property real searchScopeTextSize: cfg.searchScopeTextSize ?? Defaults.searchScopeTextSize
    readonly property string searchScopeLabel: searchScopes.find(s => s.key === searchScope)?.text ?? ""
    onSearchScopeChanged: {
        // Not persisted as DMS' last launcher mode (last argument)
        if (searchScope === "apps")
            launcher.setMode("apps", false, undefined, true);
        else if (searchScope === "files")
            launcher.setMode("files", false, "file", true);
        else if (searchScope === "dirs")
            launcher.setMode("files", false, "dir", true);
        else if (searchScope === "plugins")
            launcher.setMode("plugins", false, undefined, true);
        else
            launcher.setMode("all", false, undefined, true);
    }

    // First result (Enter)
    readonly property var firstResult: searchSections.length ? searchSections[0].apps[0] : null

    // ── Keyboard navigation in the apps element ─────────────────────────
    // Like DMS' launcher: arrows (left/right once the keyboard selection
    // is active, otherwise they move the text cursor), Page up/down,
    // Ctrl+J/K/H/L, Ctrl+N/P = next/previous section, Ctrl+1–4 = scope,
    // Enter = start, Menu/F10 = app menu. While searching the first
    // result is selected (Enter starts it); typing resets the selection.
    property int navIndex: 0
    property bool navActive: false
    property int appColumns: 1
    property int appPageRows: 4
    // Delegate of the selected tile (for the app menu and scrolling)
    property Item navItem: null
    readonly property var navOffsets: {
        const out = [];
        let n = 0;
        for (const sec of appSections) {
            out.push(n);
            n += sec.apps.length;
        }
        return out;
    }
    readonly property int navCount: appSections.reduce((n, sec) => n + sec.apps.length, 0)
    readonly property bool navShown: navCount > 0 && (navActive || (searching && searchEnterLaunches))
    readonly property var navTile: {
        const p = navPos(navIndex);
        return p ? appSections[p.s].apps[p.l] : null;
    }
    onAppSectionsChanged: navIndex = Math.min(navIndex, Math.max(0, navCount - 1))
    function navResetSelection() {
        navActive = false;
        navIndex = 0;
    }
    function navPos(i) {
        for (let s = appSections.length - 1; s >= 0; s--) {
            if (i >= navOffsets[s])
                return i - navOffsets[s] < appSections[s].apps.length ? { "s": s, "l": i - navOffsets[s] } : null;
        }
        return null;
    }
    // Rows inside one section (each section is its own grid)
    function navVertical(rows) {
        const cols = Math.max(1, appColumns);
        let p = navPos(navIndex);
        if (!p)
            return;
        for (let step = 0; step < Math.abs(rows); step++) {
            const len = appSections[p.s].apps.length;
            const col = p.l % cols;
            if (rows > 0) {
                if (p.l + cols < len)
                    p = { "s": p.s, "l": p.l + cols };
                else if (Math.floor(p.l / cols) < Math.floor((len - 1) / cols))
                    p = { "s": p.s, "l": len - 1 };
                else if (p.s + 1 < appSections.length)
                    p = { "s": p.s + 1, "l": Math.min(col, appSections[p.s + 1].apps.length - 1) };
            } else {
                if (p.l - cols >= 0)
                    p = { "s": p.s, "l": p.l - cols };
                else if (p.s > 0) {
                    const prev = appSections[p.s - 1].apps.length;
                    const lastRow = Math.floor((prev - 1) / cols) * cols;
                    p = { "s": p.s - 1, "l": Math.min(lastRow + col, prev - 1) };
                }
            }
        }
        navIndex = navOffsets[p.s] + p.l;
    }
    function navSection(delta) {
        const p = navPos(navIndex);
        if (!p)
            return;
        const s = Math.max(0, Math.min(appSections.length - 1, p.s + delta));
        navIndex = navOffsets[s];
    }
    // → true when the key was used
    function handleNavKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const move = f => {
            if (navCount === 0)
                return true;
            // First key only shows the selection (on the current tile)
            if (navActive || searching)
                f();
            navActive = true;
            return true;
        };
        switch (event.key) {
        case Qt.Key_Down:
            return move(() => navVertical(1));
        case Qt.Key_Up:
            return move(() => navVertical(-1));
        case Qt.Key_PageDown:
            return move(() => navVertical(appPageRows));
        case Qt.Key_PageUp:
            return move(() => navVertical(-appPageRows));
        case Qt.Key_Right:
            if (!navActive && !ctrl)
                return false;
            return move(() => navIndex = Math.min(navCount - 1, navIndex + 1));
        case Qt.Key_Left:
            if (!navActive && !ctrl)
                return false;
            return move(() => navIndex = Math.max(0, navIndex - 1));
        case Qt.Key_J:
            return ctrl ? move(() => navVertical(1)) : false;
        case Qt.Key_K:
            return ctrl ? move(() => navVertical(-1)) : false;
        case Qt.Key_L:
            return ctrl ? move(() => navIndex = Math.min(navCount - 1, navIndex + 1)) : false;
        case Qt.Key_H:
            return ctrl ? move(() => navIndex = Math.max(0, navIndex - 1)) : false;
        case Qt.Key_N:
            return ctrl ? move(() => navSection(1)) : false;
        case Qt.Key_P:
            return ctrl ? move(() => navSection(-1)) : false;
        case Qt.Key_1:
        case Qt.Key_2:
        case Qt.Key_3:
        case Qt.Key_4:
            if (!ctrl && !(event.modifiers & Qt.AltModifier))
                return false;
            searchScope = searchScopes[event.key - Qt.Key_1].key;
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (navActive && navTile)
                activateTile(navTile);
            else if (searchEnterLaunches && searching && firstResult)
                activateTile(firstResult);
            return true;
        case Qt.Key_Menu:
        case Qt.Key_F10:
            if (navShown && navItem && navTile && !navTile.launcherItem) {
                menuContext = { "type": "apps" };
                appContextMenu.showFor(navItem, navTile, activePopout?.screen ?? parentScreen);
            }
            return true;
        }
        return false;
    }

    // Start a tile of the apps element: an app or a launcher result
    function activateTile(tile) {
        if (!tile)
            return;
        closePopout();
        if (tile.launcherItem)
            launcher.executeItem(tile.launcherItem);
        else
            launchApp(tile);
    }

    // Same identifier as the edit panel and DMS' launcher
    function appKey(app) {
        return app?.id || app?.execString || app?.exec || "";
    }

    function setAppIconColor(key, color) {
        if (!key)
            return;
        const next = Object.assign({}, appIconColors);
        if (color)
            next[key] = color;
        else
            delete next[key];
        saveKey("appIconColors", next);
    }

    // Bar icon colour (glyph icons; empty = DMS text colour)
    readonly property color barIconColor: cfg.barIconColor || Theme.surfaceText
    readonly property int cardMargin: cfg.cardMargin ?? Defaults.cardMargin
    // Docked menus (all but "Free") have their own margin on the side at the
    // bar, frame or island; cardMargin is then for the other three sides.
    readonly property int cardMarginDocked: cfg.cardMarginDocked ?? Defaults.cardMarginDocked
    readonly property int dockedPosition: activePopout?.effectiveBarPosition ?? -1
    readonly property string dockedSide: menuAnchor === "screen" && !freeJoined ? "" : (dockedPosition === SettingsData.Position.Top || dockedPosition === SettingsData.Position.TopCenter) ? "top" : (dockedPosition === SettingsData.Position.Bottom || dockedPosition === SettingsData.Position.BottomCenter) ? "bottom" : dockedPosition === SettingsData.Position.Left ? "left" : dockedPosition === SettingsData.Position.Right ? "right" : ""
    // Free menu joined to the frame (it reaches the bar side; set on opening)
    property bool freeJoined: false
    readonly property int cardMarginTop: dockedSide === "top" ? cardMarginDocked : cardMargin
    readonly property int cardMarginBottom: dockedSide === "bottom" ? cardMarginDocked : cardMargin
    readonly property int cardMarginLeft: dockedSide === "left" ? cardMarginDocked : cardMargin
    readonly property int cardMarginRight: dockedSide === "right" ? cardMarginDocked : cardMargin
    readonly property color cardBaseColor: ColorRoles.resolve(Theme, cardColorMode, cardCustomColor, Theme.cardSurface)
    // "none" = no fill (only border, if any)
    readonly property color cardColor: cardColorMode === "none" ? "transparent" : Theme.withAlpha(cardBaseColor, cardBaseColor.a * (cardTransparent ? 1 - cardTransparency / 100 : 1))

    // App grid
    readonly property int appIconSize: cfg.appIconSize ?? Defaults.appIconSize
    readonly property bool appShowLabels: cfg.appShowLabels ?? Defaults.appShowLabels
    readonly property bool appTooltips: cfg.appTooltips ?? Defaults.appTooltips
    // Tooltip of an app or button: name, for apps also the description
    // (empty title = no tooltip, also while something is dragged)
    function tooltipTitle(app, enabled) {
        return enabled && app && !appDragging ? (app.name || "") : "";
    }
    function tooltipDescription(app) {
        const comment = app?.comment || "";
        return comment !== app?.name ? comment : "";
    }
    // Content alignment in the apps and the buttons element: share of the
    // free space before the content (0 start, 0.5 centered, 1 end)
    function alignShare(v) {
        return v === "end" ? 1 : v === "center" ? 0.5 : 0;
    }
    readonly property real appAlignX: alignShare(cfg.appAlignH ?? Defaults.appAlignH)
    readonly property real appAlignY: alignShare(cfg.appAlignV ?? Defaults.appAlignV)
    // Automatic (setting): everything fits → centered, it scrolls → top
    // (and left). "v" = only vertically (horizontally the fixed setting),
    // "both" = also horizontally (also a single row that is not full),
    // "off" = the fixed settings. Former true/false = both/off.
    readonly property string appAlignAuto: {
        const v = cfg.appAlignAuto ?? Defaults.appAlignAuto;
        return v === true ? "both" : v === false ? "off" : String(v);
    }
    readonly property int cardPadding: cfg.cardPadding ?? Defaults.cardPadding
    // Docked: the side at the bar separately (as the card margin); unset =
    // as the other sides
    readonly property int cardPaddingDocked: cfg.cardPaddingDocked ?? cardPadding
    readonly property int cardPadTop: dockedSide === "top" ? cardPaddingDocked : cardPadding
    readonly property int cardPadBottom: dockedSide === "bottom" ? cardPaddingDocked : cardPadding
    readonly property int cardPadLeft: dockedSide === "left" ? cardPaddingDocked : cardPadding
    readonly property int cardPadRight: dockedSide === "right" ? cardPaddingDocked : cardPadding
    readonly property real appSpacing: cfg.appSpacing ?? Defaults.appSpacing
    readonly property real appRowSpacing: cfg.appRowSpacing ?? Defaults.appRowSpacing
    // Text colour, same pattern as the card colour; "default" = DMS text colour.
    readonly property color appTextColor: catColor("appText", Theme.surfaceText, "allPieceText")

    // Fallback icon (initial letter when an app ships no icon). DMS draws it
    // on surfaceLight, nearly the chip colour and thus hardly visible.
    // Default here: accent surface with matching contrast colour.
    readonly property string fallbackIconColorMode: cfg.fallbackIconColorMode ?? "default"
    readonly property string fallbackIconCustomColor: cfg.fallbackIconCustomColor ?? ""
    readonly property color fallbackIconColor: fallbackIconColorMode === "none" ? "transparent" : ColorRoles.resolve(Theme, fallbackIconColorMode, fallbackIconCustomColor, Theme.primaryContainer)
    readonly property string fallbackLetterColorMode: cfg.fallbackLetterColorMode ?? "default"
    readonly property string fallbackLetterCustomColor: cfg.fallbackLetterCustomColor ?? ""
    readonly property color fallbackLetterColor: fallbackLetterColorMode === "none" ? "transparent" : ColorRoles.resolve(Theme, fallbackLetterColorMode, fallbackLetterCustomColor, Theme.onPrimaryContainer)

    // Chips: the layer below the card, one background per app.
    readonly property bool chipEnabled: cfg.chipEnabled ?? Defaults.chipEnabled
    // Tile size applies without visible chips too (invisible tile then).
    readonly property real chipWidth: cfg.chipWidth ?? Defaults.chipWidth
    readonly property int chipHeight: cfg.chipHeight ?? Defaults.chipHeight

    // Layout as in the DMS launcher: "grid" (icon, name below), "tile" (icon
    // fills the tile, name in a strip at the bottom), "list" (one row per app).
    // Tile building blocks (see components/AppTile.qml). The former layouts
    // grid/tiles/list are presets of these values (set in the settings).
    readonly property bool appShowIcon: cfg.appShowIcon ?? Defaults.appShowIcon
    readonly property bool appShowDescription: cfg.appShowDescription ?? Defaults.appShowDescription
    readonly property string appIconPosition: cfg.appIconPosition ?? Defaults.appIconPosition
    readonly property string appTextAlign: cfg.appTextAlign ?? Defaults.appTextAlign
    readonly property bool appTextBackground: cfg.appTextBackground ?? Defaults.appTextBackground
    readonly property bool appFullWidth: cfg.appFullWidth ?? Defaults.appFullWidth
    readonly property int textSize: inherit("textSize", "allPieceTextSize", Defaults.textSize)
    // Icon of the widget in the bar (Material Symbols name)
    readonly property string barIcon: cfg.barIcon || Defaults.barIcon
    readonly property bool showEditButton: cfg.showEditButton ?? Defaults.showEditButton
    readonly property bool showSettingsButton: cfg.showSettingsButton ?? Defaults.showSettingsButton
    // Chips, tiles, search field: DMS level 4 (nested chip) by default
    readonly property color chipColor: catSurface("chip", Theme.chipSurfaceNested, "allPiece")
    readonly property real chipRadius: Math.min(inherit("chipRadius", "allPieceRadius", Theme.cornerRadius), chipHeight / 2)

    // Same list as the DMS launcher: without hidden apps, with renames from
    // the launcher settings. cacheVersion increases on every change (app
    // installed/removed, hidden …) and forces a recalculation.
    //
    // ── Categories ───────────────────────────────────────────────────────
    // As in the DMS launcher: from Categories= of the .desktop files, merged
    // into main groups (AppSearchService). Plus "All" and "Hidden".
    // Always: the categories element itself is the switch (removed or added
    // in edit mode); the former setting "showCategories" is no longer read
    readonly property bool showCategories: true
    readonly property string categoryStyle: cfg.categoryStyle ?? Defaults.categoryStyle
    readonly property bool showHiddenCategory: cfg.showHiddenCategory ?? Defaults.showHiddenCategory
    property string currentCategory: startCategoryShown

    // Category chips: defaults = DMS' DFilterChips
    readonly property real catChipHeight: cfg.catChipHeight ?? Defaults.catChipHeight
    // Corner radius, at most half the height (fully round, no straight piece)
    readonly property real catChipRadius: Math.min(inherit("catChipRadius", "allPieceRadius", Theme.cornerRadiusS), catChipHeight / 2)
    readonly property real catChipWidth: cfg.catChipWidth ?? Defaults.catChipWidth
    readonly property real catChipSpacing: cfg.catChipSpacing ?? Defaults.catChipSpacing
    readonly property real catChipRowSpacing: cfg.catChipRowSpacing ?? Defaults.catChipRowSpacing
    // Text alignment in the chips; "auto" = one column left, else centred
    readonly property string catTextAlign: cfg.catTextAlign ?? Defaults.catTextAlign
    readonly property real catChipBorderWidth: inherit("catChipBorderWidth", "allPieceBorderWidth", Defaults.catChipBorderWidth)
    // Borders and font weight
    readonly property real cardBorderWidth: cfg.cardBorderWidth ?? Defaults.cardBorderWidth
    readonly property real chipBorderWidth: inherit("chipBorderWidth", "allPieceBorderWidth", Defaults.chipBorderWidth)
    function fontWeight(name) {
        return name === "bold" ? Font.Bold : (name === "medium" ? Theme.fontWeightMedium : Font.Normal);
    }
    readonly property int appTextWeight: fontWeight(inherit("appTextWeight", "allPieceTextWeight", Defaults.appTextWeight))
    readonly property real catTextSize: inherit("catTextSize", "allPieceTextSize", Defaults.catTextSize)
    readonly property int catTextWeight: fontWeight(inherit("catTextWeight", "allPieceTextWeight", Defaults.catTextWeight))
    // Category chips hovered and selected (Categories › Chips): text weight
    // -1 = as the normal chips
    readonly property int catHoverTextWeight: cfg.catChipHoverTextWeight ? fontWeight(cfg.catChipHoverTextWeight) : -1
    readonly property int catSelTextWeight: cfg.catChipSelTextWeight ? fontWeight(cfg.catChipSelTextWeight) : -1

    // Category chip colours (normal, selected, hovered), shared by the
    // category chips and, as their defaults, the scope chips
    readonly property color catChipBorderColor: catColor("catChipBorder", Theme.outlineVariant, "allPieceBorder")
    readonly property color catChipBgColor: catSurface("catChipBg", Theme.chipSurfaceNested, "allPiece")
    readonly property color catChipSelColor: catSurface("catChipSel", Theme.secondaryContainer, "allPieceSel")
    readonly property color catChipTextColor: catColor("catChipText", Theme.onSurfaceVariant, "allPieceText")
    readonly property color catChipSelTextColor: catColor("catChipSelText", Theme.onSecondaryContainer)
    readonly property color catChipSelBorderColor: catColor("catChipSelBorder", "transparent")
    readonly property color catChipHoverColor: catSurface("catChipHoverBg", Theme.withAlpha(Theme.onSurface, Theme.stateLayerHover))
    readonly property color catChipHoverBorderColor: catColor("catChipHoverBorder", catChipBorderColor)
    readonly property color catChipHoverTextColor: catColor("catChipHoverText", catChipTextColor)
    // For the settings page: the chip colours as used, shown beside
    // "as …" (default) in the colour pickers instead of a fixed DMS colour
    readonly property var lookColors: ({
        "instance": instanceId,
        "catChipBg": String(catChipBgColor), "catChipSel": String(catChipSelColor),
        "catChipBorder": String(catChipBorderColor), "catChipText": String(catChipTextColor),
        "catChipSelText": String(catChipSelTextColor), "catChipSelBorder": String(catChipSelBorderColor),
        "catChipHoverBg": String(catChipHoverColor), "catChipHoverBorder": String(catChipHoverBorderColor),
        "catChipHoverText": String(catChipHoverTextColor)
    })
    function publishLookColors() {
        if (sizeShownInSettings)
            publishVar("lookColors", lookColors);
    }
    onLookColorsChanged: Qt.callLater(publishLookColors)
    // Search scope chips (Search › Scope › Chips): own values, each as the
    // category chips until set
    readonly property real scopeChipHeight: cfg.scopeChipHeight ?? catChipHeight
    readonly property real scopeChipRadius: Math.min(cfg.scopeChipRadius ?? catChipRadius, scopeChipHeight / 2)
    readonly property real scopeChipSpacing: cfg.scopeChipSpacing ?? Theme.spacingXS
    readonly property real scopeChipBorderWidth: cfg.scopeChipBorderWidth ?? catChipBorderWidth
    readonly property real scopeTextSize: cfg.scopeTextSize ?? catTextSize
    readonly property int scopeTextWeight: cfg.scopeTextWeight ? fontWeight(cfg.scopeTextWeight) : catTextWeight

    // ── Shared element look (General › Element look) ─────────────────────
    // Each value: the element's own, else the shared one ("allArea…" for
    // the element frame, "allPiece…" for chips, tiles and the search field),
    // else the element's own DMS default. Nothing shared set = every
    // element looks as before.
    // src: where the values come from (default cfg; a tile element's own
    // look laid over cfg)
    function inherit(key, sharedKey, def, src) {
        const c = src ?? cfg;
        const v = c[key];
        if (v !== undefined && v !== null)
            return v;
        const s = sharedKey ? c[sharedKey] : undefined;
        return s !== undefined && s !== null ? s : def;
    }
    // Colour group (mode, custom colour, transparency) of the element, or of
    // the shared prefix when the element is on "Default"
    function lookPrefix(prefix, shared, src) {
        const c = src ?? cfg;
        const own = c[prefix + "ColorMode"];
        if (own && own !== "default")
            return prefix;
        const sm = shared ? c[shared + "ColorMode"] : undefined;
        return sm && sm !== "default" ? shared : prefix;
    }

    // "none" = fully transparent (no text, no line, no fill)
    // Colours of text, borders, icons: with their transparency (own, else
    // the shared one), as the surfaces; noAlpha: the caller applies its own
    // (the search placeholder)
    function catColor(prefix0, fallback, shared, src, noAlpha) {
        const c = src ?? cfg;
        const prefix = lookPrefix(prefix0, shared, c);
        const mode = c[prefix + "ColorMode"] ?? "default";
        if (mode === "none")
            return "transparent";
        const col = ColorRoles.resolve(Theme, mode, c[prefix + "CustomColor"] ?? "", fallback);
        if (noAlpha)
            return col;
        // Own transparency first (also with the colour from the shared
        // setting), else the shared one
        const tPrefix = c[prefix0 + "Transparent"] !== undefined ? prefix0 : shared && c[shared + "Transparent"] !== undefined ? shared : prefix;
        const t = (c[tPrefix + "Transparent"] ?? false) ? (c[tPrefix + "Transparency"] ?? 0) / 100 : 0;
        return t > 0 ? Theme.withAlpha(col, col.a * (1 - t)) : col;
    }
    function catSurface(prefix0, fallback, shared, src) {
        const cfg = src ?? root.cfg;
        const prefix = lookPrefix(prefix0, shared, cfg);
        const mode = cfg[prefix + "ColorMode"] ?? "default";
        // "none" = no fill
        if (mode === "none" || (mode === "default" && fallback === "transparent"))
            return "transparent";
        const c = ColorRoles.resolve(Theme, mode, cfg[prefix + "CustomColor"] ?? "", fallback);
        // Transparency: the element's own, else the shared one (Appearance),
        // also when the shared colour is left at its default
        const tPrefix = cfg[prefix0 + "Transparent"] !== undefined ? prefix0 : shared && cfg[shared + "Transparent"] !== undefined ? shared : prefix;
        const t = (cfg[tPrefix + "Transparent"] ?? false) ? (cfg[tPrefix + "Transparency"] ?? 0) / 100 : 0;
        // Colours with own transparency (e.g. white 85 %) keep it
        return Theme.withAlpha(c, c.a * (1 - t));
    }

    // All categories in their order (setting: category editor), each with
    // kind ("all", "dms", "custom", "hidden") and whether it is hidden from
    // the chips. Default order: All, Favourites, DMS', own, Hidden. Deleted
    // DMS categories are left out; hidden ones stay in the editor.
    readonly property string favoritesKey: "custom:favorites"
    DmsAppLists {
        id: dmsLists
        // DMS' names may arrive translated only later: migrate then
        onCategoriesChanged: Qt.callLater(root.migrateCategoryKeys)
    }
    readonly property var categoryEntries: {
        const allName = I18n.tr("All");
        const map = AppSearchService._categoryMap;
        const dms = dmsLists.categories.filter(c => c !== allName && deletedCategories.indexOf(Defaults.dmsCategoryKey(map, c)) < 0).map(c => ({ "key": Defaults.dmsCategoryKey(map, c), "text": I18n.tr(c), "icon": Defaults.categoryIcon(c, (t, ctx) => ctx ? I18n.tr(t, ctx) : I18n.tr(t), AppSearchService.getCategoryIcon(c)), "kind": "dms" }));
        // Own categories: icon of most categories (as shown, incl. own
        // choices from the icon list), usually DMS' folder; favourites a star
        const counts = {};
        for (const c of dms) {
            const icon = (cfg.catIcons ?? {})[c.key] || c.icon;
            counts[icon] = (counts[icon] ?? 0) + 1;
        }
        const common = Object.keys(counts).sort((a, b) => counts[b] - counts[a])[0] || "folder";
        // Favourites without own name: the translated "Favorites"
        const own = customCategories.map(cc => ({ "key": "custom:" + cc.id, "text": cc.name || (cc.id === "favorites" ? I18n.trFor("customMenu", "Favorites") : ""), "icon": cc.id === "favorites" ? "star" : common, "kind": "custom" }));
        let list = [{ "key": "__all", "text": I18n.trFor("customMenu", "All"), "icon": "apps", "kind": "all" }].concat(own.filter(o => o.key === favoritesKey), dms, own.filter(o => o.key !== favoritesKey), [{ "key": "__hidden", "text": I18n.trFor("customMenu", "Hidden"), "icon": "visibility_off", "kind": "hidden" }]);
        if (categoryOrder.length > 0) {
            const pos = list.map(e => e.key);
            const rank = k => {
                const o = categoryOrder.indexOf(k);
                return o >= 0 ? o : 1000 + pos.indexOf(k);
            };
            list = list.slice().sort((a, b) => rank(a.key) - rank(b.key));
        }
        return list.map(e => Object.assign({}, e, { "hidden": e.kind === "hidden" ? !showHiddenCategory : hiddenCategories.indexOf(e.key) >= 0 }));
    }
    // The chips
    readonly property var categories: categoryEntries.filter(e => !e.hidden)
    // Order of the categories (keys), set in the category editor
    readonly property var categoryOrder: Array.isArray(cfg.categoryOrder) ? cfg.categoryOrder : []
    // DMS categories deleted in the editor (gone from the list; restorable)
    readonly property var deletedCategories: Array.isArray(cfg.deletedCategories) ? cfg.deletedCategories : []
    // Category selected when the menu opens (default: favourites; gone or
    // hidden → All)
    readonly property string startCategory: cfg.startCategory ?? Defaults.startCategory
    // No categories element shown (switched off or not in the menu): there
    // is nothing to switch with, so all apps
    readonly property bool categoriesShown: showCategories && storedLayout.some(i => i.id === "categories")
    readonly property string startCategoryShown: categoriesShown && categories.some(c => c.key === startCategory) ? startCategory : "__all"
    onCategoriesShownChanged: if (!categoriesShown) currentCategory = "__all"
    // The categories as the menu shows them, for the start category choice
    // in the settings (plugin-wide variable per instance)
    readonly property var categoryChoices: categories.map(c => ({ "key": c.key, "text": c.text }))
    onCategoryChoicesChanged: Qt.callLater(() => publishVar("categoryChoices_" + (instanceId || "main"), categoryChoices))

    function moveCategoryTo(from, to) {
        const keys = categoryEntries.map(e => e.key);
        if (from < 0 || from >= keys.length || to < 0 || to >= keys.length || from === to)
            return;
        keys.splice(to, 0, keys.splice(from, 1)[0]);
        saveKey("categoryOrder", keys);
    }
    function setCategoryHidden(key, hidden) {
        if (key === "__hidden") {
            saveKey("showHiddenCategory", !hidden);
            return;
        }
        const next = hiddenCategories.filter(k => k !== key);
        if (hidden)
            next.push(key);
        saveKey("hiddenCategories", next);
    }
    function deleteCategory(entry) {
        if (subsOf(entry.key).length > 0)
            saveSubs(entry.key, []);
        if (entry.kind === "custom")
            deleteCustomCategory(entry.key.slice(7));
        else if (entry.kind === "dms")
            saveKey("deletedCategories", deletedCategories.concat([entry.key]));
        if (currentCategory === entry.key)
            currentCategory = "__all";
    }
    function restoreDeletedCategories() {
        saveKey("deletedCategories", []);
    }
    function setCategoryIcon(key, icon) {
        const next = Object.assign({}, cfg.catIcons ?? {});
        if (icon)
            next[key] = icon;
        else
            delete next[key];
        saveKey("catIcons", next);
    }

    // Favourites: once (fresh install, or the first start with this
    // version) an own category with the 10 most used apps (DMS' usage
    // ranking), as soon as the apps are known. Deleting it is final.
    // In the same step the default tile element, if in the menu and still
    // empty, gets the 4 most used apps (so a fresh install has no empty
    // element; existing menus are seeded already and stay as they are).
    // Fewer than that known (DMS itself new, no usage yet): topped up with
    // the system's default apps (browser, file manager, terminal, editor).
    property bool favoritesSeeding: false
    function seedFavorites() {
        if (favoritesSeeding || cfg.favoritesSeeded || Object.keys(allAppsByKey).length === 0)
            return;
        favoritesSeeding = true;
        defaultAppsProbe.running = true;
    }
    function finishSeeding(defaultApps) {
        const ranked = AppUsageHistoryData.getRankedApps().map(a => a.id).filter(id => !!allAppsByKey[id]);
        const filled = ranked.concat(defaultApps.filter(id => ranked.indexOf(id) < 0));
        // No stored name: shown translated (the translations may not be
        // loaded yet at start)
        const fav = { "id": "favorites", "name": "", "apps": (ranked.length > 0 ? ranked : filled).slice(0, 10) };
        const changes = { "customCategories": [fav].concat(customCategories.filter(c => c.id !== "favorites")), "favoritesSeeded": true };
        const tiles = shortcutsData["shortcuts:default"];
        if (storedLayout.some(i => i.id === "shortcuts:default") && tiles && tiles.tiles.length === 0 && filled.length > 0) {
            const next = JSON.parse(JSON.stringify(shortcutsData));
            next["shortcuts:default"].tiles = filled.slice(0, 4).map((app, n) => ({ "app": app, "size": "small", "col": n, "row": 0 }));
            changes.shortcuts = next;
        }
        saveKeys(changes);
    }
    // The terminal: DMS' setting, else $TERMINAL, else the system's
    // preference (xdg-terminals.list), else the first in DMS' own order,
    // else any terminal app
    function terminalApp(listed) {
        const apps = Object.keys(allAppsByKey).map(k => ({ "key": k, "app": allAppsByKey[k] }));
        const base = v => String(v || "").split(/\s+/)[0].split("/").pop().replace(/\.desktop$/, "");
        const match = name => name ? apps.find(a => a.key === name || a.key.endsWith("." + name) || base(a.app.execString || a.app.exec) === name) : null;
        const names = [base(SessionData.resolveTerminal?.() ?? ""), base(listed)].concat(SessionData.terminalOptions ?? []);
        for (const name of names) {
            const hit = match(name);
            if (hit)
                return hit.key;
        }
        return apps.find(a => (a.app.categories ?? []).indexOf("TerminalEmulator") >= 0)?.key ?? "";
    }
    Process {
        id: defaultAppsProbe
        // Default apps; last line: the preferred terminal (xdg-terminal-exec's list)
        command: ["sh", "-c", "for m in x-scheme-handler/https inode/directory text/plain; do xdg-mime query default \"$m\"; done; echo; grep -hv '^#' \"${XDG_CONFIG_HOME:-$HOME/.config}/xdg-terminals.list\" 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            id: defaultAppsOut
        }
        onExited: {
            const parts = defaultAppsOut.text.split("\n\n");
            const found = parts[0].split("\n").map(l => l.trim().replace(/\.desktop$/, "")).filter(k => !!root.allAppsByKey[k]);
            const term = root.terminalApp((parts[1] ?? "").trim());
            // Browser, file manager, terminal, editor
            const list = found.slice(0, 2).concat(term ? [term] : [], found.slice(2));
            root.finishSeeding(list.filter((k, n) => list.indexOf(k) === n));
        }
    }
    onAllAppsByKeyChanged: Qt.callLater(seedFavorites)

    // Apps added to a category by drag & drop: { category: [appKey, …] }.
    // Only adds; DMS' own categories of an app stay.
    readonly property var categoryExtras: cfg.categoryExtras ?? ({})
    // Apps taken out of a DMS category they have by their start file
    // ({ category: [appKey, …] }; dragged onto the remove target)
    readonly property var categoryRemovals: cfg.categoryRemovals ?? ({})
    // Where assignments made in the menu apply: "both" = CustomMenu and DMS
    // launcher (own start file in ~/.local/share/applications; hiding via
    // DMS), "menu" = CustomMenu only (kept in the plugin data)
    readonly property string categoryScope: cfg.categoryScope ?? Defaults.categoryScope
    readonly property var localHiddenApps: cfg.localHiddenApps ?? []
    // Own categories (CustomMenu only; DMS' category list is fixed):
    // [{ id, name, icon, apps: [appKey, …] }]
    readonly property var customCategories: cfg.customCategories ?? []
    // DMS categories removed from the chips (key = DMS category name)
    readonly property var hiddenCategories: cfg.hiddenCategories ?? []

    function saveCustomCategories(list) {
        saveKey("customCategories", list);
    }
    function addCustomCategory() {
        const base = I18n.trFor("customMenu", "New category");
        let name = base, n = 2;
        while (customCategories.some(c => c.name === name))
            name = base + " " + n++;
        saveCustomCategories(customCategories.concat([{ "id": "c" + Date.now(), "name": name, "apps": [] }]));
    }
    function renameCustomCategory(id, name) {
        if (name.trim() && name.trim() !== categoryEntries.find(e => e.key === "custom:" + id)?.text)
            saveCustomCategories(customCategories.map(c => c.id === id ? Object.assign({}, c, { "name": name.trim() }) : c));
    }
    function deleteCustomCategory(id) {
        saveCustomCategories(customCategories.filter(c => c.id !== id));
        if (currentCategory === "custom:" + id)
            currentCategory = "__all";
    }
    function setDmsCategoryHidden(key, hidden) {
        const next = hiddenCategories.filter(k => k !== key);
        if (hidden)
            next.push(key);
        saveKey("hiddenCategories", next);
    }

    function dmsCategoryName(key) {
        return Defaults.dmsCategoryName(AppSearchService._categoryMap, key);
    }
    // Data stored before 31.10.2026 has DMS categories by their translated
    // name: to the language-independent key (Defaults.dmsCategoryKey).
    // Names of another language than the current one stay until DMS runs
    // in that language again.
    function migrateCategoryKeys() {
        const map = AppSearchService._categoryMap ?? {};
        const conv = k => typeof k === "string" && !k.startsWith("dms:") && !k.startsWith("custom:") && !k.startsWith("__") ? Defaults.dmsCategoryKey(map, k) : k;
        const changes = {};
        for (const key of ["deletedCategories", "hiddenCategories", "categoryOrder"]) {
            const list = instanceData[key];
            if (Array.isArray(list) && list.some(k => conv(k) !== k))
                changes[key] = list.map(conv);
        }
        for (const key of ["catIcons", "catIconColors", "categoryExtras", "categoryRemovals", "subcategories"]) {
            const obj = instanceData[key];
            if (!obj || typeof obj !== "object" || !Object.keys(obj).some(k => conv(k) !== k))
                continue;
            const next = {};
            for (const k of Object.keys(obj))
                next[conv(k)] = obj[k];
            changes[key] = next;
        }
        if (typeof instanceData.startCategory === "string" && conv(instanceData.startCategory) !== instanceData.startCategory)
            changes.startCategory = conv(instanceData.startCategory);
        if (Object.keys(changes).length > 0)
            saveKeys(changes);
    }
    // DMS category name → freedesktop category (first entry of DMS' own map)
    function freedesktopCategoryFor(dmsName) {
        return freedesktopCategoriesFor(dmsName)[0] ?? "";
    }
    // All freedesktop categories DMS shows as this category
    function freedesktopCategoriesFor(dmsName) {
        const map = AppSearchService._categoryMap ?? {};
        return Object.keys(map).filter(k => map[k] === dmsName);
    }

    // Writing the own start file: load (async), then save once ready
    property var pendingDesktopEdit: null
    DesktopFileOverride {
        id: categoryOverride
        onReadyChanged: {
            const edit = root.pendingDesktopEdit;
            if (!ready || !edit)
                return;
            root.pendingDesktopEdit = null;
            // Only existing start files (an app without one has no .desktop id)
            if (sourceText !== "")
                save(edit);
        }
    }

    // ── Drag & drop of apps ──────────────────────────────────────────────
    // An app tile dragged (past a small threshold) shows its icon under the
    // mouse (dragProxy). Targets: category chip (add to the category;
    // "Hidden" hides the app, "All" does nothing), shortcut group (add),
    // empty canvas (new shortcuts element there with the app).
    property var dragApp: null
    property bool appDragging: false
    property Item dragProxy: null

    // Where the dragged app comes from: null (apps element) or
    // { elementId, groupId } of a shortcut group (then it is moved)
    property var dragFrom: null

    function startAppDrag(app, source, x, y, from) {
        if (!dragProxy)
            return;
        dragApp = app;
        dragFrom = from ?? null;
        moveAppDrag(source, x, y);
        appDragging = true;
    }
    function moveAppDrag(source, x, y) {
        if (!dragProxy)
            return;
        const p = source.mapToItem(dragProxy.parent, x, y);
        dragProxy.x = p.x - dragProxy.width / 2;
        dragProxy.y = p.y - dragProxy.height / 2;
    }
    // Drop handlers run synchronously inside drop(); then clean up
    function endAppDrag() {
        dragHover = null;
        if (appDragging && dragProxy)
            dragProxy.Drag.drop();
        appDragging = false;
        dragApp = null;
        dragFrom = null;
    }

    function dropOnCategory(key) {
        const app = dragApp;
        const appId = appKey(app);
        // Buttons are no apps
        if (!app || !appId || key === "__all" || String(appId).startsWith("act:"))
            return;
        if (key === "__hidden") {
            if (categoryScope === "both")
                SessionData.hideApp(appId);
            else if (localHiddenApps.indexOf(appId) < 0)
                saveKey("localHiddenApps", localHiddenApps.concat([appId]));
            return;
        }
        if (key.startsWith("custom:")) {
            saveCustomCategories(customCategories.map(c => "custom:" + c.id === key && c.apps.indexOf(appId) < 0 ? Object.assign({}, c, { "apps": c.apps.concat([appId]) }) : c));
            return;
        }
        // Taken out before: back in
        const removed = categoryRemovals[key] ?? [];
        if (removed.indexOf(appId) >= 0) {
            const next = Object.assign({}, categoryRemovals);
            next[key] = removed.filter(k => k !== appId);
            if (next[key].length === 0)
                delete next[key];
            saveKey("categoryRemovals", next);
        }
        const name = dmsCategoryName(key);
        if (AppSearchService.getCategoriesForApp(app).includes(name))
            return;
        // CustomMenu: right away via the plugin data
        const list = categoryExtras[key] ?? [];
        if (list.indexOf(appId) < 0) {
            const next = Object.assign({}, categoryExtras);
            next[key] = list.concat([appId]);
            saveKey("categoryExtras", next);
        }
        // DMS launcher too: own start file with the category
        const fd = freedesktopCategoryFor(name);
        if (categoryScope === "both" && fd && app.id) {
            pendingDesktopEdit = { "addCategory": fd };
            categoryOverride.load(app.id);
        }
    }

    // Remove target (an X shown while dragging): the dragged app leaves
    // where it came from, its tile element or the category shown. Not in
    // "All" and not in search results (no category to leave).
    readonly property bool dragCanRemove: appDragging && (dragFrom !== null || (!searching && categoriesShown && currentCategory !== "__all" && !String(appKey(dragApp)).startsWith("act:")))
    function dropOnRemove() {
        const app = dragApp;
        const appId = appKey(app);
        if (!appId || !dragCanRemove)
            return;
        if (dragFrom)
            scRemoveApp(dragFrom.elementId, appId);
        else
            removeFromCategory(app, currentCategory);
    }
    function removeFromCategory(app, key) {
        const appId = appKey(app);
        // Out of the category's sub-categories as well
        if (realSubsOf(key).some(x => (x.apps ?? []).indexOf(appId) >= 0))
            moveAppToSubcategory(key, "", appId);
        if (key === "__hidden") {
            if (AppSearchService.isAppHidden(app))
                SessionData.showApp(appId);
            if (localHiddenApps.indexOf(appId) >= 0)
                saveKey("localHiddenApps", localHiddenApps.filter(k => k !== appId));
            return;
        }
        if (key.startsWith("custom:")) {
            saveCustomCategories(customCategories.map(c => "custom:" + c.id === key ? Object.assign({}, c, { "apps": c.apps.filter(k => k !== appId) }) : c));
            return;
        }
        // DMS category: an own addition goes
        const extra = categoryExtras[key] ?? [];
        if (extra.indexOf(appId) >= 0) {
            const next = Object.assign({}, categoryExtras);
            next[key] = extra.filter(k => k !== appId);
            if (next[key].length === 0)
                delete next[key];
            saveKey("categoryExtras", next);
        }
        // One from the app's start file: left out in CustomMenu, and in
        // the DMS launcher too via the own start file
        const name = dmsCategoryName(key);
        if (AppSearchService.getCategoriesForApp(app).includes(name)) {
            const removed = categoryRemovals[key] ?? [];
            if (removed.indexOf(appId) < 0) {
                const next = Object.assign({}, categoryRemovals);
                next[key] = removed.concat([appId]);
                saveKey("categoryRemovals", next);
            }
            const fds = freedesktopCategoriesFor(name);
            if (categoryScope === "both" && fds.length > 0 && app.id) {
                pendingDesktopEdit = { "removeCategories": fds };
                categoryOverride.load(app.id);
            }
        }
    }

    // Drop on inner cell (col, row) of a shortcuts element. From another
    // shortcuts element the app is moved, from the apps element added.
    function dropOnShortcuts(elementId, col, row) {
        const appId = appKey(dragApp);
        if (!appId)
            return;
        const from = dragFrom;
        const isButton = String(appId).startsWith("act:");
        // A button moved to another element takes its definition along
        // (saved together with the tiles below)
        let defs = null;
        if (isButton && from && from.elementId !== elementId) {
            defs = Object.assign({}, shortcutsData[elementId]?.defs ?? {});
            defs[appId] = shortcutsData[from.elementId]?.defs?.[appId] ?? { "kind": "command" };
        }
        const size = (from ? scData(from.elementId).tiles.find(t => t.app === appId)?.size : null) ?? "small";
        if (from && from.elementId !== elementId)
            scRemoveApp(from.elementId, appId);
        const d = scData(elementId);
        if (isFlowElement(elementId)) {
            // Buttons: inserted into the order, the width stays
            const data = { "tiles": flowDrop(elementId, d.tiles, tileColumns(elementId), appId, size, col, row) };
            if (defs)
                data.defs = defs;
            saveSc(elementId, data);
            return;
        }
        // Dropped into the extra column: the element gets that column
        const tiles = tilesWithDrop(d.tiles, Math.max(1, d.columns) + 1, appId, size, col, row);
        const extent = packTiles(tiles, Math.max(1, d.columns) + 1).reduce((m, p) => Math.max(m, p.col + p.w), 1);
        const data = { "tiles": tiles, "columns": Math.max(d.columns, extent) };
        if (defs)
            data.defs = defs;
        saveSc(elementId, data);
    }

    // Canvas: cell under the drop point; only free cells (not on an element).
    // New shortcuts element with the app as small tile (sizes itself).
    function dropOnCanvas(col, row) {
        const appId = appKey(dragApp);
        if (!appId)
            return;
        if (layoutItems.some(i => col >= i.col && col < i.col + i.w && row >= i.row && row < i.row + i.h))
            return;
        const isButton = String(appId).startsWith("act:");
        const def = isButton && dragFrom ? shortcutsData[dragFrom.elementId]?.defs?.[appId] : null;
        if (dragFrom)
            scRemoveApp(dragFrom.elementId, appId);
        // A new tile element: a button one flowing, an app one on the grid
        const id = "tiles:" + Date.now();
        const defs = {};
        if (def)
            defs[appId] = def;
        saveSc(id, { "title": "", "tiles": [{ "app": appId, "size": "small", "col": 0, "row": 0 }], "columns": 4, "defs": defs, "arrangement": isButton ? "flow" : "grid" });
        const cells = scElementCells(isButton ? 4 : 1, 1, "", id);
        const item = { "id": id, "col": Math.max(0, Math.min(gridColumns - cells.w, col)), "row": Math.max(0, Math.min(gridRows - cells.h, row)), "w": cells.w, "h": cells.h };
        saveLayout(fitLayout(storedLayout.concat([item])).items);
    }

    // Menu cells a shortcuts element needs for cols × rows inner cells
    // (inner padding, element gap and the title line included)
    function scElementCells(cols, rows, title, elementId) {
        const look = lookOf(elementId);
        const pad = (areaStyleFor(elementId ?? "tiles")?.padding ?? 0) * 2 + elementGap;
        const band = scTitleBand(title, look);
        const pxW = cols * look.unit + (cols - 1) * look.spacing + pad + band.w;
        const pxH = rows * look.unit + (rows - 1) * look.spacing + pad + band.h;
        return { "w": Math.max(1, Math.ceil(pxW / Math.max(1, layoutColumnWidth))), "h": Math.max(1, Math.ceil(pxH / Math.max(1, layoutRowUnit))) };
    }

    // Size of a shortcuts element in menu cells, from its packed content
    // (at least 1 × 1 inner cell; an empty element 4 × 1 as a drop target)
    function scWantedCells(id) {
        const d = scData(id);
        const placed = packFor(id, d.tiles.filter(t => !!tileObject(id, t.app)), Math.max(1, d.columns));
        // Empty: as wide as its columns (set by dragging its width)
        const cols = placed.length ? placed.reduce((m, t) => Math.max(m, t.col + t.w), 1) : Math.max(1, d.columns);
        const rows = placed.length ? placed.reduce((m, t) => Math.max(m, t.row + t.h), 1) : 1;
        return scElementCells(cols, rows, d.title, id);
    }

    // Tile elements are sized freely (grid and row); their inner columns
    // and rows follow the size (see scElement)

    // Edit mode: the width of a shortcuts element sets its inner columns
    function scColumnsFromCells(id, w) {
        const look = lookOf(id);
        const pad = (areaStyleFor(id)?.padding ?? 0) * 2 + elementGap;
        const px = w * layoutColumnWidth - pad;
        return Math.max(1, Math.floor((px + look.spacing) / (look.unit + look.spacing)));
    }

    // Selected category disappeared (e.g. "Hidden" turned off) → All
    onCategoriesChanged: if (!categories.some(c => c.key === currentCategory)) currentCategory = startCategoryShown

    // ── Layout ───────────────────────────────────────────────────────────────
    // The menu is a grid of elements (search, categories, apps). In edit mode
    // they can be dragged, snapped and resized; stored as "layout".
    // Cells of about Defaults.gridCell px, an even number of columns and
    // rows (so there is a true middle), as many as fit best into the canvas
    // inside its padding; the grid fills that room exactly (see layoutArea),
    // so the cells are a fraction of a pixel off square and the margins to
    // the canvas edge are equal on all sides. Larger
    // distances between elements come from empty cells, the minimum distance
    // is elementGap. The layout is stored in "layoutGrid" units of the width
    // and of the height (thousandths; before: 48ths, 12ths without the key)
    // and scaled to the current columns/rows on reading (rounded to whole
    // cells; the fit below sorts out overlaps), so it keeps its proportions
    // when the menu size changes.
    property real layoutAreaWidth: 0
    property real layoutAreaHeight: 0
    readonly property int gridColumns: layoutAreaWidth > 0 ? 2 * Math.max(1, Math.round(layoutAreaWidth / (2 * Defaults.gridCell))) : 48
    readonly property int gridRows: layoutAreaHeight > 0 ? 2 * Math.max(1, Math.round(layoutAreaHeight / (2 * Defaults.gridCell))) : 48
    // Edit mode: grid lines (button beside the pencil)
    readonly property bool showGridLines: cfg.editShowGrid ?? Defaults.editShowGrid
    readonly property var elementTypes: ["search", "categories", "apps", "tiles"]
    // Tile elements (several allowed): apps and buttons, see tileMode
    function isTileElement(id) {
        return elementType(id) === "tiles";
    }
    // Element id → type: unique elements use the type as id, shortcuts
    // (several allowed) "shortcuts:<n>"
    function elementType(id) {
        const t = String(id).split(":")[0];
        // Former shortcuts and buttons elements are tile elements
        return t === "shortcuts" || t === "actions" ? "tiles" : t;
    }
    // In 24 units, scaled like a stored layout
    readonly property var defaultLayout: Defaults.defaultLayout

    function scaleLayout(items, from, to) {
        if (!(from > 0) || !(to > 0))
            return items;
        if (from === to)
            return items.map(i => ({ "id": i.id, "col": i.col, "row": i.row, "w": i.w, "h": i.h }));
        const f = to / from;
        return items.map(i => {
            const col = Math.round(i.col * f);
            const row = Math.round(i.row * f);
            return {
                "id": i.id,
                "col": col,
                "row": row,
                "w": Math.max(1, Math.round((i.col + i.w) * f) - col),
                "h": Math.max(1, Math.round((i.row + i.h) * f) - row)
            };
        });
    }

    // Layout scaling and free areas: LayoutFit.js
    function scaleLayoutXY(items, from, toCols, toRows) {
        return LayoutFit.scaleLayoutXY(items, from, toCols, toRows);
    }
    function layoutToStore(items) {
        return LayoutFit.layoutToStore(items, gridColumns, gridRows, Defaults.layoutStoreGrid);
    }

    readonly property var storedLayout: {
        const stored = cfg.layout;
        if (!Array.isArray(stored) || stored.length === 0)
            return scaleLayoutXY(defaultLayout, Defaults.defaultLayoutGrid, gridColumns, gridRows);
        return scaleLayoutXY(stored, cfg.layoutGrid ?? 12, gridColumns, gridRows);
    }

    // Shown layout: categories turned off → element disappears; then fitted
    // into the grid (never outside the menu, never smaller than an
    // element needs; the search element exactly as high as the field).
    // Only shown fitted; saved on the next change in edit mode, so making
    // the menu bigger again restores the stored layout where it fits.
    readonly property var layoutFit: fitLayout(storedLayout.filter(i => i.id !== "categories" || showCategories))
    readonly property var layoutItems: layoutFit.items
    // Menu too small for all elements at their minimum size
    readonly property bool layoutOverflow: layoutFit.overflow

    // Locked elements (lock in edit mode) stay where they are stored: the
    // fit places them first, the grid's pushing is undone on commit
    readonly property var lockedElements: Array.isArray(cfg.lockedElements) ? cfg.lockedElements : []
    // keep: further ids that must not move (e.g. all others while adding)
    function fitLayout(items, firstId, keep) {
        const locked = lockedElements.concat(keep ?? []).filter(id => items.some(i => i.id === id));
        const fixed = items.map(i => {
            const stored = locked.indexOf(i.id) >= 0 ? storedLayout.find(o => o.id === i.id) : null;
            return stored ? Object.assign({}, i, { "col": stored.col, "row": stored.row, "w": stored.w, "h": stored.h }) : i;
        });
        return LayoutFit.fit(fixed, gridColumns, gridRows, id => minRows(id), id => elementType(id) === "search" ? minRows("search") : 0, "apps", locked.concat(firstId ? [firstId] : []));
    }
    property bool layoutEditing: false
    property real appRowInset: 0
    // Content areas, reported by the elements
    property real appsAreaWidth: 0
    property real appsAreaHeight: 0
    property real catAreaWidth: 0
    property real catAreaHeight: 0
    property int catChipColumns: 1
    property int catTotalRows: 0


    // Width a category chip needs to show the longest name in full: text
    // (measured in the chips' font), padding on both sides (CategoryChips:
    // spacingL), icon + gap if shown, a little slack for rounding
    readonly property real catMinChipWidth: {
        let widest = 0;
        for (let i = 0; i < catTextProbe.count; i++)
            widest = Math.max(widest, catTextProbe.itemAt(i)?.implicitWidth ?? 0);
        const icon = (cfg.catShowIcons ?? Defaults.catShowIcons) ? (cfg.catIconSize ?? Defaults.catIconSize) + Theme.spacingS : 0;
        return Math.ceil(widest + Theme.spacingL * 2 + icon + 2);
    }

    // Invisible texts, one per category, same font as the chips
    Item {
        visible: false
        Repeater {
            id: catTextProbe
            model: root.categories
            StyledText {
                required property var modelData
                text: modelData.text
                font.pixelSize: root.catTextSize
                font.weight: root.catTextWeight
            }
        }
    }

    // Element sizes do not change the chips: a chip is never shown wider
    // than its element, and an element too small for its content scrolls
    // Set by the layout area: height of one cell and the gap
    property real layoutRowUnit: 16
    property real layoutColumnWidth: 16
    property real layoutGap: 4
    // Only true sizes count: until the menu was laid out once the cell size
    // above is a placeholder (auto sizing would store wrong element sizes)
    property bool layoutMeasured: false

    readonly property int searchHeight: cfg.searchHeight ?? Defaults.searchHeight
    // Search field look, same options as the category chips. Defaults =
    // DMS' DTextField values.
    // Default like the category chips (both are chips/fields of the shared look)
    readonly property real searchRadius: Math.min(inherit("searchRadius", "allPieceRadius", Theme.cornerRadiusS), searchHeight / 2)
    readonly property int searchBorderWidth: inherit("searchBorderWidth", "allPieceBorderWidth", Theme.outlineWidth)
    readonly property real searchTextSize: inherit("searchTextSize", "allPieceTextSize", Theme.fontSizeMedium)
    readonly property bool searchShowIcon: cfg.searchShowIcon ?? Defaults.searchShowIcon
    readonly property string searchIconName: cfg.searchIconName || Defaults.searchIconName
    // Drawn by us (FlexIcon in the field's leading slot): a file or a logo
    readonly property bool searchIconIsFile: searchIconName.startsWith("/") || searchIconName.startsWith("logo:")
    // Hint text ("Search apps"): own colour, by default half transparent
    readonly property color searchHintBaseColor: catColor("searchPlaceholder", Theme.onSurfaceVariant, "allPieceText", undefined, true)
    readonly property bool searchHintTransparent: cfg.searchPlaceholderTransparent ?? Defaults.searchPlaceholderTransparent
    readonly property int searchHintTransparency: cfg.searchPlaceholderTransparency ?? Defaults.searchPlaceholderTransparency
    // The placeholder's own transparency on top of its colour's (a colour
    // with transparency, e.g. black 85 %, stays that light, never darker)
    // (and the shared text transparency of Appearance › Level 4)
    readonly property real sharedTextAlpha: (cfg.allPieceTextTransparent ?? false) ? 1 - (cfg.allPieceTextTransparency ?? 0) / 100 : 1
    readonly property color searchHintColor: Theme.withAlpha(searchHintBaseColor, searchHintBaseColor.a * sharedTextAlpha * (searchHintTransparent ? 1 - searchHintTransparency / 100 : 1))
    // Optionally hidden as soon as text is typed (the text moves to the left)
    readonly property bool searchHideIconWhileTyping: cfg.searchHideIconWhileTyping ?? Defaults.searchHideIconWhileTyping
    readonly property bool searchIconVisible: searchShowIcon && !(searchHideIconWhileTyping && searchQuery !== "")

    // Own background and border per element (search, categories, apps), so
    // the card can be switched off and the elements still stand apart.
    // Default: none. With either, the content moves in by the padding.
    readonly property var areaPrefixes: ({ "search": "searchArea", "categories": "catArea", "apps": "appsArea", "tiles": "tlArea" })
    // Default background per element type: none, shortcuts stand out
    function makeAreaStyle(prefix, src) {
        const c = src ?? cfg;
        // Default for every element: no background (General ›
        // Element backgrounds or a template can set one)
        // Default: DMS level 3 (chip); our levels follow DMS' surfaces
        const color = catSurface(prefix, Theme.chipSurface, "allArea", c);
        const borderWidth = inherit(prefix + "BorderWidth", "allAreaBorderWidth", 0, c);
        const colorPrefix = lookPrefix(prefix, "allArea", c);
        const visible = color.a > 0 || (c[colorPrefix + "ColorMode"] ?? "default") !== "default" || borderWidth > 0;
        return {
            "color": color,
            "borderWidth": borderWidth,
            "borderColor": catColor(prefix + "Border", Theme.outlineVariant, "allAreaBorder", c),
            "radius": inherit(prefix + "Radius", "allAreaRadius", Theme.cornerRadius, c),
            "padding": visible ? inherit(prefix + "Padding", "allAreaPadding", Defaults.areaPadding, c) : 0,
            // Blur behind the element's background (own menu surface only)
            "blur": inherit(prefix + "Blur", "allAreaBlur", false, c) === true
        };
    }
    readonly property var areaStyle: {
        const result = {};
        for (const id of Object.keys(areaPrefixes))
            result[id] = makeAreaStyle(areaPrefixes[id]);
        return result;
    }
    // Per element: tile elements with own values have their own frame
    readonly property var tileAreaStyles: {
        const out = {};
        for (const id of shortcutsElements) {
            const own = tileLookValues[id];
            if (own && Object.keys(own).some(k => k.startsWith("tlArea")))
                out[id] = makeAreaStyle("tlArea", Object.assign({}, cfg, own));
        }
        return out;
    }
    function areaStyleFor(elementId) {
        return tileAreaStyles[elementId] ?? areaStyle[elementType(elementId)];
    }

    // Gap between neighbouring elements in px (set in edit mode by clicking
    // a gap, or in General › Background)
    readonly property real elementGap: cfg.elementGap ?? Defaults.elementGap

    function minRows(id) {
        const type = elementType(id);
        // Element padding on both sides plus the element gap (inset)
        const pad = (areaStyleFor(id)?.padding ?? 0) * 2 + elementGap;
        const need = pad + (type === "search" ? searchHeight + searchScopeExtra : type === "categories" ? catChipHeight : type === "tiles" ? lookOf(id).unit : layoutRowUnit * 3);
        return Math.max(1, Math.ceil((need + layoutGap) / (layoutRowUnit + layoutGap)));
    }

    // ── Undo (edit mode) ─────────────────────────────────────────────────
    // Before a change in edit mode the arrangement, the element contents
    // and the locks are remembered; saves within 800 ms count as one step
    // (one action often saves several times). Cleared when edit mode ends.
    readonly property var undoKeys: ["layout", "layoutGrid", "shortcuts", "lockedElements", "tileLooks"]
    property var undoStack: []
    property real undoLast: 0
    property bool undoSuspended: false
    function undoCheckpoint() {
        if (!layoutEditing || undoSuspended)
            return;
        const now = Date.now();
        const sameStep = now - undoLast < 800;
        undoLast = now;
        if (sameStep)
            return;
        const snap = {};
        for (const k of undoKeys)
            snap[k] = instanceData[k] === undefined ? undefined : JSON.parse(JSON.stringify(instanceData[k]));
        undoStack = undoStack.concat([snap]).slice(-50);
    }
    function undo() {
        if (undoStack.length === 0)
            return;
        const snap = undoStack[undoStack.length - 1];
        undoStack = undoStack.slice(0, -1);
        undoSuspended = true;
        // One write for all keys
        const changes = {};
        for (const k of undoKeys)
            changes[k] = snap[k];
        saveKeys(changes);
        undoLast = 0;
        // Follow-up saves (sizes fitted again) are not new steps
        undoResume.restart();
    }
    Timer {
        id: undoResume
        interval: 800
        onTriggered: root.undoSuspended = false
    }

    function saveLayout(items) {
        undoCheckpoint();
        const clean = items.map(i => ({ "id": i.id, "col": i.col, "row": i.row, "w": i.w, "h": i.h }));
        // Keep a hidden categories element so it returns at its place
        const hidden = storedLayout.filter(i => i.id === "categories" && !showCategories);
        // One write: grid units and layout together
        saveKeys({ "layoutGrid": Defaults.layoutStoreGrid, "layout": layoutToStore(clean.concat(hidden)) });
    }

    // Compact (button in the settings): all spacings 0 and the menu, in
    // pixels, shrunk to its elements (their bounding box in whole cells, an
    // even number like the grid); the layout is stretched to fill it.
    // Spacings can be added again afterwards.
    function compactMenu() {
        const items = layoutItems;
        if (items.length === 0)
            return;
        const c0 = Math.min(...items.map(i => i.col)), r0 = Math.min(...items.map(i => i.row));
        const bw = Math.max(...items.map(i => i.col + i.w)) - c0, bh = Math.max(...items.map(i => i.row + i.h)) - r0;
        const even = n => 2 * Math.max(1, Math.ceil(n / 2));
        // Room outside the grid that is no spacing (DMS' popout header)
        const spacingW = cardPadLeft + cardPadRight - elementGap, spacingH = cardPadTop + cardPadBottom - elementGap;
        const extraW = layoutAreaWidth > 0 ? Math.max(0, Math.round(popoutWidth - layoutAreaWidth - cardMarginLeft - cardMarginRight - spacingW)) : 0;
        const extraH = layoutAreaHeight > 0 ? Math.max(0, Math.round(popoutHeight - layoutAreaHeight - cardMarginTop - cardMarginBottom - spacingH)) : 0;
        const n = Defaults.layoutStoreGrid;
        const layout = items.map(i => {
            const col = Math.round((i.col - c0) * n / bw), row = Math.round((i.row - r0) * n / bh);
            return { "id": i.id, "col": col, "row": row, "w": Math.round((i.col - c0 + i.w) * n / bw) - col, "h": Math.round((i.row - r0 + i.h) * n / bh) - row };
        });
        const changes = {
            "menuSizeMode": "pixels",
            "menuSizePixels": undefined,
            "menuWidth": even(bw) * Defaults.gridCell + extraW,
            "menuHeight": even(bh) * Defaults.gridCell + extraH,
            "cardMargin": 0,
            "cardMarginDocked": 0,
            "cardPadding": 0,
            "cardPaddingDocked": 0,
            "elementGap": 0,
            "allAreaPadding": 0,
            "layoutGrid": n,
            "layout": layout
        };
        // Own paddings of single elements
        for (const p of Object.values(areaPrefixes))
            changes[p + "Padding"] = undefined;
        // A template with its own size active: the size is a change to it
        if (sizeFromTemplate) {
            changes.profileSize = { "menuSizeMode": "pixels", "menuWidth": changes.menuWidth, "menuHeight": changes.menuHeight };
            for (const key of Templates.sizeKeys)
                delete changes[key];
        }
        const looks = JSON.parse(JSON.stringify(tileLookValues));
        for (const id of Object.keys(looks))
            delete looks[id].tlAreaPadding;
        changes.tileLooks = looks;
        saveKeys(changes);
    }

    function largestFreeArea(items) {
        return LayoutFit.largestFreeArea(items, gridColumns, gridRows);
    }

    // Adds an element of wanted size w × h in the middle of the largest free
    // area (smaller to fit it, not below what the element needs); the other
    // elements keep their places
    function placeNewElement(id, w, h) {
        const items = layoutItems;
        const area = largestFreeArea(items);
        const minH = minRows(id);
        const ew = area.w > 0 ? Math.max(1, Math.min(w, area.w)) : w;
        const eh = area.w > 0 ? Math.max(minH, Math.min(h, area.h)) : h;
        const col = area.w > 0 ? area.col + Math.floor((area.w - ew) / 2) : 0;
        const row = area.w > 0 ? area.row + Math.floor(Math.max(0, area.h - eh) / 2) : 0;
        const others = items.map(i => i.id);
        saveLayout(fitLayout(items.concat([{ "id": id, "col": col, "row": Math.min(row, gridRows - eh), "w": ew, "h": eh }]), undefined, others).items);
    }

    function addElement(type) {
        // Tile elements: a new one, empty, on the grid
        const id = type === "tiles" ? "tiles:" + Date.now() : type;
        if (type === "tiles") {
            saveSc(id, { "title": "", "tiles": [], "arrangement": "grid" });
            const cells = scElementCells(4, 4, "", id);
            placeNewElement(id, cells.w, cells.h);
            return;
        }
        const w = Math.round(Defaults.newElementW * gridColumns / Defaults.defaultLayoutGrid);
        const h = type === "search" ? minRows(id) : Math.max(minRows(id), Math.round(Defaults.newElementH * gridRows / Defaults.defaultLayoutGrid));
        placeNewElement(id, w, h);
    }

    function removeElement(id) {
        saveLayout(storedLayout.filter(i => i.id !== id));
        // Without the categories element nothing can be chosen: open with
        // all apps (the setting can be changed again afterwards)
        if (id === "categories")
            saveKey("startCategory", "__all");
        if (isTileElement(id)) {
            dropShortcutsData(id);
            if (tileLookValues[id]) {
                const looks = Object.assign({}, tileLookValues);
                delete looks[id];
                saveKey("tileLooks", looks);
            }
        }
        if (elementEditing === id)
            elementEditing = "";
    }

    function elementTitle(id) {
        switch (elementType(id)) {
        case "search":
            return I18n.trFor("customMenu", "Search");
        case "categories":
            return I18n.trFor("customMenu", "Categories");
        case "tiles": {
            const n = shortcutsElements.indexOf(id);
            return shortcutsElements.length > 1 && n >= 0 ? I18n.trFor("customMenu", "Tiles") + " " + (n + 1) : I18n.trFor("customMenu", "Tiles");
        }
        default:
            return I18n.trFor("customMenu", "Apps");
        }
    }

    // Element pen (edit mode): which element manages its content right now
    // (shortcuts: groups; categories: categories). "" = none.
    property string elementEditing: ""
    // Edit mode: the element clicked last (framed); its tools offer
    // aligning it in the menu. alignMenu: "h"/"v" while a choice is open.
    property string focusedElement: ""
    property string alignMenu: ""
    onLayoutEditingChanged: if (!layoutEditing) {
        elementEditing = "";
        focusedElement = "";
        alignMenu = "";
        undoStack = [];
    }
    onFocusedElementChanged: {
        alignMenu = "";
    }

    // Grid placement order with the locked elements in front
    function lockedFirst(items, order) {
        const isLocked = i => lockedElements.indexOf(items[i]?.id) >= 0;
        return order.filter(isLocked).concat(order.filter(i => !isLocked(i)));
    }
    function toggleLock(id) {
        const list = lockedElements.indexOf(id) >= 0 ? lockedElements.filter(x => x !== id) : lockedElements.concat([id]);
        undoCheckpoint();
        saveKey("lockedElements", list);
        alignMenu = "";
    }

    // Align an element in the menu grid: axis "h" (start = left, center,
    // end = right) or "v" (start = top, center, end = bottom); "between" =
    // centered between the neighbours on that axis (the nearest elements
    // beside it that overlap it across the axis, else the menu edge).
    // Starts from the shown arrangement; overlaps are sorted out by the fit.
    function alignElement(id, axis, where) {
        const items = layoutItems.map(i => Object.assign({}, i));
        const it = items.find(i => i.id === id);
        if (!it)
            return;
        const others = items.filter(i => i.id !== id);
        if (axis === "h") {
            if (where === "between") {
                const across = others.filter(o => o.row < it.row + it.h && o.row + o.h > it.row);
                const lo = across.filter(o => o.col + o.w <= it.col).reduce((m, o) => Math.max(m, o.col + o.w), 0);
                const hi = across.filter(o => o.col >= it.col + it.w).reduce((m, o) => Math.min(m, o.col), gridColumns);
                it.col = lo + Math.round((hi - lo - it.w) / 2);
            } else {
                it.col = where === "start" ? 0 : where === "end" ? gridColumns - it.w : Math.round((gridColumns - it.w) / 2);
            }
        } else {
            if (where === "between") {
                const across = others.filter(o => o.col < it.col + it.w && o.col + o.w > it.col);
                const lo = across.filter(o => o.row + o.h <= it.row).reduce((m, o) => Math.max(m, o.row + o.h), 0);
                const hi = across.filter(o => o.row >= it.row + it.h).reduce((m, o) => Math.min(m, o.row), gridRows);
                it.row = lo + Math.round((hi - lo - it.h) / 2);
            } else {
                it.row = where === "start" ? 0 : where === "end" ? gridRows - it.h : Math.round((gridRows - it.h) / 2);
            }
        }
        // The aligned element keeps its new place, the others give way
        saveLayout(fitLayout(items, id).items);
        alignMenu = "";
    }

    // Search: same ranking as the DMS launcher (AppSearchService)
    property string searchQuery: ""
    // Without a search element the menu takes the typing itself
    readonly property bool hasSearchElement: layoutItems.some(i => i.id === "search")
    // Search behaviour (settings)
    readonly property bool searchEnterLaunches: cfg.searchEnterLaunches ?? Defaults.searchEnterLaunches
    readonly property bool searchShowQueryChip: cfg.searchShowQueryChip ?? Defaults.searchShowQueryChip

    readonly property var apps: {
        AppSearchService.cacheVersion;
        SessionData.hiddenApps;
        // Searching: the launcher's results (searchSections)
        if (searching)
            return [];
        let list;
        // Visible = not hidden by DMS and not hidden in CustomMenu only
        const visible = () => dmsLists.visibleApps.filter(a => localHiddenApps.indexOf(appKey(a)) < 0);
        if (!categoriesShown || currentCategory === "__all") {
            list = visible();
        } else if (currentCategory.startsWith("custom:")) {
            const cc = customCategories.find(c => "custom:" + c.id === currentCategory);
            const keys = cc?.apps ?? [];
            list = visible().filter(a => keys.indexOf(appKey(a)) >= 0);
        } else if (currentCategory === "__hidden") {
            const seen = new Set();
            list = AppSearchService.applications.filter(a => {
                const id = a.id || a.execString || "";
                const hidden = AppSearchService.isAppHidden(a) || localHiddenApps.indexOf(appKey(a)) >= 0;
                if (!hidden || seen.has(id))
                    return false;
                seen.add(id);
                return true;
            }).map(a => AppSearchService.applyAppOverride(a));
        } else {
            // DMS' categories of the app plus the ones added by drag & drop
            const extra = categoryExtras[currentCategory] ?? [];
            const removed = categoryRemovals[currentCategory] ?? [];
            const name = dmsCategoryName(currentCategory);
            list = visible().filter(a => (AppSearchService.getCategoriesForApp(a).includes(name) && removed.indexOf(appKey(a)) < 0) || extra.indexOf(appKey(a)) >= 0);
        }
        return list.slice().sort((a, b) => (a.name || "").localeCompare(b.name || ""));
    }

    // ── Preview while the settings are open ──────────────────────────────
    // The settings page sets the plugin-wide variable "settingsOpen".
    // While it is set the menu stays open so changes show live. The popout
    // then disables its click-outside-to-close area and does not grab the
    // keyboard (see the Bindings below).
    // Only the instance being edited in the settings (globalVar editInstance)
    readonly property bool previewActive: PluginService.globalVars[pluginId]?.settingsOpen === true && (PluginService.globalVars[pluginId]?.editInstance ?? "") === instanceId
    // "Compact" button in the settings: { instance, stamp }
    readonly property var compactRequest: PluginService.globalVars[pluginId]?.compactRequest ?? null
    onCompactRequestChanged: if (compactRequest && compactRequest.instance === instanceId && Date.now() - compactRequest.stamp < 2000) compactMenu()
    property var activePopout: null
    // App being edited; the card shows AppEditPanel instead of the apps
    // then. Closing the menu returns to the app view.
    property var editingApp: null
    readonly property bool menuOpen: activePopout?.shouldBeVisible ?? false
    // DMS' popout internals (host, frame, animation, blur, position,
    // settings window): components/PopoutChrome.qml
    PopoutChrome {
        id: chrome
        menu: root
    }

    // ── Menu position ────────────────────────────────────────────────────
    // "widget" = DMS default (at the widget). "left"/"right"/"top"/"bottom"
    // = out of that screen edge, centred along it plus an offset; in the
    // connected frame mode the menu stays joined with the frame there.
    // "screen" = free: centred on the screen plus offsets, detached from
    // the frame. Done by re-positioning the popout's trigger before it
    // opens (and before it closes), so DMS' animations start and end at
    // the menu, not at the widget. DMS clamps the result to the screen.
    readonly property string menuAnchor: cfg.menuAnchor ?? Defaults.menuAnchor
    // Shadow around the free menu (DMS' popout shadow, if enabled there)
    readonly property bool menuShadow: cfg.menuShadow ?? Defaults.menuShadow
    onMenuShadowChanged: {
        const host = popoutHost(activePopout);
        if (host && !host.connected)
            adjustDetachedChrome(host);
    }
    // Menu surface (General › Menu surface): "default" = DMS' popout surface
    // with its blur; any other colour (also "none") = an own surface drawn
    // behind the canvas, DMS' fill, border and shadow hidden. DMS draws a
    // docked menu as part of its frame, so the menu is detached then (its
    // position stays). Former switch menuTransparent = colour "none".
    readonly property string menuSurfaceMode: cfg.menuSurfaceColorMode ?? (cfg.menuTransparent ? "none" : "default")
    // "default" with own transparency switched on: an own surface too, in
    // DMS' popout colour (readableSurface), so the transparency applies
    readonly property bool menuOwnTransparency: (cfg.menuSurfaceTransparent ?? false) && (cfg.menuSurfaceTransparency ?? 0) > 0
    readonly property bool menuTransparent: menuSurfaceMode !== "default" || menuOwnTransparency
    // Blur hidden for "none" and when switched off
    readonly property bool menuBlurOff: menuTransparent && (menuSurfaceMode === "none" || (cfg.menuSurfaceBlur ?? "dms") === "off")
    // Windows on the menu screen's active workspace (for "transparency only
    // without windows")
    // (DMS' own windows, e.g. its settings, do not count: the menu is their
    // preview, and with them counted the effect showed only without them)
    readonly property bool menuScreenHasWindows: (Hyprland.monitorFor(parentScreen)?.activeWorkspace?.toplevels?.values ?? []).some(t => settingsWindowClasses.indexOf(t.wayland?.appId ?? t.lastIpcObject?.class ?? "") < 0)
    readonly property color menuSurfaceColor: {
        if (menuSurfaceMode === "none")
            return "transparent";
        const c = ColorRoles.resolve(Theme, menuSurfaceMode, cfg.menuSurfaceCustomColor ?? "", Theme.readableSurface);
        let t = (cfg.menuSurfaceTransparent ?? false) ? (cfg.menuSurfaceTransparency ?? 0) / 100 : 0;
        if ((cfg.menuSurfaceTransparentEmptyOnly ?? false) && menuScreenHasWindows)
            t = 0;
        return Theme.withAlpha(c, (c.a ?? 1) * (1 - t));
    }
    readonly property real menuSurfaceRadius: cfg.menuSurfaceRadius ?? Theme.windowRadius
    readonly property real menuSurfaceBorderWidth: cfg.menuSurfaceBorderWidth ?? 0
    readonly property color menuSurfaceBorderColor: catColor("menuSurfaceBorder", Theme.outlineVariant)
    onMenuTransparentChanged: {
        ownBlurTimer.restart();
        applyDetach(activePopout);
        const host = popoutHost(activePopout);
        if (host)
            applySurfaceVisibility(host);
    }
    readonly property int menuOffsetX: cfg.menuOffsetX ?? Defaults.menuOffsetX
    readonly property int menuOffsetY: cfg.menuOffsetY ?? Defaults.menuOffsetY
    onMenuAnchorChanged: {
        applyDetach(activePopout);
        menuPlacementChanged();
    }
    onMenuOffsetXChanged: menuPlacementChanged()
    onMenuOffsetYChanged: menuPlacementChanged()
    onActivePopoutChanged: Qt.callLater(() => applyDetach(activePopout))

    function menuPlacementChanged() {
        applyMenuPosition(activePopout);
        if (previewActive)
            placeSettingsSoon();
    }

    function ownPopout() {
        return chrome.ownPopout();
    }

    // Same as PluginComponent's versions, plus placing the menu between
    // positioning (DMS sets the trigger at the widget) and toggling.
    function triggerPopout() {
        surfaceContext?.ensureVisible(root);
        if (pillClickAction) {
            runPillAction(pillClickAction);
            return;
        }
        if (usesAttachedExpansion && surfaceContext?.requestExpansion(root))
            return;
        const p = ownPopout();
        if (!p || !hasPopout || !positionPopout())
            return;
        prepareToggle(p);
        p.toggle();
    }

    function triggerHoverPopout(widgetHostId) {
        if (pillClickAction) {
            triggerPopout();
            return;
        }
        const p = ownPopout();
        if (!p || !hasPopout || !positionPopout())
            return;
        prepareToggle(p);
        PopoutManager.requestHoverPopout(p, undefined, widgetHostId || pluginId);
    }

    // Trigger as DMS set it at the widget (positionPopout), for this opening
    property var dmsTrigger: null

    function captureDmsTrigger(p) {
        return chrome.captureDmsTrigger(p);
    }

    function prepareToggle(p) {
        return chrome.prepareToggle(p);
    }

    function setTrigger(p, t) {
        return chrome.setTrigger(p, t);
    }

    function applyMenuPosition(p) {
        return chrome.applyMenuPosition(p);
    }

    function findItem(item, test) {
        return chrome.findItem(item, test);
    }
    function findItems(item, test, out) {
        return chrome.findItems(item, test, out);
    }
    function popoutHost(p) {
        return chrome.popoutHost(p);
    }

    function freeTouchesBar(p) {
        return chrome.freeTouchesBar(p);
    }

    function applyDetach(p) {
        return chrome.applyDetach(p);
    }

    // Detached in frame mode, DMS still uses the frame's directional reveal:
    // it clips the chrome to a rectangle of the menu's size, also once fully
    // open. The shadow then only shows as dark square bits outside the
    // rounded corners. So clip only while the reveal runs; the shadow has
    // room around the menu (the surface is larger by DMS' shadow buffer).
    // Blur follows DMS' setting; the shadow can be switched off.
    property var detachBound: []
    function adjustDetachedChrome(host) {
        return chrome.adjustDetachedChrome(host);
    }

    // ── Blur with an own menu surface ────────────────────────────────────
    // The compositor blurs one region per window. With an own surface DMS'
    // blur is off and the menu sets the region itself: the union of the
    // parts that want blur (menu surface unless switched off, canvas,
    // element backgrounds), each exactly in its rounded shape, clipped to
    // the window (Hyprland blurs the whole surface for a region outside it).
    property var blurParts: ({})
    // DMS' content wrapper (animated: position, scale) and the window
    // geometry of a blurred item in it: follows the open/close animation;
    // nothing while the menu closes (as DMS' own blur)
    property var dmsWrapper: null
    function blurGeom(item, open, wx, wy, ws, ix, iy, iw, ih, ir) {
        return chrome.blurGeom(item, open, wx, wy, ws, ix, iy, iw, ih, ir);
    }
    // Collected and handed over at most once per frame (many chips and
    // tiles register at once)
    property var _blurRaw: ({})
    function setBlurPart(key, region) {
        if (region)
            _blurRaw[key] = region;
        else
            delete _blurRaw[key];
        Qt.callLater(flushBlurParts);
    }
    function flushBlurParts() {
        blurParts = Object.assign({}, _blurRaw);
    }
    // Soft edges of scrolling areas (Appearance › Level 3)
    readonly property bool scrollFade: cfg.scrollFade ?? Defaults.scrollFade
    // Level 4 blur (Appearance › Level 4)
    readonly property bool pieceBlur: cfg.allPieceBlur === true
    property var blurRoot: null
    property var blurClip: null
    function applyOwnBlur() {
        return chrome.applyOwnBlur();
    }
    onBlurPartsChanged: Qt.callLater(applyOwnBlur)
    // On opening: at once, and once more after DMS' setup
    Timer {
        id: ownBlurTimer
        interval: 120
        onTriggered: root.applyOwnBlur()
    }

    // ── Opening animation (setting) ──────────────────────────────────────
    // "dms": DMS' own (slides in from the bar side, grows a little).
    // "screenCenter": grows from a small point in the middle of the screen
    // into its place; "menuCenter": grows in place from its own middle.
    // Bindings on DMS' content wrapper (position, scale), driven by DMS'
    // own progress (morphProgress 0 → 1), so timing and closing stay DMS';
    // DMS' bindings come back with "dms". Only for a free-standing menu
    // (detached), not with DMS' fluid effect.
    readonly property string menuAnimation: cfg.menuAnimation ?? Defaults.menuAnimation
    property var animBound: []
    property var animState: ({ "bound": false })
    function applyAnimation(host, chrome, wrapper) {
        return chrome.applyAnimation(host, chrome, wrapper);
    }

    // Hide (transparent menu) or restore DMS' surface and blur. DMS'
    // surface items are the siblings of the content wrapper (shadow, local
    // chrome, border) and its own children except our content; plus the
    // blur. Each gets a Binding that holds visible/blurEnabled false while
    // menuTransparent is on and gives DMS' own binding back when it is off.
    property var surfaceBound: []
    function applySurfaceVisibility(host) {
        return chrome.applySurfaceVisibility(host);
    }

    // Bumped on every opening; the search element then takes the focus
    property int searchFocusRequest: 0

    onMenuOpenChanged: {
        if (menuOpen) {
            applyOwnBlur();
            ownBlurTimer.restart();
        }
        // Each opening starts with the chosen start category
        if (menuOpen)
            currentCategory = startCategoryShown;
        // Folder counts may change between openings; the scope starts at "All"
        if (!menuOpen) {
            folderInfo = {};
            searchScope = "all";
            editingCategories = false;
            scopeListOpen = false;
            navResetSelection();
        }
        if (menuOpen) {
            searchFocusRequest++;
            // DMS 2.0 looks for dsearch only when its own launcher opens a
            // session; without that, files and folders stayed empty here
            DSearchService.ensureChecked?.();
            // Opened while the settings are open for another instance: the
            // settings switch to this one (it then stays open as their
            // preview; without the gear there was no other way)
            if (PluginService.globalVars[pluginId]?.settingsOpen === true && (PluginService.globalVars[pluginId]?.editInstance ?? "") !== instanceId)
                PluginService.setGlobalVar(pluginId, "editInstance", instanceId);
            // Opened another way (e.g. IPC): place it now
            if (!dmsTrigger) {
                captureDmsTrigger(activePopout);
                applyMenuPosition(activePopout);
            }
            return;
        }
        dmsTrigger = null;
        applyDetach(activePopout);
        editingApp = null;
        editingActions = "";
        layoutEditing = false;
        searchQuery = "";
    }

    // Settings closed with the gear in the menu: the menu stays open
    property bool keepOpenAfterSettings: false
    onPreviewActiveChanged: {
        if (previewActive && !menuOpen)
            triggerPopout();
        else if (!previewActive && menuOpen && !keepOpenAfterSettings)
            closePopout();
        if (!previewActive)
            keepOpenAfterSettings = false;
        settingsShrink = 0;
        if (previewActive) {
            placeSettingsSoon();
        } else {
            placeSettingsTimer.stop();
        }
    }

    // ── Move the settings window next to the menu (Hyprland only) ────────
    // The DMS settings window is a regular floating window and would end up
    // behind the menu. Only when the menu covers it, it is moved; the side
    // with more room wins, left on a tie. The
    // window appears asynchronously, so poll briefly until it exists.
    property int placeTries: 0
    // App id of the DMS windows: dev.duxlabs.shell since 2.0, com.danklinux.dms before
    readonly property var settingsWindowClasses: ["dev.duxlabs.shell", "com.danklinux.dms"]

    // While a settings slider is dragged, only remember it; place on release
    readonly property bool settingsSliderDragging: PluginService.globalVars[pluginId]?.sliderDragging === true
    property bool placePending: false
    onSettingsSliderDraggingChanged: {
        if (!settingsSliderDragging && placePending && previewActive)
            placeSettingsSoon();
    }

    // Open the settings at a section: expanded, its parents too, scrolled
    // there (the settings page reacts on "focusSection"). exclusive: all
    // other sections collapse (a click on a part of the menu); key "" with
    // exclusive: everything collapsed (gear button)
    function openSettingsAt(key, exclusive) {
        // The settings edit this instance
        PluginService.setGlobalVar(pluginId, "editInstance", instanceId);
        PluginService.setGlobalVar(pluginId, "focusSection", { "key": key, "exclusive": exclusive === true, "stamp": Date.now() });
        if (!previewActive)
            PopoutService.openSettingsWithTab(SettingsTabs.pluginPrefix + pluginId);
    }

    // Settings section of the part under a point of the canvas (card):
    // a tagged part (chip, tile, field: deepest visible item, then up to the
    // nearest one with jumpSection), else an element's background, the
    // canvas edge (spacing), an element's surroundings (jumpMargin around
    // its background, its general settings), else the canvas itself
    readonly property int jumpMargin: 10
    property var jumpFrames: []
    // Parts of the popout content the elements (components/) reach: the
    // canvas and the apps' context menu (set when they are built)
    property Item canvasCard: null
    property var appContextMenu: null
    function sectionAt(container, x, y) {
        return jumpTargetAt(container, x, y).key;
    }
    // The same, with what to highlight on hover: { key, item, margin }
    // (item = the part, margin = px around it) or { key, edge: true } (the
    // canvas edge band, jumpMargin wide)
    function jumpTargetAt(container, x, y) {
        const piece = taggedItemAt(container, x, y);
        const frameAt = margin => {
            for (const f of jumpFrames) {
                const b = f.jumpBounds;
                if (!b || !b.visible || !f.jumpSection)
                    continue;
                const q = container.mapToItem(b, x, y);
                if (q.x >= -margin && q.y >= -margin && q.x < b.width + margin && q.y < b.height + margin)
                    return { "key": f.jumpSection, "item": b, "margin": margin };
            }
            return null;
        };
        // An element: its content → its settings; its edge (inner padding,
        // at least a few px, and jumpMargin around it) → its own background
        // (highlighted as a frame: margin outside, inset inside)
        const edgeOf = (hit, margin) => {
            const f = jumpFrames.find(j => j.jumpBounds === hit.item);
            const id = f?.jumpElementId ?? "";
            const area = areaPrefixes[elementType(id)] ?? "";
            const inset = Math.max(areaStyleFor(id)?.padding ?? 0, 6);
            const q = container.mapToItem(hit.item, x, y);
            const onEdge = margin > 0 || q.x < inset || q.y < inset || q.x >= hit.item.width - inset || q.y >= hit.item.height - inset;
            if (!onEdge || !area)
                return hit;
            return { "key": area, "item": hit.item, "margin": jumpMargin, "inset": inset, "elementId": id };
        };
        const inside = frameAt(0);
        // A tagged part (chip, tile, field): highlighted within the visible
        // area of its element (a list can reach past it)
        if (piece)
            return { "key": piece.jumpSection, "item": piece, "margin": 0, "clip": inside?.item ?? null };
        if (inside)
            return edgeOf(inside, 0);
        if (x < jumpMargin || y < jumpMargin || x >= container.width - jumpMargin || y >= container.height - jumpMargin)
            return { "key": "cardSpacing", "edge": true };
        const near = frameAt(jumpMargin);
        return near ? edgeOf(near, jumpMargin) : { "key": "card", "item": container, "margin": 0 };
    }
    // The visible child on top at a point. Item.childAt() goes by order of
    // creation, not by z: the edit tools layer (over the whole canvas,
    // created later) hid the menu's buttons above it
    function topChildAt(item, x, y) {
        let top = null;
        for (let i = item.children.length - 1; i >= 0; i--) {
            const ch = item.children[i];
            if (!ch.visible || (top && ch.z <= top.z))
                continue;
            const p = item.mapToItem(ch, x, y);
            if (p.x >= 0 && p.y >= 0 && p.x < ch.width && p.y < ch.height)
                top = ch;
        }
        return top;
    }
    // A part marked jumpPassThrough under the point (the menu's buttons)
    function passesThrough(container, x, y) {
        let item = container, px = x, py = y;
        for (;;) {
            const child = topChildAt(item, px, py);
            if (!child)
                return false;
            if (child.jumpPassThrough === true)
                return true;
            const p = item.mapToItem(child, px, py);
            item = child;
            px = p.x;
            py = p.y;
        }
    }
    // The tile element at a point (its background and jumpMargin around
    // it), "" if none: the settings then edit that element's own look
    function tileElementAt(container, x, y) {
        for (const f of jumpFrames) {
            const b = f.jumpBounds;
            if (!b || !b.visible || !isTileElement(f.jumpElementId))
                continue;
            const q = container.mapToItem(b, x, y);
            if (q.x >= -jumpMargin && q.y >= -jumpMargin && q.x < b.width + jumpMargin && q.y < b.height + jumpMargin)
                return f.jumpElementId;
        }
        return "";
    }
    function taggedSectionAt(container, x, y) {
        return taggedItemAt(container, x, y)?.jumpSection ?? "";
    }
    // Deepest visible part with jumpSection under the point, through all
    // overlapping layers (the topmost alone can be a frame drawn over the
    // content, e.g. an element's border)
    function taggedItemAt(container, x, y) {
        const search = (item, px, py) => {
            const kids = [];
            for (let i = 0; i < item.children.length; i++)
                kids.push({ "c": item.children[i], "i": i });
            kids.sort((a, b) => (b.c.z - a.c.z) || (b.i - a.i));
            for (const k of kids) {
                const c = k.c;
                if (!c.visible || c.width <= 0 || c.height <= 0)
                    continue;
                const p = item.mapToItem(c, px, py);
                if (p.x < 0 || p.y < 0 || p.x >= c.width || p.y >= c.height)
                    continue;
                const found = search(c, p.x, p.y);
                if (found)
                    return found;
                if (c.jumpSection && c.jumpBounds === undefined)
                    return c;
            }
            return null;
        };
        return search(container, x, y);
    }

    // Edit mode with the settings open: the focused element's section
    readonly property var elementSections: ({ "search": "search", "categories": "categories", "apps": "apps", "tiles": "tiles" })

    function placeSettingsSoon() {
        if (settingsSliderDragging) {
            placePending = true;
            return;
        }
        placePending = false;
        placeTries = 0;
        placeSettingsTimer.restart();
    }

    // Menu moved or resized while the settings are open: follow it
    onPopoutWidthChanged: if (previewActive) placeSettingsSoon()
    onPopoutHeightChanged: if (previewActive) placeSettingsSoon()

    Timer {
        id: placeSettingsTimer
        interval: 150
        repeat: true
        onTriggered: {
            if (++root.placeTries > 20 || !CompositorService.isHyprland) {
                stop();
                return;
            }
            Hyprland.refreshToplevels();
            if (root.placeSettingsWindow())
                stop();
        }
    }

    function placeSettingsWindow() {
        return chrome.placeSettingsWindow();
    }

    // Launch as in the DMS launcher, including the usage counter for "frequent".
    function launchApp(app) {
        if (!app)
            return;
        SessionService.launchDesktopEntry(app);
        // Usage counter is a nice-to-have: an error there must not stop
        // the caller (closing the menu)
        try {
            AppUsageHistoryData.addAppUsage(app);
        } catch (e) {
            console.warn("customMenu: usage counter failed:", e);
        }
    }

    // ── Keyboard shortcut per instance ───────────────────────────────────
    // dms ipc call customMenu toggle (main) / customMenu_<variant id> toggle.
    // If the instance sits in bars on several screens, the one on the
    // focused screen answers (else the first screen by name); the screens
    // per instance are registered in a plugin-wide variable: entries
    // { screen, token }, the token per widget, so a widget being rebuilt
    // (e.g. the bar entry renamed) removes only its own entry, not that of
    // its successor on the same screen.
    readonly property string ipcTarget: instanceId ? "customMenu_" + instanceId : "customMenu"
    readonly property string screenName: parentScreen?.name ?? ""
    readonly property string screensKey: "screens_" + (instanceId || "main")
    readonly property string screenToken: Date.now().toString(36) + Math.random().toString(36).slice(2, 8)
    function registerScreen(add) {
        const list = (PluginService.globalVars[pluginId]?.[screensKey] ?? []).filter(e => e && e.token !== screenToken && typeof e === "object");
        PluginService.setGlobalVar(pluginId, screensKey, add && screenName ? list.concat([{ "screen": screenName, "token": screenToken }]) : list);
    }
    Component.onDestruction: registerScreen(false)
    onScreenNameChanged: registerScreen(true)
    // One widget per instance answers: the first on the focused screen,
    // else the first by screen name
    readonly property bool ipcAnswers: {
        const list = (PluginService.globalVars[pluginId]?.[screensKey] ?? []).filter(e => e && typeof e === "object");
        const focused = Hyprland.focusedMonitor?.name ?? "";
        const onFocused = list.filter(e => e.screen === focused);
        const pick = onFocused.length > 0 ? onFocused[0] : list.slice().sort((x, y) => x.screen < y.screen ? -1 : x.screen > y.screen ? 1 : 0)[0];
        return !!pick && pick.token === screenToken;
    }
    IpcHandler {
        target: root.ipcTarget
        enabled: root.ipcAnswers
        function toggle(): string {
            root.triggerPopout();
            return "ok";
        }
        function open(): string {
            if (!root.menuOpen)
                root.triggerPopout();
            return "open";
        }
        function close(): string {
            if (root.menuOpen)
                root.closePopout();
            return "closed";
        }
    }

    horizontalBarPill: Component {
        FlexIcon {
            icon: root.barIcon
            size: Theme.iconSize - 6
            color: root.barIconColor
        }
    }

    verticalBarPill: Component {
        FlexIcon {
            icon: root.barIcon
            size: Theme.iconSize - 6
            color: root.barIconColor
        }
    }

    // Layers as in DMS: host (popout background) → card → chips.
    // The popout grows with its content; popoutHeight alone is not enough.
    // The content therefore fills the height (pattern from the official
    // plugins: height minus header, description and padding).
    popoutContent: Component {
        MenuPopout {
            menu: root
        }
    }
}
