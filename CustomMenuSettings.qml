import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets
import "./components/settings"
import "./components/common"
import "Defaults.js" as Defaults
import "Templates.js" as Templates
import "FontLogos.js" as FontLogos

PluginSettings {
    id: root
    pluginId: "customMenu"

    // Upper bound of the size sliders: largest connected screen minus margin.
    // The settings page belongs to no bar, so no bar is subtracted here;
    // the widget additionally clamps to the space next to its bar when opening.
    readonly property int maxScreenWidth: Quickshell.screens.reduce((m, s) => Math.max(m, s.width), 0)
    readonly property int maxScreenHeight: Quickshell.screens.reduce((m, s) => Math.max(m, s.height), 0)
    // The menu gets narrower while the settings are open, so this window fits
    // beside it (published by the widget): a notice once per opening, unless
    // switched off ("Do not show again")
    readonly property bool menuShrunk: {
        const v = PluginService.globalVars[pluginId]?.menuShrunk;
        return !!v && v.instance === editInstance && v.shrunk === true;
    }
    property bool shrinkNoticeShown: false
    onMenuShrunkChanged: {
        if (!menuShrunk || shrinkNoticeShown || loadValue("hideShrinkNotice", false) === true)
            return;
        shrinkNoticeShown = true;
        openDialog(shrinkNoticeComp);
    }
    // Dialogs in the layer DMS uses for its own dialogs on this page (as in
    // TemplateBar)
    function openDialog(comp) {
        let page = root.parent;
        while (page && page.parentModal === undefined)
            page = page.parent;
        const host = page?.parentModal?.modalFocusScope ?? null;
        return comp.createObject(host ?? root, { "open": true });
    }
    Component {
        id: shrinkNoticeComp
        SmallDialog {
            id: shrinkNotice
            title: I18n.trFor("customMenu", "Menu shown at reduced size")
            message: (root.activeTemplateId === "fullscreen" || root.loadValue("menuSizeMode", "") === "full") ? I18n.trFor("customMenu", "The menu is narrowed so the settings window fits next to it and you can see your changes. It returns to fullscreen when you close the settings.") : I18n.trFor("customMenu", "The menu is narrowed so the settings window fits next to it and you can see your changes. It returns to its full size when you close the settings.")
            buttons: [
                DButton {
                    iconName: "check"
                    text: I18n.trFor("customMenu", "OK")
                    onClicked: shrinkNotice.done()
                },
                DButton {
                    iconName: "visibility_off"
                    text: I18n.trFor("customMenu", "Don't show again")
                    onClicked: {
                        root.saveValue("hideShrinkNotice", true);
                        shrinkNotice.done();
                    }
                }
            ]
        }
    }

    // The active template has its own size over the instance's (Fullscreen,
    // a mini menu): the size controls are locked while it is active
    // (read directly: loadValue itself depends on sizeFromProfile)
    readonly property string activeTemplateId: storedValue("activeTemplate") ?? "standard"
    readonly property bool sizeFromProfile: Templates.isOverlay(activeTemplateId, (SettingsData.pluginSettings[pluginId] ?? {}).userTemplates ?? {})
    // Size of the edited instance's menu as shown (published by the widget)
    readonly property var shownMenuSize: PluginService.globalVars[pluginId]?.menuSize ?? null

    // Live preview: while this page exists, the widget keeps the menu open.
    // Plugin-wide variable instead of a setting, so it is never saved.
    Component.onCompleted: {
        PluginService.setGlobalVar(pluginId, "settingsOpen", true);
        focusTimer.restart();
    }
    Component.onDestruction: PluginService.setGlobalVar(pluginId, "settingsOpen", false)

    // ── Collapsible sections ─────────────────────────────────────────────
    // DMS' SettingsCard (as in the other DMS settings). Open/closed is
    // stored as plugin state, not as a setting, so "Reset to defaults"
    // leaves it alone. Default: all closed.
    // Jump to a section on request of the menu (e.g. a click on a gap in edit
    // mode): expand it and its parents, then scroll it into view
    property var sectionItems: ({})
    // Build the content of every section, also closed ones (a jump to a
    // section that does not exist yet)
    property bool loadAllBodies: false
    readonly property var focusRequest: PluginService.globalVars[pluginId]?.focusSection ?? null
    onFocusRequestChanged: focusTimer.restart()

    function focusSection(key, exclusive) {
        // No section: all collapsed, back to the top
        if (!key && exclusive) {
            for (const k of Object.keys(sectionItems)) {
                if (sectionItems[k])
                    sectionItems[k].expanded = false;
            }
            scrollTimer.target = contentLoader;
            scrollTimer.restart();
            return true;
        }
        const section = sectionItems[key];
        if (!section) {
            // Not built yet (inside a closed section): build all, retry
            loadAllBodies = true;
            return false;
        }
        const chain = [];
        for (let p = section; p; p = p.parent) {
            if (p.isCustomMenuSection) {
                p.expanded = true;
                chain.push(p);
            }
        }
        // Only the path to the section stays open
        if (exclusive) {
            for (const k of Object.keys(sectionItems)) {
                const other = sectionItems[k];
                if (other && chain.indexOf(other) < 0)
                    other.expanded = false;
            }
        }
        scrollTimer.target = section;
        scrollTimer.restart();
        return true;
    }

    // Wait until the sections exist (page just opened) and are expanded
    // (collapse animation), then scroll
    Timer {
        id: focusTimer
        interval: 150
        onTriggered: {
            const request = root.focusRequest;
            if (!request || Date.now() - request.stamp > 10000)
                return;
            if (!root.focusSection(request.key, request.exclusive === true))
                restart();
        }
    }
    Timer {
        id: scrollTimer
        property var target: null
        interval: 400
        onTriggered: {
            if (!target)
                return;
            let flick = target.parent;
            while (flick && !(flick.contentItem !== undefined && flick.contentY !== undefined))
                flick = flick.parent;
            if (!flick)
                return;
            const y = target.mapToItem(flick.contentItem, 0, 0).y - Theme.spacingL;
            flick.contentY = Math.max(0, Math.min(y, flick.contentHeight - flick.height));
        }
    }

    function sectionExpanded(key) {
        return loadState("section_" + key, false) === true;
    }
    function setSectionExpanded(key, value) {
        saveState("section_" + key, value);
    }

    // Presets for the tile building blocks (the former layouts)
    readonly property var presets: ({
        "grid": { appShowIcon: true, appShowLabels: true, appShowDescription: false, appIconPosition: "top", appTextAlign: "center", appTextBackground: false, appFullWidth: false },
        "tile": { appShowIcon: true, appShowLabels: true, appShowDescription: false, appIconPosition: "top", appTextAlign: "center", appTextBackground: true, appFullWidth: false },
        "list": { appShowIcon: true, appShowLabels: true, appShowDescription: true, appIconPosition: "left", appTextAlign: "left", appTextBackground: false, appFullWidth: true }
    })

    // Shows "Custom" in the preset dropdown as soon as a value no longer
    // matches the chosen preset
    function checkPreset() {
        const name = effectiveValue("layoutMode", Defaults.layoutMode);
        const p = presets[name];
        if (!p)
            return;
        for (const key of Object.keys(p)) {
            const fallback = Defaults[key];
            if (effectiveValue(key, fallback) !== p[key]) {
                saveValue("layoutMode", "custom");
                return;
            }
        }
    }

    Connections {
        target: PluginService
        function onPluginDataChanged(pluginId) {
            if (pluginId !== root.pluginId)
                return;
            Qt.callLater(root.checkPreset);
            root.lookRevision++;
        }
    }

    // Shared element look (Appearance): an element setting
    // without own value shows the shared one, else its own default
    property int lookRevision: 0

    // Element types in the edited instance's layout: the sections of
    // elements that are not in the menu are hidden
    readonly property var layoutTypes: {
        lookRevision;
        editInstance;
        const layout = loadValue("layout", null) ?? Defaults.defaultLayout;
        // Former shortcuts and buttons elements are tile elements
        return layout.map(i => String(i.id).split(":")[0]).map(t => t === "shortcuts" || t === "actions" ? "tiles" : t);
    }
    function hasElement(type) {
        return layoutTypes.indexOf(type) >= 0;
    }

    // ── Tile elements: shared look or one element's own ──────────────────
    // The Tiles section edits the look of all tile elements, or with an
    // element chosen (tileScope, plugin-wide variable; also set by the menu
    // when a tile element is clicked) that element's own values, stored as
    // tileLooks[id] = { key: value }. Unset there = the shared value.
    readonly property var tileElements: {
        lookRevision;
        editInstance;
        const layout = loadValue("layout", null) ?? Defaults.defaultLayout;
        const data = loadValue("shortcuts", null) ?? Defaults.defaultShortcuts;
        const ids = layout.map(i => String(i.id)).filter(id => /^(tiles|shortcuts|actions):/.test(id));
        return ids.map((id, n) => ({ "id": id, "name": data[id]?.title || (ids.length > 1 ? I18n.trFor("customMenu", "Tiles") + " " + (n + 1) : I18n.trFor("customMenu", "Tiles")) }));
    }
    readonly property string tileScope: {
        const id = PluginService.globalVars[pluginId]?.tileScope ?? "";
        return tileElements.some(e => e.id === id) ? id : "";
    }
    function isTileLookKey(key) {
        return /^tl[A-Z]/.test(key);
    }
    function selectTileScope(id) {
        PluginService.setGlobalVar(pluginId, "tileScope", id);
        PluginService.pluginDataChanged(pluginId);
    }
    readonly property bool tileScopeHasOwn: {
        lookRevision;
        const own = (loadValue("tileLooks", {}) ?? {})[tileScope];
        return !!tileScope && !!own && Object.keys(own).length > 0;
    }
    function resetTileScope() {
        const looks = loadValue("tileLooks", {}) ?? {};
        delete looks[tileScope];
        saveValue("tileLooks", looks);
    }
    readonly property string inheritLabel: I18n.trFor("customMenu", "Default (same as Appearance)")
    readonly property string scopeInherit: I18n.trFor("customMenu", "Same as category chips")
    // Chip colours as the menu of the edited instance uses them (it reports
    // them): what "as …" in a colour picker stands for
    function lookColor(name, fallback) {
        const c = PluginService.globalVars[pluginId]?.lookColors;
        return c && c.instance === editInstance && c[name] ? c[name] : fallback;
    }
    function sharedOr(key, def) {
        lookRevision;
        return effectiveValue(key, def);
    }

    // Templates (Templates.js): a setting without stored value takes the
    // chosen template's value, then the default
    // The chosen template's values, worked out once per template and state
    // of the own profiles (every control asks for them; each working them
    // out again made an instance switch take seconds). The cache is a plain
    // object field: writing a property from inside bindings would loop.
    readonly property var templateCache: ({})
    function currentTemplateValues() {
        const own = SettingsData.pluginSettings[pluginId] ?? {};
        const data = !editInstance ? own : (own.variants ?? []).find(v => v.id === editInstance)?.data ?? {};
        const id = data.activeTemplate ?? "standard";
        const profiles = own.userTemplates;
        const c = templateCache;
        if (c.values && c.id === id && c.profiles === profiles)
            return c.values;
        c.id = id;
        c.profiles = profiles;
        c.values = Templates.resolveTheme(Templates.valuesOf(id, profiles ?? {}), Theme);
        return c.values;
    }
    function templateValue(key) {
        return currentTemplateValues()[key];
    }
    function effectiveValue(key, def) {
        const v = loadValue(key, undefined);
        if (v !== undefined && v !== null)
            return v;
        const t = templateValue(key);
        return t === undefined || t === null ? def : t;
    }
    // Remove all own look values of an element: it follows General again
    function resetLook(keys) {
        const changes = {};
        for (const k of keys)
            changes[k] = undefined;
        saveValues(changes);
    }
    readonly property var colorKeySuffixes: ["ColorMode", "CustomColor", "Transparent", "Transparency"]
    function lookKeys(prefixes, plain) {
        let out = plain.slice();
        for (const p of prefixes)
            out = out.concat(colorKeySuffixes.map(x => p + x));
        return out;
    }

    // "Single column" overrides the chip width. Turning it on remembers the
    // width ("chipWidthMulti"), turning it off restores it, so the grid has
    // as many apps per row as before. Without a remembered width: the
    // current row width (still one column; narrowing creates more).
    function singleColumnChanged(on) {
        if (on) {
            saveValue("chipWidthMulti", effectiveValue("chipWidth", Defaults.chipWidth));
            return;
        }
        const remembered = effectiveValue("chipWidthMulti", undefined);
        if (remembered !== undefined && remembered !== null) {
            saveValue("chipWidth", remembered);
            return;
        }
        const rowWidth = PluginService.globalVars[root.pluginId]?.rowWidth ?? 0;
        if (rowWidth > 0)
            saveValue("chipWidth", rowWidth);
    }

    function applyPreset(name) {
        const p = presets[name];
        if (!p)
            return;
        // Presets switch "Single column" too: remember/restore the width
        const wasSingle = effectiveValue("appFullWidth", Defaults.appFullWidth) === true;
        if (p.appFullWidth !== undefined && p.appFullWidth !== wasSingle)
            singleColumnChanged(p.appFullWidth);
        // The controls follow the plugin data live, no rebuild needed
        saveValues(Object.assign({}, p, { "layoutMode": name }));
    }

    // The running distribution (for the bar icon suggestions)
    FileView {
        id: osRelease
        path: "/etc/os-release"
        printErrors: false
    }
    function osReleaseText() {
        return osRelease.text();
    }
    // Category styling only applies to the "chips" style (older styles = chips)
    readonly property bool catChips: effectiveValue("categoryStyle", Defaults.categoryStyle) !== "dropdown"

    // ── Instances (DMS plugin variants) ─────────────────────────────────
    // The page edits one instance: "" = the main one (plugin data), else a
    // variant (its data in DMS' variant list). Shared with the menus via
    // the globalVar editInstance. loadValue/saveValue (also used by all
    // controls) go to that instance; own profiles (userTemplates) and the
    // variant list itself are shared by all instances.
    readonly property string editInstance: {
        // "variant_main" is the main instance (its data in the plugin data)
        const id = PluginService.globalVars[pluginId]?.editInstance ?? "";
        return id && id !== "variant_main" && PluginService.getPluginVariantData(pluginId, id) ? id : "";
    }
    readonly property var globalKeys: ["userTemplates", "variants", "enabled", "hideShrinkNotice"]
    function instanceStored() {
        if (!editInstance)
            return SettingsData.getPluginSettingsForPlugin(pluginId);
        return JSON.parse(JSON.stringify(PluginService.getPluginVariantData(pluginId, editInstance)?.data ?? {}));
    }
    // The stored data a key belongs to: plugin-wide or the edited instance's
    function storedData(key) {
        const own = SettingsData.pluginSettings[pluginId] ?? {};
        return !editInstance || globalKeys.indexOf(key) >= 0 ? own : (own.variants ?? []).find(v => v.id === editInstance)?.data ?? {};
    }
    // A stored value as is (no tile scope, no profile size)
    function storedValue(key) {
        return storedData(key)[key];
    }
    function loadValue(key, defaultValue) {
        // Called by every control on every data change: read in place and
        // copy only the one value (a copy of all plugin data each time,
        // variants included, made the page slow to build)
        const d = storedData(key);
        // One tile element chosen: its own value first
        const scoped = tileScope && isTileLookKey(key) ? d.tileLooks?.[tileScope]?.[key] : undefined;
        // A template with its own size active: the size controls show the
        // changes made to it (profileSize); the own size stays underneath
        const v = sizeFromProfile && Templates.isSizeKey(key) ? d.profileSize?.[key] : scoped !== undefined ? scoped : d[key];
        if (v === undefined)
            return defaultValue;
        return v !== null && typeof v === "object" ? JSON.parse(JSON.stringify(v)) : v;
    }
    function saveValue(key, value) {
        const c = {};
        c[key] = value;
        saveValues(c);
    }
    function selectInstance(id) {
        PluginService.setGlobalVar(pluginId, "editInstance", id);
        // All controls read their value again
        PluginService.pluginDataChanged(pluginId);
    }

    // Several values in one write (one file save, one change signal).
    // Value by value every save copies and writes all plugin settings and
    // re-evaluates the whole menu; with dozens of keys DMS froze long
    // enough for Hyprland's "not responding" dialog.
    // changes: { key: value }, undefined = remove.
    // Tiles › center the content on one axis ("h"/"v"): the alignment (for
    // the chosen tile element or all) and the tiles of grid elements
    function centerTileContent(axis) {
        saveValue(axis === "h" ? "tlAlignH" : "tlAlignV", "center");
        PluginService.setGlobalVar(pluginId, "centerTilesRequest", { "instance": editInstance, "scope": tileScope, "axis": axis, "stamp": Date.now() });
    }
    // raw: as given (the template bar handles the size itself)
    function saveValues(changes, raw) {
        // A template with its own size active: size changes go into
        // profileSize (a change against that template), not over the own size
        if (!raw && sizeFromProfile && Object.keys(changes).some(k => Templates.isSizeKey(k))) {
            const size = loadValue("profileSize", {}) ?? {};
            const rest = {};
            for (const key of Object.keys(changes)) {
                if (!Templates.isSizeKey(key))
                    rest[key] = changes[key];
                else if (changes[key] === undefined)
                    delete size[key];
                else
                    size[key] = changes[key];
            }
            rest.profileSize = Object.keys(size).length > 0 ? size : undefined;
            changes = rest;
        }
        // One tile element chosen: its look values go into tileLooks[id]
        if (tileScope && Object.keys(changes).some(k => isTileLookKey(k))) {
            const looks = loadValue("tileLooks", {}) ?? {};
            const mine = Object.assign({}, looks[tileScope] ?? {});
            const rest = {};
            for (const key of Object.keys(changes)) {
                if (!isTileLookKey(key)) {
                    rest[key] = changes[key];
                    continue;
                }
                if (changes[key] === undefined)
                    delete mine[key];
                else
                    mine[key] = changes[key];
            }
            if (Object.keys(mine).length > 0)
                looks[tileScope] = mine;
            else
                delete looks[tileScope];
            rest.tileLooks = looks;
            changes = rest;
        }
        const updated = JSON.parse(JSON.stringify(SettingsData.pluginSettings));
        const own = updated[pluginId] ?? {};
        const apply = (target, key) => {
            if (changes[key] === undefined)
                delete target[key];
            else
                target[key] = changes[key];
        };
        const instanceKeys = [];
        for (const key of Object.keys(changes)) {
            if (!editInstance || globalKeys.indexOf(key) >= 0)
                apply(own, key);
            else
                instanceKeys.push(key);
        }
        if (instanceKeys.length > 0) {
            const variants = Array.isArray(own.variants) ? own.variants : [];
            const v = variants.find(x => x.id === editInstance);
            if (v) {
                const data = Object.assign({}, v.data ?? {});
                for (const key of instanceKeys)
                    apply(data, key);
                v.data = data;
            }
        }
        updated[pluginId] = own;
        SettingsData.pluginSettings = updated;
        SettingsData.savePluginSettings();
        PluginService.pluginDataChanged(pluginId);
    }

    // All settings in one Loader. The controls (components/Plugin*.qml)
    // follow the plugin data live, so presets and reset need no rebuild.
    Loader {
        id: contentLoader
        width: parent.width
        sourceComponent: Component {
            Column {
                id: page
                width: contentLoader.width
                // Same distance between the top-level sections as DMS puts
                // between nested ones (their row padding plus the list gap)
                spacing: SettingsMetrics.rowPaddingV * 2 + Theme.groupedListGap


                // ── Instance: always shown, top level ──
                Column {
                    readonly property bool countsAsLevel: true
                    width: parent.width
                    spacing: page.spacing

                    InstanceBar {}

                    // Command for a keyboard shortcut (DMS › Keyboard shortcuts:
                    // run a command), opens/closes exactly this instance
                    Section {
                        key: "instanceShortcut"
                        title: I18n.trFor("customMenu", "Keyboard shortcut")
                        // Indented like the sub-sections inside a section
                        x: SettingsMetrics.rowPaddingH
                        width: parent.width - SettingsMetrics.rowPaddingH * 2

                        body: Component {
                            Item {

                                StyledText {
                                    x: Theme.spacingM
                                    width: parent.width - Theme.spacingM * 2
                                    wrapMode: Text.WordWrap
                                    text: I18n.trFor("customMenu", "Keyboard shortcut for this instance (DMS › Input › Keyboard shortcuts, run a command):")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                                DTextField {
                                    x: Theme.spacingM
                                    width: parent.width - Theme.spacingM * 2
                                    readOnly: true
                                    text: "dms ipc call " + (root.editInstance ? "customMenu_" + root.editInstance : "customMenu") + " toggle"
                                }
                            }
                        }
                    }
                }

                // ── Template ──
                Section {
                    key: "template"
                    title: I18n.trFor("customMenu", "Template")

                    body: Component {
                        Item {

                            TemplateBar {}
                        }
                    }
                }

                // ── General ──
                SettingsGeneral {
                    settings: root
                }

                // ── Appearance: the shared look of the elements ──
                SettingsAppearance {
                    settings: root
                }

                // ── Apps ──
                SettingsApps {
                    settings: root
                }

                // ── Categories ──
                SettingsCategories {
                    settings: root
                }

                // ── Search ──
                SettingsSearch {
                    settings: root
                }

                // ── Tiles ──
                SettingsTiles {
                    settings: root
                }



            }
        }
    }
}
