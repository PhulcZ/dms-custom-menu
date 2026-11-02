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

Item {
    id: scElement
    // The menu widget (CustomMenuWidget): its settings and functions
    required property Item menu

    readonly property string elementId: parent?.elementId ?? ""
    readonly property var info: menu.scData(elementId)
    // Look of shortcuts or buttons, and the element frame
    readonly property var look: menu.lookOf(elementId)
    readonly property var hull: menu.areaStyleFor(elementId)
    readonly property bool managing: menu.elementEditing === elementId && elementId !== ""
    // Title band beside the tiles (see menu.scTitleBand)
    readonly property bool hasTitle: info.title !== "" && !managing
    readonly property real gap: scElement.look.titleGap
    readonly property string side: scElement.look.titleSide
    readonly property real bandW: hasTitle && (side === "left" || side === "right") ? scTitle.implicitWidth + gap * 2 : 0
    readonly property real bandH: hasTitle && (side === "top" || side === "bottom") ? scTitle.implicitHeight + gap * 2 : 0
    // Tile grid offset inside the element
    readonly property real gridX: side === "left" ? bandW : 0
    readonly property real gridY: side === "top" ? bandH : 0
    // Both arrangements are sized freely; the inner cells follow
    // the size in steps: as many columns/rows as fit, the rest is
    // the margin, placed by the alignment (grid: the cells, row:
    // the tiles). Grid tiles keep their places as long as they fit
    // into the columns; the others move to the next free cells.
    // Taller than the element: scrolls vertically (like the apps).
    readonly property bool flow: menu.isFlowElement(elementId)
    readonly property real availW: Math.max(0, width - bandW)
    readonly property real availH: Math.max(0, height - bandH)
    readonly property int fitColumns: Math.max(1, Math.floor((availW + scElement.look.spacing) / step))
    readonly property int fitRows: Math.max(1, Math.floor((availH + scElement.look.spacing) / step))
    readonly property int columns: fitColumns
    // Grid: rows shown (all that fit, more if the tiles reach further)
    readonly property int gridRowsShown: Math.max(fitRows, Math.ceil(usedRows - 1e-6))
    // Row while an app is dragged: aligned as the drop cells (all
    // columns, one row more), so cells and tiles line up (the
    // tiles move once when the drag starts)
    readonly property real contentW: (flow ? (menu.appDragging ? dropColumns : usedColumns) : columns) * step - scElement.look.spacing
    readonly property real contentH: (flow ? (menu.appDragging ? dropRows : usedRows) : gridRowsShown) * step - scElement.look.spacing
    readonly property real gridWidth: Math.max(availW, menu.appDragging ? dropColumns * step - scElement.look.spacing : contentW)
    readonly property real gridHeight: Math.max(availH, menu.appDragging ? dropRows * step - scElement.look.spacing : contentH)
    // Free space around the content (tiles or cells)
    readonly property real alignX: Math.max(0, availW - contentW) * scElement.look.alignX
    readonly property real alignY: Math.max(0, availH - contentH) * scElement.look.alignY
    onColumnsChanged: menu.flowColumns[elementId] = columns
    onFitRowsChanged: menu.tileFitRows[elementId] = fitRows
    Component.onCompleted: {
        menu.flowColumns[elementId] = columns;
        menu.tileFitRows[elementId] = fitRows;
    }
    // Stored tiles (stable while dragging) and the preview
    // positions while an app hovers over this element
    readonly property var placed: {
        menu.shortcutsData;
        return menu.packFor(elementId, info.tiles.filter(t => !!menu.tileObject(elementId, t.app)), columns);
    }
    readonly property var preview: {
        menu.dragHover;
        return menu.previewPositions(elementId);
    }
    readonly property string dragKey: menu.appDragging ? menu.appKey(menu.dragApp) : ""
    // Incoming app (not in here yet): shown as a ghost tile
    readonly property var ghost: preview && dragKey && !placed.some(p => p.tile.app === dragKey) ? preview[dragKey] : null
    readonly property var shown: preview ? Object.keys(preview).map(k => preview[k]) : placed
    readonly property real step: scElement.look.unit + scElement.look.spacing
    // Contrast to the element background (light → black, dark → white)
    readonly property color cellContrast: {
        const bg = scElement.hull?.color ?? Theme.surface;
        const c = bg.a > 0 ? bg : Theme.surface;
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b > 0.5 ? "black" : "white";
    }
    // Size of tiles + title (the slot draws its background this big)
    // Real numbers: spacers in button elements shift by fractions of a cell
    readonly property real usedColumns: shown.length ? shown.reduce((m, t) => Math.max(m, t.col + t.w), 1) : Math.min(4, columns)
    readonly property real usedRows: shown.length ? shown.reduce((m, t) => Math.max(m, t.row + t.h), 1) : 1
    // While dragging the drop area (all columns, one more row),
    // so background and frame cover the drop cells
    readonly property real contentFitWidth: gridWidth + bandW
    readonly property real contentFitHeight: gridHeight + bandH
    // Element frame (background) around the content: padding and radius
    readonly property real hullPad: scElement.hull?.padding ?? 0
    readonly property real hullRadius: scElement.hull?.radius ?? Theme.cornerRadius

    // Drop cells: exactly fill the area inside the frame, 2 px
    // apart; corner cells rounded like the frame (concentric)
    readonly property real cellGap: 2
    readonly property real cellW: (dropWidth - (dropColumns - 1) * cellGap) / dropColumns
    readonly property real cellH: (dropRows * step - scElement.look.spacing - (dropRows - 1) * cellGap) / dropRows
    readonly property real cornerRadius: Math.max(2, hullRadius - hullPad)
    function cellRect(c, r, w, h) {
        // Corners at the frame only (not where the title band is)
        const top = r === 0 && bandH === 0 || r === 0 && side !== "top";
        const bottom = r + h >= dropRows && !(bandH > 0 && side === "bottom");
        const left = c === 0 && !(bandW > 0 && side === "left");
        const right = c + w >= dropColumns && !(bandW > 0 && side === "right");
        return {
            "x": c * (cellW + cellGap), "y": r * (cellH + cellGap),
            "w": w * cellW + (w - 1) * cellGap, "h": h * cellH + (h - 1) * cellGap,
            "tl": top && left ? cornerRadius : 2, "tr": top && right ? cornerRadius : 2,
            "bl": bottom && left ? cornerRadius : 2, "br": bottom && right ? cornerRadius : 2
        };
    }

    // While dragging: all columns and one row more than used,
    // so an app can go next to or below the tiles (drawn past
    // the element, the slot does not clip then)
    // Row: one row more than used; grid: exactly the rows shown
    // (the element has a fixed size, more room by resizing it)
    readonly property int dropRows: flow ? Math.ceil(usedRows - 1e-6) + 1 : gridRowsShown
    readonly property int dropColumns: columns
    readonly property real dropWidth: dropColumns * step - scElement.look.spacing
    readonly property real dropHeight: bandH + dropRows * step - scElement.look.spacing

    function cellAt(x, y) {
        const p = mapToItem(tileArea, x, y);
        return { "col": Math.max(0, Math.min(dropColumns - 1, Math.floor(p.x / step))), "row": Math.max(0, Math.min(dropRows - 1, Math.floor(p.y / step))) };
    }

    // Drop an app on the inner cell under the mouse; while
    // hovering the tiles show where everything will be
    DropArea {
        id: scDrop
        width: menu.appDragging ? scElement.contentFitWidth : parent.width
        height: menu.appDragging ? scElement.contentFitHeight : parent.height
        keys: ["custommenu-app"]
        function hover(x, y) {
            const c = scElement.cellAt(x, y);
            const h = menu.dragHover;
            if (!h || h.elementId !== scElement.elementId || h.col !== c.col || h.row !== c.row)
                menu.dragHover = { "elementId": scElement.elementId, "col": c.col, "row": c.row };
        }
        onEntered: drag => hover(drag.x, drag.y)
        onPositionChanged: drag => hover(drag.x, drag.y)
        onExited: if (menu.dragHover?.elementId === scElement.elementId) menu.dragHover = null
        onDropped: drop => {
            const c = scElement.cellAt(drop.x, drop.y);
            menu.dropOnShortcuts(scElement.elementId, c.col, c.row);
        }
    }
    // Drop frame: exactly on the element background (same size,
    // same rounding), drawn above everything in the element
    Rectangle {
        x: -scElement.hullPad
        y: -scElement.hullPad
        width: scElement.contentFitWidth + scElement.hullPad * 2
        height: scElement.contentFitHeight + scElement.hullPad * 2
        visible: scDrop.containsDrag
        z: 10
        radius: Math.min(scElement.hullRadius, width / 2, height / 2)
        color: "transparent"
        border.width: 2
        border.color: Theme.primary
    }

    // In the middle of its band (gap to the frame and to the
    // tiles), aligned along the side
    StyledText {
        id: scTitle
        readonly property bool across: scElement.side === "left" || scElement.side === "right"
        readonly property real along: across ? scElement.contentFitHeight : scElement.contentFitWidth
        readonly property real len: across ? height : width
        readonly property real pos: scElement.look.titleAlign === "center" ? (along - len) / 2 : scElement.look.titleAlign === "end" ? along - len - scElement.gap : scElement.gap
        visible: scElement.hasTitle
        width: across ? implicitWidth : Math.min(implicitWidth, Math.max(0, scElement.contentFitWidth - scElement.gap * 2))
        x: across ? (scElement.side === "left" ? scElement.gap : scElement.gridWidth + scElement.gap) : pos
        y: across ? pos : (scElement.side === "top" ? scElement.gap : scElement.gridHeight + scElement.gap)
        text: scElement.info.title
        elide: Text.ElideRight
        font.pixelSize: scElement.look.titleSize
        font.weight: Theme.fontWeightMedium
        color: scElement.look.titleColor
    }

    StyledText {
        visible: scElement.info.tiles.length === 0 && !scElement.managing
        anchors.fill: parent
        wrapMode: Text.WordWrap
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        text: I18n.trFor("customMenu", "Drag apps here")
        font.pixelSize: scElement.look.textSize
        color: Theme.withAlpha(scElement.look.textColor, 0.6)
    }

    DFlickable {
        id: scFlick
        fadeEdges: false
        // Scroll bar in the middle between the tiles and the edge
        QQC.ScrollBar.vertical: GutterScrollbar {
            host: scFlick.parent
            flick: scFlick
            contentRight: scFlick.x + tileArea.x + scElement.contentW
            edgeRight: scElement.width + scElement.hullPad
        }
        EdgeFade {
            menu: scElement.menu
            parent: scFlick.parent
            target: scFlick
        }
        visible: !scElement.managing
        anchors.fill: parent
        anchors.leftMargin: scElement.gridX
        anchors.topMargin: scElement.gridY
        clip: !menu.appDragging
        contentWidth: width
        contentHeight: tileArea.y + tileArea.height
        interactive: !menu.layoutEditing

        Item {
            id: tileArea
            // Placed in the element by the alignment settings
            x: Math.round(scElement.alignX)
            y: Math.round(scElement.alignY)
            width: Math.max(0, parent.width - scElement.alignX)
            height: Math.max(scElement.flow ? 0 : scElement.contentH, scElement.shown.reduce((m, t) => Math.max(m, (t.row + t.h) * scElement.step - scElement.look.spacing), 0))

            // While an app is dragged: the inner cells
            Repeater {
                model: menu.appDragging ? scElement.dropColumns * scElement.dropRows : 0
                // Filled in a colour contrasting with the element, 90 %
                // transparent
                Rectangle {
                    required property int index
                    readonly property var r: scElement.cellRect(index % scElement.dropColumns, Math.floor(index / scElement.dropColumns), 1, 1)
                    x: r.x
                    y: r.y
                    width: r.w
                    height: r.h
                    topLeftRadius: r.tl
                    topRightRadius: r.tr
                    bottomLeftRadius: r.bl
                    bottomRightRadius: r.br
                    color: Theme.withAlpha(scElement.cellContrast, 0.1)
                }
            }

            // Incoming app while hovering: where it will land
            // Same geometry as the drop cells it covers (2 px apart,
            // 2 px rounding), in the colour of the drop frame
            Rectangle {
                readonly property var r: scElement.cellRect(scElement.ghost?.col ?? 0, scElement.ghost?.row ?? 0, scElement.ghost?.w ?? 1, scElement.ghost?.h ?? 1)
                visible: scElement.ghost !== null
                x: r.x
                y: r.y
                width: r.w
                height: r.h
                topLeftRadius: r.tl
                topRightRadius: r.tr
                bottomLeftRadius: r.bl
                bottomRightRadius: r.br
                color: Theme.withAlpha(Theme.primary, 0.45)
                AppIconRenderer {
                    anchors.centerIn: parent
                    opacity: 0.7
                    width: Math.round(Math.min(parent.width, parent.height) * 0.65)
                    height: width
                    iconSize: width
                    iconValue: menu.dragApp?.icon || ""
                    fallbackText: (menu.dragApp?.name || "?").charAt(0).toUpperCase()
                }
            }

            Repeater {
                model: scElement.placed

                StyledRect {
                    id: scTile
                    required property var modelData
                    readonly property string jumpSection: "tlTiles"
                    PieceBlur {
                        menu: scElement.menu
                        radius: scTile.radius
                        viewport: scFlick
                    }
                    readonly property var app: {
                        menu.shortcutsData;
                        return menu.tileObject(scElement.elementId, modelData.tile.app);
                    }
                    readonly property bool isButton: String(modelData.tile.app).startsWith("act:")
                    // Spacer: takes its cells in the flow, shows nothing
                    readonly property bool isSpacer: !!modelData.spacer
                    visible: !isSpacer
                    // Buttons with confirmation: hold like in DMS' power menu
                    readonly property bool needsHold: isButton && (menu.actionDef(scElement.elementId, modelData.tile.app)?.confirm ?? false)
                    property real holdProgress: 0
                    // Where it is shown: preview position while dragging
                    readonly property var pos: scElement.preview?.[modelData.tile.app] ?? modelData
                    readonly property bool small: pos.w === 1 || pos.h === 1
                    // The dragged tile: faded while it is away from here
                    opacity: scElement.dragKey === modelData.tile.app && !scElement.preview ? 0.35 : 1
                    x: pos.col * scElement.step
                    y: pos.row * scElement.step
                    width: pos.w * scElement.look.unit + (pos.w - 1) * scElement.look.spacing
                    height: pos.h * scElement.look.unit + (pos.h - 1) * scElement.look.spacing
                    Behavior on x { NumberAnimation { duration: 120 } }
                    Behavior on y { NumberAnimation { duration: 120 } }
                    radius: Math.min(scElement.look.tileRadius, width / 2, height / 2)
                    color: scElement.look.tileColor

                    AppTile {
                        textJumpSection: "tlText"
                        anchors.fill: parent
                        app: scTile.app
                        showIcon: true
                        showName: scElement.look.showLabels && !scTile.small
                        iconPosition: "top"
                        textAlign: "center"
                        // Icon fills the tile up to the edge distance (setting,
                        // per tile size); AppTile fits it next to a name
                        padding: scTile.small ? scElement.look.iconPadSmall : scElement.look.iconPadLarge
                        iconSize: Math.max(8, Math.min(scTile.width, scTile.height) - padding * 2)
                        textSize: scElement.look.textSize
                        textColor: scElement.look.textColor
                        textWeight: scElement.look.textWeight
                        fallbackColor: menu.fallbackIconColor
                        fallbackLetterColor: menu.fallbackLetterColor
                        iconColor: menu.appIconColors[scTile.modelData.tile.app] || scElement.look.iconColor
                        cornerRadius: scTile.radius
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: scArea.containsMouse ? Theme.withAlpha(Theme.onSurface, Theme.stateLayerHover) : "transparent"
                    }

                    Rectangle {
                        visible: scElement.look.tileBorderWidth > 0
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: scElement.look.tileBorderWidth
                        border.color: scElement.look.tileBorderColor
                    }

                    TileTooltip {
                        title: menu.tooltipTitle(scTile.app, scElement.look.tooltips)
                        description: menu.tooltipDescription(scTile.app)
                        target: scTile
                        hoverArea: scArea
                    }

                    MouseArea {
                        id: scArea
                        anchors.fill: parent
                        enabled: !menu.layoutEditing
                        hoverEnabled: true
                        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        // Drag & drop like the apps element; from here the
                        // app is moved (other element, canvas) or reordered
                        preventStealing: true
                        property point pressAt: Qt.point(0, 0)
                        property bool dragging: false
                        property bool wasDrag: false
                        onPressed: mouse => {
                            pressAt = Qt.point(mouse.x, mouse.y);
                            wasDrag = false;
                            if (scTile.needsHold && mouse.button === Qt.LeftButton)
                                holdAnim.restart();
                        }
                        onPositionChanged: mouse => {
                            if (!(mouse.buttons & Qt.LeftButton))
                                return;
                            if (!dragging && Math.hypot(mouse.x - pressAt.x, mouse.y - pressAt.y) > 8) {
                                holdAnim.stop();
                                scTile.holdProgress = 0;
                                dragging = true;
                                menu.startAppDrag(scTile.app, scArea, mouse.x, mouse.y, { "elementId": scElement.elementId });
                            } else if (dragging) {
                                menu.moveAppDrag(scArea, mouse.x, mouse.y);
                            }
                        }
                        onReleased: {
                            // Released before the hold completed: nothing happens
                            if (holdAnim.running) {
                                holdAnim.stop();
                                scTile.holdProgress = 0;
                                wasDrag = true;
                            }
                            if (!dragging)
                                return;
                            dragging = false;
                            wasDrag = true;
                            menu.endAppDrag();
                        }
                        onCanceled: {
                            dragging = false;
                            menu.appDragging = false;
                            menu.dragApp = null;
                            menu.dragFrom = null;
                        }
                        onClicked: mouse => {
                            if (wasDrag) {
                                wasDrag = false;
                                return;
                            }
                            if (mouse.button === Qt.RightButton) {
                                menu.menuContext = { "type": "shortcut", "elementId": scElement.elementId };
                                menu.appContextMenu.showFor(scTile, scTile.app, menu.activePopout?.screen ?? menu.parentScreen);
                                return;
                            }
                            // Buttons: run (with confirmation the hold did it)
                            if (scTile.isButton) {
                                if (!scTile.needsHold)
                                    menu.runAction(scElement.elementId, scTile.modelData.tile.app);
                                return;
                            }
                            // Close first, see the apps element
                            const app = scTile.app;
                            menu.closePopout();
                            menu.launchApp(app);
                        }

                    // Hold to confirm: fills the tile, runs at the end
                    NumberAnimation {
                        id: holdAnim
                        target: scTile
                        property: "holdProgress"
                        from: 0
                        to: 1
                        duration: Math.max(200, SettingsData.powerActionHoldDuration * 1000)
                        onFinished: {
                            scTile.holdProgress = 0;
                            menu.runAction(scElement.elementId, scTile.modelData.tile.app);
                        }
                    }
                    // Hold progress, left to right: the whole tile shape (same
                    // rounding) filled up to the progress with a hard edge, so
                    // it never leaves the button's shape
                    Rectangle {
                        id: holdFill
                        visible: scTile.holdProgress > 0
                        anchors.fill: parent
                        // The tile's rounding (the parent here is its mouse area)
                        radius: scTile.radius
                        readonly property color fill: Theme.withAlpha(Theme.error, 0.35)
                        readonly property real edge: Math.max(0.0001, Math.min(0.9999, scTile.holdProgress))
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: holdFill.fill }
                            GradientStop { position: holdFill.edge; color: holdFill.fill }
                            GradientStop { position: holdFill.edge + 0.0001; color: "transparent" }
                            GradientStop { position: 1; color: "transparent" }
                        }
                    }
                    }
                }
            }
        }
    }

    // Manage view (element pen): the title
    Column {
        visible: scElement.managing
        anchors.fill: parent
        anchors.topMargin: 28
        spacing: Theme.spacingS

        DTextField {
            width: parent.width
            height: 36
            text: scElement.info.title
            placeholderText: I18n.trFor("customMenu", "Title (optional)")
            onEditingFinished: menu.scSetTitle(scElement.elementId, text)
        }

        StyledText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: I18n.trFor("customMenu", "Right-click an app to change its tile size; for more groups, add more tile elements.")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.withAlpha(menu.appTextColor, 0.6)
        }
    }
}
