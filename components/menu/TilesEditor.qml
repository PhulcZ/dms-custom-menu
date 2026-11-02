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
import "../common"

// ── Buttons editor (element pen of a buttons element) ────
Item {
    id: actionsEditor
    // The menu widget (CustomMenuWidget): its settings and functions
    required property Item menu

    visible: menu.editingActions !== ""
    anchors.fill: parent
    anchors.margins: menu.cardPadding
    readonly property string eid: menu.editingActions
    readonly property var info: {
        menu.shortcutsData;
        return menu.scData(eid);
    }
    // All tiles: buttons and apps
    readonly property var buttons: info.tiles.map(t => t.app)
    readonly property bool flow: menu.isFlowElement(eid)
    // Some button opens a folder or runs a command: column for that
    readonly property bool anyTarget: buttons.some(k => ["path", "command"].indexOf(menu.shortcutsData[eid]?.defs?.[k]?.kind) >= 0)
    property string pickingKey: ""
    // App list open ("Add app")
    property bool pickingApp: false
    readonly property bool listing: pickingKey === "" && !pickingApp
    // Wide enough: the add chips left, the tile rows right, both
    // areas alike, half an area between them
    readonly property bool wide: width >= 900
    readonly property real areaW: width / 2.5
    onVisibleChanged: if (!visible) pickingApp = false

    Column {
        id: editorHead
        visible: actionsEditor.listing
        width: parent.width
        spacing: Theme.spacingS

        Item {
            width: parent.width
            height: doneButton.height
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.trFor("customMenu", "Edit tiles")
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Theme.fontWeightMedium
                color: menu.appTextColor
            }
            DButton {
                id: doneButton
                anchors.right: parent.right
                iconName: "check"
                text: I18n.trFor("customMenu", "Done")
                onClicked: menu.editingActions = ""
            }
        }

        DTextField {
            width: Math.min(parent.width, 420)
            height: 40
            text: actionsEditor.info.title
            placeholderText: I18n.trFor("customMenu", "Title (optional)")
            onEditingFinished: menu.scSetTitle(actionsEditor.eid, text)
        }

        // Arrangement: grid (fixed places, sizes itself) or row
        // (in order, sized freely)
        Row {
            spacing: Theme.spacingXS
            Repeater {
                model: [["grid", "grid_view", I18n.trFor("customMenu", "Grid")], ["flow", "view_stream", I18n.trFor("customMenu", "Row")]]
                DButton {
                    required property var modelData
                    readonly property bool chosen: menu.tileMode(actionsEditor.eid) === modelData[0]
                    iconName: modelData[1]
                    text: modelData[2]
                    backgroundColor: chosen ? Theme.primary : Theme.surfaceContainerHigh
                    textColor: chosen ? Theme.onPrimary : menu.appTextColor
                    onClicked: menu.setTileMode(actionsEditor.eid, modelData[0])
                }
            }
        }

    }

    // Adding: an app (own colour) and the button kinds
    Column {
        id: addPanel
        visible: actionsEditor.listing
        y: editorHead.height + Theme.spacingXL
        width: actionsEditor.wide ? actionsEditor.areaW : parent.width
        spacing: Theme.spacingS

        StyledText {
            text: I18n.trFor("customMenu", "Add")
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            color: Theme.primary
        }
        Flow {
            width: parent.width
            spacing: Theme.spacingXS
            DButton {
                iconName: "apps"
                text: I18n.trFor("customMenu", "Add app")
                backgroundColor: Theme.tertiaryContainer
                textColor: Theme.onTertiaryContainer
                onClicked: {
                    appSearch.text = "";
                    actionsEditor.pickingApp = true;
                    appSearch.forceActiveFocus();
                }
            }
            Repeater {
                // Spaces only in a row (on the grid free cells stay free)
                model: menu.actionKindOrder.filter(k => k !== "spacer" || actionsEditor.flow)
                DButton {
                    required property string modelData
                    iconName: menu.actionKinds[modelData].icon
                    text: menu.actionKinds[modelData].label
                    onClicked: menu.addActionButton(actionsEditor.eid, modelData)
                }
            }
        }
    }

    // One row per button: icon (picker), label, target, hold, remove.
    // Column widths are the same in every row (label at most
    // 280 px, folder/command at most 360 px); the rows and the
    // hint below them are centered, the hint wraps at their width.
    DFlickable {
        id: buttonFlick
        fadeEdges: false
        EdgeFade {
            menu: actionsEditor.menu
            parent: buttonFlick.parent
            target: buttonFlick
        }
        visible: actionsEditor.listing
        // Wide: right area beside the chips; else below them
        anchors.top: actionsEditor.wide ? addPanel.top : addPanel.bottom
        anchors.topMargin: actionsEditor.wide ? 0 : Theme.spacingXL
        anchors.left: parent.left
        anchors.leftMargin: actionsEditor.wide ? actionsEditor.areaW * 1.5 : 0
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        contentWidth: width
        contentHeight: buttonList.implicitHeight + Theme.spacingXL

        readonly property real btn: 40
        readonly property real gap: Theme.spacingS
        readonly property int columnsBesides: actionsEditor.anyTarget ? 5 : 4
        readonly property real avail: width - 4 * btn - columnsBesides * gap
        readonly property real labelW: Math.max(120, Math.min(280, actionsEditor.anyTarget ? avail * 0.4 : avail))
        readonly property real targetW: actionsEditor.anyTarget ? Math.max(120, Math.min(360, avail - labelW)) : 0
        readonly property real rowWidth: 4 * btn + labelW + targetW + columnsBesides * gap

        Column {
            id: buttonList
            // Wide: at the start of its area (half an area from the
            // chips); else centered
            x: actionsEditor.wide ? 0 : Math.max(0, (parent.width - width) / 2)
            width: Math.min(buttonFlick.width, buttonFlick.rowWidth)
            spacing: Theme.spacingXS

            Repeater {
                id: buttonRepeater
                model: actionsEditor.buttons

                Row {
                    id: buttonRow
                    required property string modelData
                    required property int index
                    readonly property var raw: menu.shortcutsData[actionsEditor.eid]?.defs?.[modelData] ?? {}
                    readonly property var def: menu.actionDef(actionsEditor.eid, modelData)
                    readonly property var kind: menu.actionKinds[raw.kind] ?? menu.actionKinds.command
                    readonly property bool hasTarget: raw.kind === "path" || raw.kind === "command"
                    readonly property bool isSpacer: raw.kind === "spacer"
                    // App tile: its icon and name, nothing to set
                    readonly property bool isApp: !String(modelData).startsWith("act:")
                    readonly property var appObj: isApp ? menu.allAppsByKey[modelData] ?? null : null
                    readonly property real btn: buttonFlick.btn
                    readonly property real labelW: buttonFlick.labelW
                    readonly property real targetW: buttonFlick.targetW
                    width: buttonList.width
                    spacing: Theme.spacingS

                    // Order (= order in the element: row by row): drag the handle;
                    // on the grid the places are fixed (empty column)
                    Item {
                        visible: !actionsEditor.flow
                        width: buttonRow.btn
                        height: 1
                    }
                    ReorderHandle {
                        visible: actionsEditor.flow
                        anchors.verticalCenter: parent.verticalCenter
                        width: buttonRow.btn
                        row: buttonRow
                        index: buttonRow.index
                        repeater: buttonRepeater
                        iconColor: menu.appTextColor
                        onMoveRequested: (from, to) => menu.moveActionButtonTo(actionsEditor.eid, from, to)
                    }
                    // Columns: icon, label (spacer: name + length), target
                    // (only if a button has one), hold; all rows alike
                    // Spacer: no icon, the column stays empty
                    Item {
                        visible: buttonRow.isSpacer
                        width: buttonRow.btn
                        height: buttonRow.btn
                    }
                    // Spacer: "Space" where the field texts start, the slider
                    // ends where the label fields end
                    Item {
                        visible: buttonRow.isSpacer
                        width: buttonRow.labelW
                        height: 36
                        anchors.verticalCenter: parent.verticalCenter
                        StyledText {
                            id: spacerLabel
                            x: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.trFor("customMenu", "Spacer")
                            font.pixelSize: Theme.fontSizeMedium
                            color: menu.appTextColor
                        }
                        DSlider {
                            anchors.left: spacerLabel.right
                            anchors.leftMargin: Theme.spacingM
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            minimum: 0
                            maximum: 100
                            value: Math.round(menu.spacerPx(actionsEditor.eid, buttonRow.modelData))
                            unit: "px"
                            wheelEnabled: false
                            onSliderValueChanged: newValue => menu.updateActionButton(actionsEditor.eid, buttonRow.modelData, { "px": newValue })
                        }
                    }
                    // App: icon and name
                    AppTile {
                        visible: buttonRow.isApp
                        anchors.verticalCenter: parent.verticalCenter
                        width: buttonRow.btn
                        height: buttonRow.btn
                        app: buttonRow.appObj
                        showIcon: true
                        showName: false
                    }
                    StyledText {
                        visible: buttonRow.isApp
                        anchors.verticalCenter: parent.verticalCenter
                        width: buttonRow.labelW + (actionsEditor.anyTarget ? buttonRow.targetW + Theme.spacingS : 0)
                        leftPadding: Theme.spacingM
                        elide: Text.ElideRight
                        text: buttonRow.appObj?.name ?? String(buttonRow.modelData)
                        font.pixelSize: Theme.fontSizeMedium
                        color: menu.appTextColor
                    }
                    Item {
                        visible: buttonRow.isApp
                        width: buttonRow.btn
                        height: 1
                    }
                    // Icon: opens the icon picker
                    DActionButton {
                        visible: !buttonRow.isSpacer && !buttonRow.isApp
                        anchors.verticalCenter: parent.verticalCenter
                        buttonSize: buttonRow.btn
                        iconName: (buttonRow.def?.icon ?? "").startsWith("/") ? "image" : (buttonRow.def?.icon ?? "help")
                        iconColor: menu.appTextColor
                        tooltipText: I18n.trFor("customMenu", "Choose icon")
                        onClicked: {
                            actionsEditor.pickingKey = buttonRow.modelData;
                            buttonPicker.open();
                        }
                    }
                    DTextField {
                        visible: !buttonRow.isSpacer && !buttonRow.isApp
                        anchors.verticalCenter: parent.verticalCenter
                        width: buttonRow.labelW
                        height: 36
                        text: buttonRow.raw.label ?? ""
                        // Hint, half transparent: folder/command buttons "Name",
                        // the others their default label
                        placeholderText: buttonRow.hasTarget ? I18n.trFor("customMenu", "Name") : buttonRow.kind.label
                        placeholderColor: Theme.withAlpha(menu.appTextColor, 0.5)
                        onEditingFinished: menu.updateActionButton(actionsEditor.eid, buttonRow.modelData, { "label": text.trim() })
                    }
                    // Folder/file or command (column kept free in the other rows)
                    DTextField {
                        visible: buttonRow.hasTarget
                        anchors.verticalCenter: parent.verticalCenter
                        width: buttonRow.targetW
                        height: 36
                        text: buttonRow.raw.kind === "path" ? (buttonRow.raw.path ?? "") : (buttonRow.raw.command ?? "")
                        placeholderText: buttonRow.raw.kind === "path" ? I18n.trFor("customMenu", "e.g. ~/Downloads") : I18n.trFor("customMenu", "e.g. dms ipc call theme toggle")
                        placeholderColor: Theme.withAlpha(menu.appTextColor, 0.5)
                        onEditingFinished: menu.updateActionButton(actionsEditor.eid, buttonRow.modelData, buttonRow.raw.kind === "path" ? { "path": text.trim() } : { "command": text.trim() })
                    }
                    Item {
                        visible: actionsEditor.anyTarget && !buttonRow.hasTarget && !buttonRow.isApp
                        width: buttonRow.targetW
                        height: 1
                    }
                    // Hold to confirm on/off (works if DMS' power confirmation is on)
                    DActionButton {
                        visible: !buttonRow.isSpacer && !buttonRow.isApp
                        anchors.verticalCenter: parent.verticalCenter
                        buttonSize: buttonRow.btn
                        readonly property bool on: buttonRow.raw.confirm ?? buttonRow.kind.confirm
                        iconName: on ? "front_hand" : "touch_app"
                        iconColor: on ? Theme.primary : menu.appTextColor
                        tooltipText: on ? I18n.trFor("customMenu", "Hold to confirm: on") : I18n.trFor("customMenu", "Hold to confirm: off")
                        onClicked: menu.updateActionButton(actionsEditor.eid, buttonRow.modelData, { "confirm": !on })
                    }
                    Item {
                        visible: buttonRow.isSpacer
                        width: buttonRow.btn
                        height: 1
                    }
                    DActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        buttonSize: buttonRow.btn
                        iconName: "delete"
                        iconColor: menu.appTextColor
                        tooltipText: I18n.trFor("customMenu", "Remove tile")
                        onClicked: menu.scRemoveApp(actionsEditor.eid, buttonRow.modelData)
                    }
                }
            }

            StyledText {
                width: buttonList.width
                topPadding: Theme.spacingM
                wrapMode: Text.WordWrap
                text: actionsEditor.flow ? I18n.trFor("customMenu", "Row: tiles fill the element row by row in this order; widen the element to fit more per row. A spacer shifts the following tiles by its length: to the right within a row, down in a single column. Add apps by dragging them onto the element. Hold to confirm uses DMS' duration (power menu settings).") : I18n.trFor("customMenu", "Grid: each tile keeps its place; drag tiles to move them, right-click to change their size (small, large). The element's width sets the number of columns; its height follows the tiles. Add apps by dragging them onto the element. Hold to confirm uses DMS' duration (power menu settings).")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.withAlpha(menu.appTextColor, 0.6)
            }
        }
    }

    IconPicker {
        id: buttonPicker
        visible: actionsEditor.pickingKey !== ""
        anchors.fill: parent
        currentIcon: menu.actionDef(actionsEditor.eid, actionsEditor.pickingKey)?.icon ?? ""
        favorites: [menu.cfg.iconFavorite1 ?? "", menu.cfg.iconFavorite2 ?? "", menu.cfg.iconFavorite3 ?? ""]
        suggestions: menu.actionKindOrder.map(k => menu.actionKinds[k].icon)
        textColor: menu.appTextColor
        onPicked: path => {
            menu.updateActionButton(actionsEditor.eid, actionsEditor.pickingKey, { "icon": path });
            actionsEditor.pickingKey = "";
        }
        onCancelled: actionsEditor.pickingKey = ""
    }

    // App list: icon and name, filtered by the search; a click
    // adds the app to the element
    Item {
        id: appPicker
        visible: actionsEditor.pickingApp
        anchors.fill: parent
        readonly property var apps: {
            actionsEditor.buttons;
            const q = appSearch.text.trim().toLowerCase();
            const taken = actionsEditor.buttons;
            return Object.keys(menu.allAppsByKey).filter(k => taken.indexOf(k) < 0).map(k => menu.allAppsByKey[k]).filter(a => a && (!q || String(a.name ?? "").toLowerCase().indexOf(q) >= 0)).sort((a, b) => String(a.name ?? "").localeCompare(String(b.name ?? "")));
        }

        Item {
            id: appPickerHead
            width: parent.width
            height: appPickerDone.height
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.trFor("customMenu", "Add app")
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Theme.fontWeightMedium
                color: menu.appTextColor
            }
            DButton {
                id: appPickerDone
                anchors.right: parent.right
                iconName: "arrow_back"
                text: I18n.trFor("customMenu", "Back")
                onClicked: actionsEditor.pickingApp = false
            }
        }
        DTextField {
            id: appSearch
            anchors.top: appPickerHead.bottom
            anchors.topMargin: Theme.spacingS
            width: Math.min(parent.width, 420)
            height: 40
            leftIconName: "search"
            placeholderText: I18n.trFor("customMenu", "Search apps")
            Keys.onEscapePressed: actionsEditor.pickingApp = false
        }
        ListView {
            id: appList
            anchors.top: appSearch.bottom
            anchors.topMargin: Theme.spacingM
            anchors.bottom: parent.bottom
            width: Math.min(parent.width, 520)
            clip: true
            spacing: 2
            model: appPicker.apps
            delegate: Rectangle {
                id: appRow
                required property var modelData
                width: appList.width
                height: 44
                radius: Theme.cornerRadius
                color: appRowMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.12) : "transparent"
                AppTile {
                    id: appRowIcon
                    x: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    app: appRow.modelData
                    showIcon: true
                    showName: false
                }
                StyledText {
                    anchors.left: appRowIcon.right
                    anchors.leftMargin: Theme.spacingM
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: appRow.modelData.name ?? ""
                    font.pixelSize: Theme.fontSizeMedium
                    color: menu.appTextColor
                }
                MouseArea {
                    id: appRowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        menu.scAddApp(actionsEditor.eid, menu.appKey(appRow.modelData), -1, "small");
                        actionsEditor.pickingApp = false;
                    }
                }
            }
        }
    }
}
