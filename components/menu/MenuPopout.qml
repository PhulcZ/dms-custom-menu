import QtQuick
import QtQuick.Controls as QQC
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.DCommon.Common as DC
import qs.Modules.Plugins
import "../../Defaults.js" as Defaults
import "root:/Common/GridLayout.js" as GridUtils
import "../common"

PopoutComponent {
    id: popout
    // The menu widget (CustomMenuWidget): its settings and functions
    required property Item menu

    showCloseButton: false

    onParentPopoutChanged: menu.activePopout = parentPopout

    // Type to search without a search element: takes the focus on
    // opening (like the search field would) and edits searchQuery.
    // Unhandled keys (Escape with an empty query) go on to DMS, which
    // closes the menu.
    Item {
        id: typeCatcher
        Keys.onPressed: event => {
            if (menu.handleNavKey(event)) {
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Escape) {
                if (menu.searchQuery !== "") {
                    menu.searchQuery = "";
                    event.accepted = true;
                }
                return;
            }
            if (event.key === Qt.Key_Backspace) {
                menu.searchQuery = menu.searchQuery.slice(0, -1);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (menu.searchEnterLaunches && menu.searching && menu.firstResult)
                    menu.activateTile(menu.firstResult);
                event.accepted = true;
                return;
            }
            const plain = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier));
            if (plain && event.text.length === 1 && event.text >= " ") {
                menu.searchQuery += event.text;
                event.accepted = true;
            }
        }

        Timer {
            id: typeFocusTimer
            interval: 80
            onTriggered: typeCatcher.forceActiveFocus()
        }
        Connections {
            target: root
            function onSearchFocusRequestChanged() {
                if (!menu.hasSearchElement && !menu.previewActive)
                    typeFocusTimer.restart();
            }
            function onHasSearchElementChanged() {
                if (!menu.hasSearchElement && menu.menuOpen && !menu.previewActive)
                    typeFocusTimer.restart();
            }
            function onLayoutEditingChanged() {
                if (!menu.layoutEditing && !menu.hasSearchElement && menu.menuOpen && !menu.previewActive)
                    typeFocusTimer.restart();
            }
        }
    }

    // Context menu. Registered as a "transient" surface of the popout so
    // that a click into the menu does not close the popout.
    // Edit mode: all element types; placed ones (each exists once for
    // now) and switched-off categories are greyed out with the reason
    DContextMenu {
        id: addMenu
        transientSurfaceTracker: popout.parentPopout?.transientSurfaceTracker ?? null
        layerNamespace: "dms:custom-menu-add-element"
        menuItems: menu.elementTypes.map(type => {
            // Tile elements may exist several times; the others once
            const placed = type !== "tiles" && menu.storedLayout.some(i => i.id === type);
            const off = type === "categories" && !menu.showCategories;
            const note = off ? I18n.trFor("customMenu", "turned off in the settings") : placed ? I18n.trFor("customMenu", "already in the menu") : "";
            const title = menu.elementTitle(type);
            return {
                "type": "item",
                "icon": type === "search" ? "search" : type === "categories" ? "label" : type === "tiles" ? "grid_view" : "apps",
                "text": note ? title + " (" + note + ")" : title,
                "enabled": !placed && !off,
                "action": () => menu.addElement(type)
            };
        })
    }

    AppContextMenu {
        id: appMenu
        Component.onCompleted: menu.appContextMenu = appMenu
        transientSurfaceTracker: popout.parentPopout?.transientSurfaceTracker ?? null
        onLaunched: () => popout.closePopout?.()
        onEditRequested: app => menu.editingApp = app
        groupItems: menu.contextMenuItems(appMenu.app)
        extraOnly: String(menu.appKey(appMenu.app)).startsWith("act:")
    }

    Binding {
        target: popout.parentPopout
        when: menu.previewActive && popout.parentPopout !== null
        property: "backgroundInteractive"
        value: false
        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        target: popout.parentPopout
        when: menu.previewActive && popout.parentPopout !== null
        property: "customKeyboardFocus"
        value: WlrKeyboardFocus.None
        restoreMode: Binding.RestoreBindingOrValue
    }

    Item {
        width: parent.width
        implicitHeight: menu.popoutHeight - popout.headerHeight - popout.detailsHeight - PopoutMetrics.contentPadding * 2

        // Own menu surface (setting): the whole popout, i.e. this area
        // plus DMS' content padding around it
        Rectangle {
            id: ownSurface
            visible: menu.menuTransparent
            readonly property bool wantsBlur: menu.menuTransparent && !menu.menuBlurOff
            property var blurRegion: Region {
                // Window geometry, following DMS' animation
                readonly property var g: menu.blurGeom(ownSurface, menu.menuOpen, menu.dmsWrapper?.x ?? 0, menu.dmsWrapper?.y ?? 0, menu.dmsWrapper?.scale ?? 1, ownSurface.x, ownSurface.y, ownSurface.width, ownSurface.height, menu.menuSurfaceRadius)
                x: g.x
                y: g.y
                width: g.w
                height: g.h
                radius: g.r
            }
            onWantsBlurChanged: menu.setBlurPart("__surface", wantsBlur ? blurRegion : null)
            Component.onCompleted: menu.setBlurPart("__surface", wantsBlur ? blurRegion : null)
            Component.onDestruction: menu.setBlurPart("__surface", null)
            x: -PopoutMetrics.contentPadding
            y: -PopoutMetrics.contentPadding
            width: parent.width + PopoutMetrics.contentPadding * 2
            height: parent.height + PopoutMetrics.contentPadding * 2
            radius: menu.menuSurfaceRadius
            color: menu.menuSurfaceColor
            border.width: menu.menuSurfaceBorderWidth
            border.color: menu.menuSurfaceBorderColor
        }

        StyledRect {
            id: card
            // Canvas blur (setting)
            readonly property bool wantsBlur: menu.menuTransparent && (menu.cfg.cardBlur ?? false) === true
            property var blurRegion: Region {
                // Window geometry, following DMS' animation
                readonly property var g: menu.blurGeom(card, menu.menuOpen, menu.dmsWrapper?.x ?? 0, menu.dmsWrapper?.y ?? 0, menu.dmsWrapper?.scale ?? 1, card.x, card.y, card.width, card.height, card.radius)
                x: g.x
                y: g.y
                width: g.w
                height: g.h
                radius: g.r
            }
            onWantsBlurChanged: menu.setBlurPart("__card", wantsBlur ? blurRegion : null)
            Component.onCompleted: {
                menu.canvasCard = card;
                menu.setBlurPart("__card", wantsBlur ? blurRegion : null);
            }
            Component.onDestruction: menu.setBlurPart("__card", null)

            // Scope list of the chip in the search field: a click
            // outside closes it
            MouseArea {
                anchors.fill: parent
                z: 999
                visible: menu.scopeListOpen
                onClicked: menu.scopeListOpen = false
            }
            Rectangle {
                id: scopeList
                z: 1000
                visible: menu.scopeListOpen
                width: 180
                x: Math.max(0, Math.min(card.width - width, menu.scopeListPos.x))
                y: menu.scopeListPos.y
                height: scopeColumn.implicitHeight + Theme.spacingXS * 2
                radius: Theme.cornerRadius
                color: Theme.surfaceContainer
                border.width: 1
                border.color: Theme.outlineVariant

                Column {
                    id: scopeColumn
                    x: Theme.spacingXS
                    y: Theme.spacingXS
                    width: parent.width - Theme.spacingXS * 2

                    Repeater {
                        model: menu.searchScopes

                        Rectangle {
                            id: scopeItem
                            required property var modelData
                            readonly property bool current: modelData.key === menu.searchScope
                            width: scopeColumn.width
                            height: 36
                            radius: Theme.cornerRadiusS
                            color: scopeItemArea.containsMouse ? Theme.withAlpha(Theme.onSurface, Theme.stateLayerHover) : "transparent"

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                x: Theme.spacingS
                                spacing: Theme.spacingS
                                DIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: scopeItem.current ? "check" : scopeItem.modelData.icon
                                    size: Theme.iconSizeSmall
                                    color: scopeItem.current ? Theme.primary : Theme.surfaceText
                                }
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: scopeItem.modelData.text
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: scopeItem.current ? Theme.primary : Theme.surfaceText
                                }
                            }
                            MouseArea {
                                id: scopeItemArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    menu.searchScope = scopeItem.modelData.key;
                                    menu.scopeListOpen = false;
                                    menu.searchFocusRequest++;
                                }
                            }
                        }
                    }
                }
            }
            // DMS puts PopoutMetrics.contentPadding around every plugin content.
            // The negative part cancels it so that "Card margin" is the
            // real distance to the menu edge (0 = flush).
            anchors.fill: parent
            anchors.topMargin: menu.cardMarginTop - PopoutMetrics.contentPadding
            anchors.bottomMargin: menu.cardMarginBottom - PopoutMetrics.contentPadding
            anchors.leftMargin: menu.cardMarginLeft - PopoutMetrics.contentPadding
            anchors.rightMargin: menu.cardMarginRight - PopoutMetrics.contentPadding
            // Concentric with the actual popout corners, which the popout reports
            // itself (x=top left, y=top right, z=bottom right, w=bottom left).
            // They depend on the mode: window radius, frame radius in frame mode,
            // 0 on the bar side for docked popouts.
            readonly property real minCardRadius: 4
            // Own menu surface: its corner radius (the menu is detached then)
            readonly property vector4d outerRadii: menu.menuTransparent ? Qt.vector4d(menu.menuSurfaceRadius, menu.menuSurfaceRadius, menu.menuSurfaceRadius, menu.menuSurfaceRadius) : (popout.parentPopout?.surfaceCornerRadii ?? Qt.vector4d(Theme.windowRadius, Theme.windowRadius, Theme.windowRadius, Theme.windowRadius))
            // Inner = outer minus margin (concentric; the smaller of the two
            // margins meeting at the corner), at least minCardRadius
            // (or the outer radius, if smaller). Not floored at DMS' card
            // radius: with a small outer radius (detached: window radius
            // 10) and a wide margin the card would look rounder than the menu.
            // Outer 0 means a docked side where the surface continues into the
            // frame or bar; the card stays rounded there anyway.
            // Plain expressions instead of a helper function: a function in a
            // binding is still called while the plugin is torn down and warns.
            topLeftRadius: outerRadii.x <= 0 ? Theme.cornerRadius : Math.max(Math.min(outerRadii.x, minCardRadius), outerRadii.x - Math.min(menu.cardMarginTop, menu.cardMarginLeft))
            topRightRadius: outerRadii.y <= 0 ? Theme.cornerRadius : Math.max(Math.min(outerRadii.y, minCardRadius), outerRadii.y - Math.min(menu.cardMarginTop, menu.cardMarginRight))
            bottomRightRadius: outerRadii.z <= 0 ? Theme.cornerRadius : Math.max(Math.min(outerRadii.z, minCardRadius), outerRadii.z - Math.min(menu.cardMarginBottom, menu.cardMarginRight))
            bottomLeftRadius: outerRadii.w <= 0 ? Theme.cornerRadius : Math.max(Math.min(outerRadii.w, minCardRadius), outerRadii.w - Math.min(menu.cardMarginBottom, menu.cardMarginLeft))
            color: menu.cardColor
            border.width: menu.cardBorderWidth
            border.color: menu.catColor("cardBorder", Theme.outlineVariant)

            // Icon under the mouse while an app is dragged (drag & drop source)
            Item {
                id: appDragProxy
                z: 100
                visible: menu.appDragging
                width: 48
                height: 48
                Drag.active: menu.appDragging
                Drag.keys: ["custommenu-app"]
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2
                Component.onCompleted: menu.dragProxy = appDragProxy

                AppIconRenderer {
                    anchors.fill: parent
                    opacity: 0.85
                    iconSize: 48
                    iconValue: menu.dragApp?.icon || ""
                    fallbackText: (menu.dragApp?.name || "?").charAt(0).toUpperCase()
                }
            }

            // Remove target while an app is dragged out of a category or a
            // tile element: dropped on it, the app leaves there. Below the
            // dragged icon, above the elements (gets the drop first).
            Rectangle {
                id: removeTarget
                z: 90
                visible: menu.dragCanRemove
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.spacingL
                width: 64
                height: 64
                radius: width / 2
                // 85 % transparent; stronger while the app is over it
                color: Theme.withAlpha(removeDrop.containsDrag ? Theme.error : menu.appTextColor, removeDrop.containsDrag ? 0.3 : 0.15)
                scale: removeDrop.containsDrag ? 1.15 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.shortDuration
                    }
                }

                DIcon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 32
                    color: removeDrop.containsDrag ? Theme.error : menu.appTextColor
                }

                DropArea {
                    id: removeDrop
                    anchors.fill: parent
                    keys: ["custommenu-app"]
                    onDropped: menu.dropOnRemove()
                }
            }

            // Top right: edit layout (pencil, like the DMS control center)
            // and settings
            Row {
                id: menuToolbar
                z: 8
                visible: menu.editingApp === null && menu.editingActions === "" && !menu.editingCategories
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingXS

                DActionButton {
                    visible: menu.layoutEditing
                    enabled: menu.undoStack.length > 0
                    opacity: enabled ? 1 : 0.35
                    iconName: "undo"
                    iconColor: menu.appTextColor
                    tooltipText: I18n.trFor("customMenu", "Undo")
                    onClicked: menu.undo()
                }

                DActionButton {
                    id: addButton
                    visible: menu.layoutEditing
                    iconName: "add"
                    iconColor: menu.appTextColor
                    tooltipText: I18n.trFor("customMenu", "Add element")
                    onClicked: {
                        const p = mapToGlobal(0, height);
                        const screen = menu.activePopout?.screen ?? menu.parentScreen;
                        addMenu.open(screen, p.x - (screen?.x || 0), p.y - (screen?.y || 0) + Theme.spacingXS, false);
                    }
                }

                // Edit mode: grid lines on/off
                DActionButton {
                    visible: menu.layoutEditing
                    iconName: menu.showGridLines ? "grid_on" : "grid_off"
                    iconColor: Theme.primary
                    tooltipText: menu.showGridLines ? I18n.trFor("customMenu", "Hide grid") : I18n.trFor("customMenu", "Show grid")
                    onClicked: menu.saveKey("editShowGrid", !menu.showGridLines)
                }

                DActionButton {
                    // Always shown while editing, so edit mode can be left
                    readonly property bool jumpPassThrough: true
                    visible: menu.showEditButton || menu.layoutEditing
                    iconName: menu.layoutEditing ? "check" : "edit"
                    iconColor: menu.layoutEditing ? Theme.primary : menu.appTextColor
                    tooltipText: menu.layoutEditing ? I18n.trFor("customMenu", "Done") : I18n.trFor("customMenu", "Edit layout")
                    onClicked: menu.layoutEditing = !menu.layoutEditing
                }

                DActionButton {
                    readonly property bool jumpPassThrough: true
                    visible: menu.showSettingsButton
                    iconName: "settings"
                    iconColor: menu.appTextColor
                    tooltipText: menu.previewActive ? I18n.trFor("customMenu", "Close the settings") : I18n.trFor("customMenu", "CustomMenu settings")
                    // Opens the settings (the menu stays open as their
                    // preview); open already: closes them, the menu stays
                    onClicked: {
                        if (menu.previewActive) {
                            menu.keepOpenAfterSettings = true;
                            PopoutService.closeSettings();
                        } else {
                            menu.openSettingsAt("", true);
                        }
                    }
                }
            }

            AppEditPanel {
                visible: menu.editingApp !== null
                anchors.fill: parent
                anchors.margins: menu.cardPadding
                app: menu.editingApp
                textColor: menu.appTextColor
                iconFavorites: [menu.cfg.iconFavorite1 ?? "", menu.cfg.iconFavorite2 ?? "", menu.cfg.iconFavorite3 ?? ""]
                editScope: menu.cfg.editScope ?? Defaults.editScope
                focus: visible
                iconColors: menu.appIconColors
                onCloseRequested: menu.editingApp = null
                onIconColorSaved: (appId, color) => menu.setAppIconColor(appId, color)
            }

            TilesEditor {
                menu: popout.menu
            }

            CategoryEditor {
                menu: popout.menu
            }

            // ── Layout grid (edit mode: drag, snap, resize) ──────────
            // Elements are cells of DMS' DEditableGrid (the grid behind
            // the the DMS dash edit mode). Positions/sizes are stored as
            // "layout" in the plugin data.
            // Element tools of edit mode (moved here from the elements):
            // over the whole canvas, so tools in the canvas padding get
            // their clicks; above the grid, below the menu's buttons
            Item {
                id: toolsLayer
                z: 7.9
                anchors.fill: parent
                visible: layoutArea.visible
            }

            Item {
                id: layoutArea
                // Element tools and handles reaching into the canvas
                // padding keep their clicks
                z: 7.5
                visible: menu.editingApp === null && menu.editingActions === "" && !menu.editingCategories
                // Room inside the canvas padding (elements sit inset by half
                // the gap); the grid fills it exactly, so the distance to
                // the canvas edge is the padding on each side (the side at
                // the bar can have its own)
                readonly property real insetL: menu.cardPadLeft - menu.elementGap / 2
                readonly property real insetR: menu.cardPadRight - menu.elementGap / 2
                readonly property real insetT: menu.cardPadTop - menu.elementGap / 2
                readonly property real insetB: menu.cardPadBottom - menu.elementGap / 2
                readonly property real availW: parent.width - insetL - insetR
                readonly property real availH: parent.height - insetT - insetB
                onAvailWChanged: if (availW > 0) menu.layoutAreaWidth = availW
                onAvailHChanged: if (availH > 0) menu.layoutAreaHeight = availH
                width: availW
                height: availH
                x: insetL
                y: insetT
                clip: !layoutGrid.editMode

                // Element tools in edit mode: each element reports its frame
                // and number of buttons; one placement for all (focused
                // element first, then top to bottom): above (right-, else
                // left-aligned), below, right, left of the frame; a spot is
                // taken if it stays inside the grid area (beyond it, in the
                // canvas padding, the buttons are drawn but get no clicks)
                // and touches no other frame and no tools placed before;
                // last choice: inside the element's top right corner.
                // No free spot: placed anyway (inside the grid).
                property var toolInfo: ({})
                function reportToolInfo(id, info) {
                    const next = Object.assign({}, toolInfo);
                    if (info)
                        next[id] = info;
                    else
                        delete next[id];
                    toolInfo = next;
                }
                readonly property var toolPlacement: {
                    const info = toolInfo;
                    const ids = Object.keys(info);
                    const B = { "l": -insetL + 2, "t": -insetT + 2, "r": width + insetR - 2, "b": height + insetB - 2 };
                    const g = 2, sp = Theme.spacingXS;
                    const inside = r => r.l >= B.l - 0.5 && r.t >= B.t - 0.5 && r.r <= B.r + 0.5 && r.b <= B.b + 0.5;
                    const hit = (a, b) => a.l < b.r && a.r > b.l && a.t < b.b && a.b > b.t;
                    // The menu's own buttons (top right of the canvas) are an
                    // obstacle too
                    const m = 4;
                    const bar = menuToolbar.visible && menuToolbar.width > 0 ? { "l": menuToolbar.x - x - m, "t": menuToolbar.y - y - m, "r": menuToolbar.x + menuToolbar.width - x + m, "b": menuToolbar.y + menuToolbar.height - y + m } : null;
                    const onBar = r => bar !== null && hit(r, bar);
                    const taken = [];
                    const free = (r, id) => inside(r) && !onBar(r) && !ids.some(o => o !== id && hit(r, info[o])) && !taken.some(t => hit(r, t));
                    const focus = menu.focusedElement;
                    const order = ids.slice().sort((a, b) => (a === focus ? -1 : b === focus ? 1 : 0) || (info[a].t - info[b].t) || (info[a].l - info[b].l));
                    const out = {};
                    for (const id of order) {
                        const f = info[id];
                        const tw = f.n * f.btn, th = f.btn;
                        const lineW = Math.max(f.r - f.l, tw);
                        const cands = [];
                        for (const y of [f.t - g - th, f.b + g]) {
                            const mode = y < f.t ? "above" : "below";
                            cands.push({ "mode": mode, "line": { "l": f.r - lineW, "t": y, "r": f.r, "b": y + th }, "tx": f.r - tw, "ty": y, "nameX": f.r - lineW + sp, "nameW": lineW - tw - 2 * sp });
                            cands.push({ "mode": mode, "line": { "l": f.l, "t": y, "r": f.l + lineW, "b": y + th }, "tx": f.l, "ty": y, "nameX": f.l + tw + sp, "nameW": lineW - tw - 2 * sp });
                        }
                        cands.push({ "mode": "right", "line": { "l": f.r + g, "t": f.t, "r": f.r + g + f.btn, "b": f.t + tw }, "tx": f.r + g, "ty": f.t, "nameW": 0 });
                        cands.push({ "mode": "left", "line": { "l": f.l - g - f.btn, "t": f.t, "r": f.l - g, "b": f.t + tw }, "tx": f.l - g - f.btn, "ty": f.t, "nameW": 0 });
                        // Inside the element, top right (over its own content)
                        cands.push({ "mode": "inside", "line": { "l": f.r - tw - g, "t": f.t + g, "r": f.r - g, "b": f.t + g + th }, "tx": f.r - tw - g, "ty": f.t + g, "nameW": 0 });
                        let pick = cands.find(c => free(c.line, id));
                        // No free spot: still somewhere inside the grid (every
                        // element keeps reachable tools, even over a neighbour)
                        if (!pick)
                            pick = cands.find(c => inside(c.line) && !onBar(c.line)) ?? cands.find(c => inside(c.line)) ?? cands[cands.length - 1];
                        if (pick) {
                            taken.push(pick.line);
                            out[id] = pick;
                        } else {
                            out[id] = { "mode": "hidden" };
                        }
                    }
                    return out;
                }

                // No gap between cells: the element gap is an inset of each
                // element (elementGap / 2 per side), independent of the grid size
                readonly property real gap: 0
                readonly property real columnWidth: (width - gap * (menu.gridColumns - 1)) / menu.gridColumns
                readonly property real rowUnit: Math.max(4, (height - gap * (menu.gridRows - 1)) / menu.gridRows)
                onRowUnitChanged: report()
                onColumnWidthChanged: report()

                onGapChanged: menu.layoutGap = gap
                Component.onCompleted: {
                    menu.layoutGap = gap;
                    if (availW > 0)
                        menu.layoutAreaWidth = availW;
                    if (availH > 0)
                        menu.layoutAreaHeight = availH;
                    report();
                }
                // Not while the menu has no size yet (closed, first layout)
                function report() {
                    if (width < menu.gridColumns || height < menu.gridRows)
                        return;
                    menu.layoutColumnWidth = columnWidth;
                    menu.layoutRowUnit = rowUnit;
                    if (!menu.layoutMeasured)
                        menu.layoutMeasured = true;
                }

                // Drop an app on the empty canvas: new shortcuts element there
                // (dropOnCanvas ignores cells covered by an element)
                DropArea {
                    anchors.fill: parent
                    enabled: !menu.layoutEditing
                    keys: ["custommenu-app"]
                    onDropped: drop => menu.dropOnCanvas(Math.floor(drop.x / layoutArea.columnWidth), Math.floor(drop.y / layoutArea.rowUnit))
                }

                // Edit mode: the cells of the menu grid as fine lines
                Repeater {
                    model: menu.layoutEditing && menu.showGridLines ? menu.gridColumns + 1 : 0
                    Rectangle {
                        required property int index
                        z: -1
                        // The middle stands out (even number of columns), every
                        // fifth line from it a little
                        readonly property bool middle: index === menu.gridColumns / 2
                        readonly property bool major: (index - menu.gridColumns / 2) % 5 === 0
                        readonly property int thickness: middle ? 3 : major ? 2 : 1
                        x: Math.round(index * layoutArea.columnWidth - thickness / 2)
                        width: thickness
                        height: layoutArea.height
                        color: middle ? Theme.withAlpha(Theme.secondary, 0.35) : Theme.withAlpha(Theme.outline, major ? 0.175 : 0.075)
                    }
                }
                Repeater {
                    model: menu.layoutEditing && menu.showGridLines ? menu.gridRows + 1 : 0
                    Rectangle {
                        required property int index
                        z: -1
                        readonly property bool middle: index === menu.gridRows / 2
                        readonly property bool major: (index - menu.gridRows / 2) % 5 === 0
                        readonly property int thickness: middle ? 3 : major ? 2 : 1
                        y: Math.round(index * layoutArea.rowUnit - thickness / 2)
                        width: layoutArea.width
                        height: thickness
                        color: middle ? Theme.withAlpha(Theme.secondary, 0.35) : Theme.withAlpha(Theme.outline, major ? 0.175 : 0.075)
                    }
                }

                // Edit mode: not all elements fit at their minimum size
                StyledRect {
                    visible: layoutGrid.editMode && menu.layoutOverflow
                    z: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: overflowText.implicitWidth + Theme.spacingL * 2
                    height: overflowText.implicitHeight + Theme.spacingS * 2
                    radius: Theme.cornerRadius
                    color: Theme.errorContainer

                    StyledText {
                        id: overflowText
                        anchors.centerIn: parent
                        text: I18n.trFor("customMenu", "Menu too small for all elements: enlarge it or remove an element")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.onErrorContainer
                    }
                }

                // Guide lines while an element is dragged or resized: 1 px
                // in the text colour where one of its edges (left, right,
                // top, bottom) or its middle lines up with the same of
                // another element, at the target position the grid shows
                Item {
                    id: snapGuides
                    anchors.fill: layoutGrid
                    z: 50
                    visible: layoutGrid.editMode && layoutGrid.interactingIndex >= 0
                    // Frames (edit outlines): the dragged/resized element at its
                    // target cell, the others where they are
                    function frameOf(i, slot) {
                        const it = slotRepeater.itemAt(i);
                        if (!slot || !it)
                            return null;
                        const x = slot.x + it.frameX, y = slot.y + it.frameY;
                        return { "l": x, "t": y, "r": x + it.frameW, "b": y + it.frameH };
                    }
                    // A guide connects the two frames: from 10 px after the first
                    // to 10 px before the second (over elements in between)
                    readonly property var guides: {
                        const slots = layoutGrid.slotLayout?.slots ?? [];
                        const idx = layoutGrid.interactingIndex;
                        const me = idx >= 0 ? frameOf(idx, slots[idx]) : null;
                        if (!me)
                            return [];
                        const near = (a, b) => Math.abs(a - b) < 0.5;
                        const gap = 10;
                        const out = [];
                        const span = (vertical, pos, a0, a1, b0, b1) => {
                            // a, b: extents along the line; the gap between them
                            const from = a1 <= b0 ? a1 + gap : b1 + gap;
                            const to = a1 <= b0 ? b0 - gap : a0 - gap;
                            if (to - from >= 1)
                                out.push({ "vertical": vertical, "pos": pos, "from": from, "to": to });
                        };
                        slots.forEach((slot, i) => {
                            if (i === idx)
                                return;
                            const o = frameOf(i, slot);
                            if (!o)
                                return;
                            if (near(o.l, me.l))
                                span(true, me.l, me.t, me.b, o.t, o.b);
                            if (near(o.r, me.r))
                                span(true, me.r - 1, me.t, me.b, o.t, o.b);
                            if (near(o.t, me.t))
                                span(false, me.t, me.l, me.r, o.l, o.r);
                            if (near(o.b, me.b))
                                span(false, me.b - 1, me.l, me.r, o.l, o.r);
                            // Centres: same middle height → horizontal line through
                            // both middles; same middle across → vertical line
                            if (near((o.t + o.b) / 2, (me.t + me.b) / 2))
                                span(false, Math.floor((me.t + me.b) / 2), me.l, me.r, o.l, o.r);
                            if (near((o.l + o.r) / 2, (me.l + me.r) / 2))
                                span(true, Math.floor((me.l + me.r) / 2), me.t, me.b, o.t, o.b);
                        });
                        return out;
                    }
                    Repeater {
                        model: snapGuides.guides
                        Rectangle {
                            required property var modelData
                            x: Math.round(modelData.vertical ? modelData.pos : modelData.from)
                            y: Math.round(modelData.vertical ? modelData.from : modelData.pos)
                            width: modelData.vertical ? 1 : Math.round(modelData.to - modelData.from)
                            height: modelData.vertical ? Math.round(modelData.to - modelData.from) : 1
                            color: menu.appTextColor
                        }
                    }
                }

                DEditableGrid {
                    id: layoutGrid
                    width: parent.width
                    editMode: menu.layoutEditing
                    sourceItems: menu.layoutItems
                    // Placement order: locked elements first, so dragging another
                    // element never pushes them (it gives way itself)
                    slotLayout: GridUtils.packCards(layoutItems, menu.lockedFirst(layoutItems, placementOrder), menu.gridColumns, width, layoutArea.gap, layoutArea.rowUnit, I18n.isRtl, () => true)
                    placeholderRadius: Theme.cornerRadius
                    // DMS' grid may push elements below the last row: fit first
                    // DMS' drop preview covers the full cells; the elements sit
                    // inset by half the element gap. Inset the preview too, so
                    // it shows exactly where the element will be (otherwise
                    // aligning it with a neighbour lands one row off).
                    Component.onCompleted: {
                        for (const child of layoutGrid.children) {
                            if (!("slot" in child) || "grid" in child || child.radius === undefined)
                                continue;
                            const preview = child;
                            preview.x = Qt.binding(() => preview.slot ? preview.slot.x + menu.elementGap / 2 : 0);
                            preview.y = Qt.binding(() => preview.slot ? preview.slot.y + menu.elementGap / 2 : 0);
                            preview.width = Qt.binding(() => preview.slot ? Math.max(0, preview.slot.w - menu.elementGap) : 0);
                            preview.height = Qt.binding(() => preview.slot ? Math.max(0, preview.slot.h - menu.elementGap) : 0);
                        }
                    }
                    // DMS hands the committed layout to this callback (before
                    // r505: the signal layoutCommitted)
                    commitHandler: items => {
                        menu.saveLayout(menu.fitLayout(items).items);
                    }

                    Repeater {
                        id: slotRepeater
                        model: layoutGrid.tileModel

                        DEditableGridSlot {
                            id: slotItem
                            grid: layoutGrid
                            readonly property var element: JSON.parse(json)
                            // Index of this element (inner Repeaters have their own index)
                            readonly property int tileIndex: index

                            // While the element's own editing is open (pen: category
                            // list, title field) it does not move: dragging there
                            // selects text. The slot's DragHandler has no id, so it
                            // is looked up among the slot's children.
                            readonly property bool locked: menu.lockedElements.indexOf(element.id) >= 0
                            // Also a locked element is not dragged
                            readonly property bool lockDrag: menu.elementEditing === element.id || locked
                            // ...and clicks reach the content (text fields), not the
                            // slot's drag area (edge handles stay above)
                            passthrough: lockDrag ? elementContent : null
                            property var dragHandlerRef: null
                            // The slot's drag area (no id either): a press on the
                            // element gives it the focus
                            property var dragAreaRef: null
                            Component.onCompleted: {
                                for (const o of data) {
                                    if (!dragHandlerRef && String(o).startsWith("QQuickDragHandler"))
                                        dragHandlerRef = o;
                                    if (!dragAreaRef && String(o).startsWith("QQuickMouseArea"))
                                        dragAreaRef = o;
                                }
                                if (!dragHandlerRef)
                                    console.warn("customMenu: DragHandler of the grid slot not found (DMS changed?), elements stay movable while editing");
                            }
                            Binding {
                                target: slotItem.dragHandlerRef
                                property: "enabled"
                                value: false
                                when: slotItem.lockDrag && slotItem.dragHandlerRef !== null
                            }
                            readonly property bool focused: layoutGrid.editMode && menu.focusedElement === element.id
                            // On top: the dragged/resized element (DMS' rule), else the
                            // focused one with its tools and the alignment choices
                            z: dragging || resizing ? 3 : focused ? 2 : 0
                            // Edit frame relative to the slot (for the guide lines)
                            readonly property real frameX: jumpFrame.x + editOutline.x
                            readonly property real frameY: jumpFrame.y + editOutline.y
                            readonly property real frameW: editOutline.width
                            readonly property real frameH: editOutline.height
                            Connections {
                                target: slotItem.dragAreaRef
                                ignoreUnknownSignals: true
                                function onPressedChanged() {
                                    if (slotItem.dragAreaRef?.pressed)
                                        menu.focusedElement = slotItem.element.id;
                                }
                            }
                            onDraggingChanged: if (dragging) menu.focusedElement = element.id
                            onResizingChanged: if (resizing) menu.focusedElement = element.id

                            onResizeRequested: (requestedWidth, requestedHeight) => {
                                const g = layoutArea.gap;
                                const w = Math.round((requestedWidth + g) / (layoutArea.columnWidth + g));
                                const h = Math.round((requestedHeight + g) / (layoutArea.rowUnit + g));
                                layoutGrid.previewSize(index, {
                                    "w": Math.max(1, Math.min(w, menu.gridColumns - (slot?.col ?? 0))),
                                    "h": slotItem.element.id === "search" ? menu.minRows("search") : Math.max(menu.minRows(slotItem.element.id), Math.min(h, menu.gridRows - (slot?.row ?? 0)))
                                });
                            }

                            // Everything visible sits inset by half the element gap, so
                            // two neighbours are exactly elementGap apart (the grid itself
                            // has no gap; see layoutArea)
                            Item {
                                id: jumpFrame
                                // Click with the settings open: on the element (its
                                // background and around it) its general settings
                                readonly property string jumpSection: menu.elementSections[menu.elementType(slotItem.element.id)] ?? ""
                                readonly property string jumpElementId: slotItem.element.id
                                readonly property Item jumpBounds: elementBg
                                // Above the slot's own drag area (z 1), so the edge
                                // handles and the remove button get the mouse; the
                                // content is disabled in edit mode, so dragging the
                                // element still works everywhere else
                                z: 2
                                // Inset by half the gap, on whole pixels of the canvas: the
                                // grid's cells are fractions of a pixel wide, and 1 px
                                // borders between two pixels look blurred and doubled
                                readonly property real ox: layoutArea.x + slotItem.x
                                readonly property real oy: layoutArea.y + slotItem.y
                                readonly property real g: menu.elementGap / 2
                                x: Math.round(ox + g) - ox
                                y: Math.round(oy + g) - oy
                                width: Math.round(ox + slotItem.width - g) - Math.round(ox + g)
                                height: Math.round(oy + slotItem.height - g) - Math.round(oy + g)

                                // Element background (optional). Shortcuts: only as big
                                // as their tiles (the element snaps to the menu grid,
                                // the rest stays transparent)
                                Rectangle {
                                    id: elementBg
                                    readonly property var style: menu.areaStyleFor(slotItem.element.id)
                                    width: elementContent.hugWidth
                                    height: elementContent.hugHeight
                                    color: style?.color ?? "transparent"
                                    radius: Math.min(style?.radius ?? 0, width / 2, height / 2)
                                    // Blur behind it, exactly in its shape (setting)
                                    readonly property bool wantsBlur: menu.menuTransparent && !!style?.blur
                                    property var blurRegion: Region {
                                        // Window geometry, following DMS' animation
                                        readonly property var g: menu.blurGeom(elementBg, menu.menuOpen, menu.dmsWrapper?.x ?? 0, menu.dmsWrapper?.y ?? 0, menu.dmsWrapper?.scale ?? 1, elementBg.x + slotItem.x, elementBg.y + slotItem.y, elementBg.width, elementBg.height, elementBg.radius)
                                        x: g.x
                                        y: g.y
                                        width: g.w
                                        height: g.h
                                        radius: g.r
                                    }
                                    onWantsBlurChanged: menu.setBlurPart(slotItem.element.id, wantsBlur ? blurRegion : null)
                                    Component.onCompleted: menu.setBlurPart(slotItem.element.id, wantsBlur ? blurRegion : null)
                                    Component.onDestruction: menu.setBlurPart(slotItem.element.id, null)
                                }

                                // Content never spills over the element
                                Loader {
                                    id: elementContent
                                    anchors.fill: parent
                                    anchors.margins: pad
                                    // Shortcuts draw their drop cells past the element while
                                    // an app is dragged
                                    clip: !(menu.appDragging && elementType === "tiles")
                                    readonly property real pad: menu.areaStyleFor(slotItem.element.id)?.padding ?? 0
                                    // Visible size: whole slot, shortcuts their content
                                    // (while dragging an app also bigger than the slot: the drop cells)
                                    // Buttons fill the slot (sized freely), only the drop cells can reach past it
                                    readonly property bool fills: menu.isTileElement(slotItem.element.id)
                                    readonly property real hugWidth: item?.contentFitWidth !== undefined ? (menu.appDragging ? Math.max(fills ? parent.width : 0, item.contentFitWidth + pad * 2) : (fills ? parent.width : Math.min(parent.width, item.contentFitWidth + pad * 2))) : parent.width
                                    readonly property real hugHeight: item?.contentFitHeight !== undefined ? (menu.appDragging ? Math.max(fills ? parent.height : 0, item.contentFitHeight + pad * 2) : (fills ? parent.height : Math.min(parent.height, item.contentFitHeight + pad * 2))) : parent.height
                                    // Edit mode: the elements lock their own controls
                                    // (search field, chips, app tiles); group headers
                                    // stay usable
                                    readonly property var slotData: slotItem.slot
                                    readonly property string elementId: slotItem.element.id
                                    readonly property string elementType: menu.elementType(slotItem.element.id)
                                    sourceComponent: elementType === "apps" ? appsElement : elementType === "categories" ? categoriesElement : elementType === "tiles" ? shortcutsElement : searchElement
                                }

                                // Element border (optional), above the content
                                Rectangle {
                                    readonly property var style: menu.areaStyleFor(slotItem.element.id)
                                    width: elementContent.hugWidth
                                    height: elementContent.hugHeight
                                    visible: (style?.borderWidth ?? 0) > 0
                                    color: "transparent"
                                    border.width: style?.borderWidth ?? 0
                                    border.color: style?.borderColor ?? "transparent"
                                    radius: Math.min(style?.radius ?? 0, width / 2, height / 2)
                                }

                                // Edit mode: outline 8 px around the element background
                                // (tile elements: their tiles), so the element stays
                                // fully visible; name, tools and handles sit on it. The
                                // grid's snap preview keeps the element's own size.
                                Rectangle {
                                    id: editOutline
                                    readonly property real pad: 8
                                    visible: layoutGrid.editMode
                                    x: -pad
                                    y: -pad
                                    width: elementContent.hugWidth + pad * 2
                                    height: elementContent.hugHeight + pad * 2
                                    // Small fixed rounding: a larger one would touch the
                                    // element's own frame in the corners
                                    radius: 5
                                    color: Theme.withAlpha(Theme.primary, 0.06)
                                    border.width: slotItem.focused ? 3 : 2
                                    border.color: slotItem.dragging || slotItem.resizing || slotItem.focused ? Theme.primary : Theme.outlineVariant
                                }

                                // Element tools, outside the element. Where: computed for all
                                // elements at once (layoutArea.toolPlacement): above or below
                                // with the name, else beside it as a column without the name,
                                // where it touches no other frame/tools and stays in the card.
                                // Grid coordinates of this content item's origin:
                                readonly property real originX: slotItem.x + x
                                readonly property real originY: slotItem.y + y
                                readonly property int toolCount: (slotItem.focused && !slotItem.locked ? 2 : 0) + 1 + (menu.isTileElement(slotItem.element.id) || slotItem.element.id === "categories" ? 1 : 0) + 1
                                readonly property var toolInfo: ({
                                    "l": originX + editOutline.x, "t": originY + editOutline.y,
                                    "r": originX + editOutline.x + editOutline.width, "b": originY + editOutline.y + editOutline.height,
                                    "n": toolCount, "btn": removeButton.width
                                })
                                onToolInfoChanged: layoutArea.reportToolInfo(slotItem.element.id, toolInfo)
                                Component.onCompleted: {
                                    layoutArea.reportToolInfo(slotItem.element.id, toolInfo);
                                    menu.jumpFrames.push(jumpFrame);
                                }
                                Component.onDestruction: {
                                    layoutArea.reportToolInfo(slotItem.element.id, null);
                                    const i = menu.jumpFrames.indexOf(jumpFrame);
                                    if (i >= 0)
                                        menu.jumpFrames.splice(i, 1);
                                }
                                readonly property var place: layoutArea.toolPlacement[slotItem.element.id] ?? ({ "mode": "hidden" })
                                readonly property bool toolsShown: layoutGrid.editMode && place.mode !== "hidden"
                                readonly property bool toolsSide: place.mode === "left" || place.mode === "right"
                                // On a layer over the whole canvas (toolsLayer): beyond the
                                // grid area, in the canvas padding, children of the grid
                                // get no pointer events
                                Grid {
                                    id: elementTools
                                    parent: toolsLayer
                                    visible: jumpFrame.toolsShown
                                    z: 20
                                    columns: jumpFrame.toolsSide ? 1 : 100
                                    x: (jumpFrame.place.tx ?? 0) + layoutArea.x
                                    y: (jumpFrame.place.ty ?? 0) + layoutArea.y

                                    // Focused element: align it (each opens its choices)
                                    Repeater {
                                        model: slotItem.focused && !slotItem.locked ? [
                                            { "axis": "h", "icon": "align_horizontal_center", "tip": I18n.trFor("customMenu", "Align horizontally") },
                                            { "axis": "v", "icon": "align_vertical_center", "tip": I18n.trFor("customMenu", "Align vertically") }
                                        ] : []
                                        DActionButton {
                                            required property var modelData
                                            iconName: modelData.icon
                                            iconColor: Theme.primary
                                            tooltipText: modelData.tip
                                            onClicked: menu.alignMenu = menu.alignMenu === modelData.axis ? "" : modelData.axis
                                        }
                                    }
                                    // Lock: the element stays where it is (others give way)
                                    DActionButton {
                                        iconName: slotItem.locked ? "lock" : "lock_open"
                                        iconColor: slotItem.locked ? Theme.primary : Theme.withAlpha(Theme.primary, 0.6)
                                        tooltipText: slotItem.locked ? I18n.trFor("customMenu", "Locked: click to unlock") : I18n.trFor("customMenu", "Lock in place")
                                        onClicked: menu.toggleLock(slotItem.element.id)
                                    }
                                    // Element pen: manage the element's content
                                    DActionButton {
                                        id: penButton
                                        visible: menu.isTileElement(slotItem.element.id) || slotItem.element.id === "categories"
                                        iconName: menu.elementEditing === slotItem.element.id ? "check" : "edit"
                                        iconColor: Theme.primary
                                        tooltipText: menu.elementEditing === slotItem.element.id ? I18n.trFor("customMenu", "Done") : slotItem.element.id === "categories" ? I18n.trFor("customMenu", "Edit categories") : I18n.trFor("customMenu", "Edit tiles")
                                        onClicked: {
                                            // Tiles: card-wide panel (room for the icon picker)
                                            if (menu.isTileElement(slotItem.element.id)) {
                                                menu.editingActions = slotItem.element.id;
                                                return;
                                            }
                                            // Categories: card-wide editor (like the buttons)
                                            if (slotItem.element.id === "categories") {
                                                menu.editingCategories = true;
                                                return;
                                            }
                                            menu.elementEditing = menu.elementEditing === slotItem.element.id ? "" : slotItem.element.id;
                                        }
                                    }
                                    DActionButton {
                                        id: removeButton
                                        iconName: "close"
                                        iconColor: Theme.primary
                                        tooltipText: I18n.trFor("customMenu", "Remove element")
                                        onClicked: menu.removeElement(slotItem.element.id)
                                    }
                                }
                                // Element name on the tools' line (above/below only, if
                                // there is room for it)
                                StyledText {
                                    parent: toolsLayer
                                    visible: jumpFrame.toolsShown && !jumpFrame.toolsSide && (jumpFrame.place.nameW ?? 0) >= 24
                                    z: 20
                                    x: (jumpFrame.place.nameX ?? 0) + layoutArea.x
                                    anchors.verticalCenter: elementTools.verticalCenter
                                    width: Math.max(0, jumpFrame.place.nameW ?? 0)
                                    elide: Text.ElideRight
                                    text: menu.elementTitle(slotItem.element.id)
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Theme.fontWeightMedium
                                    color: Theme.primary
                                }
                                // Alignment choices, opaque, below/above the tools
                                Rectangle {
                                    id: alignBox
                                    parent: toolsLayer
                                    visible: slotItem.focused && menu.alignMenu !== ""
                                    z: 30
                                    // Next to the tools, away from the element
                                    x: jumpFrame.place.mode === "right" ? elementTools.x + elementTools.width + 2 : jumpFrame.place.mode === "left" ? elementTools.x - width - 2 : Math.max(elementTools.x, elementTools.x + elementTools.width - width)
                                    // Above the tools only if it stays in the canvas, else below
                                    readonly property real aboveY: elementTools.y - height - 2
                                    readonly property real canvasTop: 0
                                    y: jumpFrame.place.mode === "below" || (!jumpFrame.toolsSide && aboveY < canvasTop) ? elementTools.y + elementTools.height + 2 : jumpFrame.toolsSide ? elementTools.y : aboveY
                                    width: alignChoices.implicitWidth + Theme.spacingXS * 2
                                    height: alignChoices.implicitHeight + Theme.spacingXS * 2
                                    radius: Theme.cornerRadius
                                    readonly property color base: Theme.surfaceContainerHigh
                                    color: Qt.rgba(base.r, base.g, base.b, 1)
                                    border.width: 1
                                    border.color: Theme.outlineVariant
                                    Row {
                                        id: alignChoices
                                        anchors.centerIn: parent
                                        Repeater {
                                            model: menu.alignMenu === "h" ? [
                                                { "where": "start", "icon": "align_horizontal_left", "tip": I18n.trFor("customMenu", "Left") },
                                                { "where": "center", "icon": "align_horizontal_center", "tip": I18n.trFor("customMenu", "Centered") },
                                                { "where": "end", "icon": "align_horizontal_right", "tip": I18n.trFor("customMenu", "Right") },
                                                { "where": "between", "icon": "horizontal_distribute", "tip": I18n.trFor("customMenu", "Centered between neighbors") }
                                            ] : [
                                                { "where": "start", "icon": "align_vertical_top", "tip": I18n.trFor("customMenu", "Top") },
                                                { "where": "center", "icon": "align_vertical_center", "tip": I18n.trFor("customMenu", "Centered") },
                                                { "where": "end", "icon": "align_vertical_bottom", "tip": I18n.trFor("customMenu", "Bottom") },
                                                { "where": "between", "icon": "vertical_distribute", "tip": I18n.trFor("customMenu", "Centered between neighbors") }
                                            ]
                                            DActionButton {
                                                required property var modelData
                                                iconName: modelData.icon
                                                iconColor: Theme.primary
                                                tooltipText: modelData.tip
                                                onClicked: menu.alignElement(slotItem.element.id, menu.alignMenu, modelData.where)
                                            }
                                        }
                                    }
                                }

                                // Edge handles: drag any of the four edges. Left/top move
                                // that edge (position and size change, the opposite edge
                                // stays), right/bottom only resize. Search: height comes
                                // from the settings, so left/right only.
                                Repeater {
                                    // Search: height comes from the field
                                    model: menu.elementType(slotItem.element.id) === "search" ? ["left", "right"] : ["left", "right", "top", "bottom"]

                                    MouseArea {
                                        id: edge
                                        required property string modelData
                                        readonly property bool horizontal: modelData === "left" || modelData === "right"
                                        readonly property real thickness: 12
                                        visible: layoutGrid.editMode && !slotItem.locked
                                        z: 2
                                        x: editOutline.x + (modelData === "right" ? editOutline.width - thickness : 0)
                                        y: editOutline.y + (modelData === "bottom" ? editOutline.height - thickness : 0)
                                        width: horizontal ? thickness : editOutline.width
                                        height: horizontal ? editOutline.height : thickness
                                        hoverEnabled: true
                                        cursorShape: horizontal ? Qt.SizeHorCursor : Qt.SizeVerCursor
                                        preventStealing: true

                                        property var start: null

                                        // Highlight of the grabbed edge
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: edge.horizontal ? 3 : Math.min(parent.width, 32)
                                            height: edge.horizontal ? Math.min(parent.height, 32) : 3
                                            radius: 1.5
                                            color: Theme.primary
                                            opacity: edge.pressed ? 1 : (edge.containsMouse ? 0.8 : 0.35)
                                        }

                                        onPressed: mouse => {
                                            const p = mapToItem(layoutArea, mouse.x, mouse.y);
                                            const it = slotItem.element;
                                            start = { "x": p.x, "y": p.y, "col": it.col, "row": it.row, "w": it.w, "h": it.h };
                                        }
                                        onPositionChanged: mouse => {
                                            if (!start)
                                                return;
                                            const p = mapToItem(layoutArea, mouse.x, mouse.y);
                                            const g = layoutArea.gap;
                                            const dc = Math.round((p.x - start.x) / (layoutArea.columnWidth + g));
                                            const dr = Math.round((p.y - start.y) / (layoutArea.rowUnit + g));
                                            const minH = menu.minRows(slotItem.element.id);
                                            const right = start.col + start.w;
                                            const bottom = start.row + start.h;
                                            // The edge stops at a neighbouring element instead of
                                            // pushing it away (DMS' grid would repack the others)
                                            const others = menu.layoutItems.filter(o => o.id !== slotItem.element.id);
                                            const rowsOverlap = o => o.row < bottom && o.row + o.h > start.row;
                                            const colsOverlap = o => o.col < right && o.col + o.w > start.col;
                                            const leftLimit = others.filter(o => rowsOverlap(o) && o.col + o.w <= start.col).reduce((m, o) => Math.max(m, o.col + o.w), 0);
                                            const rightLimit = others.filter(o => rowsOverlap(o) && o.col >= right).reduce((m, o) => Math.min(m, o.col), menu.gridColumns);
                                            const topLimit = others.filter(o => colsOverlap(o) && o.row + o.h <= start.row).reduce((m, o) => Math.max(m, o.row + o.h), 0);
                                            const bottomLimit = others.filter(o => colsOverlap(o) && o.row >= bottom).reduce((m, o) => Math.min(m, o.row), menu.gridRows);
                                            let c = { "col": start.col, "row": start.row, "w": start.w, "h": start.h };
                                            switch (modelData) {
                                            case "left":
                                                c.col = Math.max(leftLimit, Math.min(right - 1, start.col + dc));
                                                c.w = right - c.col;
                                                break;
                                            case "right":
                                                c.w = Math.max(1, Math.min(rightLimit - start.col, start.w + dc));
                                                break;
                                            case "top":
                                                c.row = Math.max(topLimit, Math.min(bottom - minH, start.row + dr));
                                                c.h = bottom - c.row;
                                                break;
                                            case "bottom":
                                                c.h = Math.max(minH, Math.min(bottomLimit - start.row, start.h + dr));
                                                break;
                                            }
                                            layoutGrid.previewSize(slotItem.tileIndex, c);
                                        }
                                        onReleased: {
                                            start = null;
                                            layoutGrid.commitSize();
                                        }
                                        onCanceled: {
                                            start = null;
                                            layoutGrid.cancelInteraction();
                                        }
                                    }
                                }

                                MouseArea {
                                    visible: layoutGrid.editMode && !slotItem.locked
                                    z: 3
                                    width: 24
                                    height: 24
                                    anchors.right: editOutline.right
                                    anchors.bottom: editOutline.bottom
                                    // Search: height comes from the settings, width only
                                    readonly property bool widthOnly: menu.elementType(slotItem.element.id) === "search"
                                    cursorShape: widthOnly ? Qt.SizeHorCursor : Qt.SizeFDiagCursor
                                    preventStealing: true
                                    onPressed: mouse => {
                                        const p = mapToItem(slotItem, mouse.x, mouse.y);
                                        slotItem.beginResize(p.x, p.y);
                                    }
                                    onPositionChanged: mouse => {
                                        const p = mapToItem(slotItem, mouse.x, mouse.y);
                                        slotItem.resizeTo(p.x, p.y);
                                    }
                                    onReleased: slotItem.finishResize()
                                    onCanceled: slotItem.cancelResize()

                                    DIcon {
                                        anchors.centerIn: parent
                                        name: parent.widthOnly ? "swap_horiz" : "open_in_full"
                                        // open_in_full points up right/down left: turned to
                                        // the corner it sits in (down right)
                                        rotation: parent.widthOnly ? 0 : 90
                                        size: 16
                                        color: Theme.primary
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Element: search ──────────────────────────────────────
            Component {
                id: searchElement
                SearchElement {
                    menu: popout.menu
                }
            }

            // ── Element: categories ──────────────────────────────────
            Component {
                id: categoriesElement
                CategoriesElement {
                    menu: popout.menu
                }
            }

            // ── Element: shortcuts ───────────────────────────────────
            // Groups of fixed apps, unaffected by category and search.
            // Element pen (edit mode): manage the groups.
            Component {
                id: shortcutsElement
                TilesElement {
                    menu: popout.menu
                }
            }

            // ── Element: apps ────────────────────────────────────────
            Component {
                id: appsElement
                AppsElement {
                    menu: popout.menu
                }
            }
        }

        // Settings open: a click on a part of the menu jumps to its
        // settings (only that section expanded) instead of acting on
        // it. In edit mode only the ring around the canvas (menu
        // surface) is caught; inside, the edit mode handles clicks.
        MouseArea {
            id: jumpCatcher
            readonly property bool catchAll: menu.previewActive && !menu.layoutEditing && menu.editingApp === null && menu.editingActions === "" && !menu.editingCategories && !menu.scopeListOpen
            // Not in edit mode: there the clicks arrange the elements
            visible: catchAll
            // Hover: the part a click would jump to lights up
            // (secondary colour). { x, y, w, h, r } in this
            // area, or with inner { ix, iy, iw, ih }: a frame
            hoverEnabled: catchAll
            property var hoverShape: null
            onExited: hoverShape = null
            onCatchAllChanged: hoverShape = null
            onPositionChanged: mouse => updateHover(mouse.x, mouse.y)
            function rectOf(item, margin) {
                const p = item.mapToItem(jumpCatcher, -margin, -margin);
                return { "x": p.x, "y": p.y, "w": item.width + margin * 2, "h": item.height + margin * 2, "r": Math.min(5 + margin, (item.width + margin * 2) / 2, (item.height + margin * 2) / 2) };
            }
            function updateHover(mx, my) {
                if (!catchAll) {
                    hoverShape = null;
                    return;
                }
                const p = mapToItem(card, mx, my);
                const c = rectOf(card, 0);
                if (p.x < 0 || p.y < 0 || p.x >= card.width || p.y >= card.height) {
                    // The menu surface around the canvas
                    hoverShape = { "x": 0, "y": 0, "w": width, "h": height, "ix": c.x, "iy": c.y, "iw": c.w, "ih": c.h };
                    return;
                }
                if (menu.passesThrough(card, p.x, p.y)) {
                    hoverShape = null;
                    return;
                }
                const t = menu.jumpTargetAt(card, p.x, p.y);
                const m = menu.jumpMargin;
                if (t.edge) {
                    hoverShape = { "x": c.x, "y": c.y, "w": c.w, "h": c.h, "ix": c.x + m, "iy": c.y + m, "iw": c.w - m * 2, "ih": c.h - m * 2 };
                } else if (t.inset !== undefined) {
                    const o = rectOf(t.item, t.margin), i = rectOf(t.item, -t.inset);
                    hoverShape = { "x": o.x, "y": o.y, "w": o.w, "h": o.h, "ix": i.x, "iy": i.y, "iw": i.w, "ih": i.h };
                } else {
                    const r = rectOf(t.item, t.margin);
                    if (t.clip) {
                        const b = rectOf(t.clip, 0);
                        const x0 = Math.max(r.x, b.x), y0 = Math.max(r.y, b.y);
                        r.w = Math.max(0, Math.min(r.x + r.w, b.x + b.w) - x0);
                        r.h = Math.max(0, Math.min(r.y + r.h, b.y + b.h) - y0);
                        r.x = x0;
                        r.y = y0;
                    }
                    hoverShape = r;
                }
            }
            // Plain shape: one rounded rectangle; frame: four strips
            Repeater {
                model: jumpCatcher.hoverShape ? (jumpCatcher.hoverShape.ix === undefined ? 1 : 4) : 0
                Rectangle {
                    required property int index
                    readonly property var s: jumpCatcher.hoverShape
                    readonly property bool frame: s.ix !== undefined
                    x: !frame ? s.x : index === 1 ? s.ix + s.iw : s.x
                    y: !frame ? s.y : index === 0 ? s.y : index === 3 ? s.iy + s.ih : s.iy
                    width: !frame ? s.w : index === 1 ? s.x + s.w - (s.ix + s.iw) : index === 2 ? s.ix - s.x : s.w
                    height: !frame ? s.h : index === 0 ? s.iy - s.y : index === 3 ? s.y + s.h - (s.iy + s.ih) : s.ih
                    radius: frame ? 0 : s.r
                    color: Theme.withAlpha(Theme.secondary, frame ? 0.35 : 0.2)
                    border.width: frame ? 0 : 2
                    border.color: Theme.withAlpha(Theme.secondary, 0.7)
                }
            }
            z: 2000
            x: -PopoutMetrics.contentPadding
            y: -PopoutMetrics.contentPadding
            width: parent.width + PopoutMetrics.contentPadding * 2
            height: parent.height + PopoutMetrics.contentPadding * 2
            cursorShape: catchAll ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: mouse => {
                const p = mapToItem(card, mouse.x, mouse.y);
                if (p.x < 0 || p.y < 0 || p.x >= card.width || p.y >= card.height) {
                    menu.openSettingsAt("menuSurface", true);
                    return;
                }
                // Outside edit mode; the menu's own buttons (pencil,
                // gear) keep working
                if (!catchAll || menu.passesThrough(card, p.x, p.y)) {
                    mouse.accepted = false;
                    return;
                }
                const key = menu.sectionAt(card, p.x, p.y) || "card";
                // A tile element: its own look
                if (key === "tiles" || key.startsWith("tl"))
                    PluginService.setGlobalVar(menu.pluginId, "tileScope", menu.tileElementAt(card, p.x, p.y));
                menu.openSettingsAt(key, true);
            }
            onWheel: wheel => wheel.accepted = false
        }
    }
}
