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

Item {
    id: element
    // The menu widget (CustomMenuWidget): its settings and functions
    required property Item menu

    // Without a search element: show what is typed, × clears it
    StyledRect {
        visible: menu.searchShowQueryChip && !menu.hasSearchElement && menu.searchQuery !== ""
        z: 5
        anchors.top: parent.top
        anchors.right: parent.right
        width: queryRow.implicitWidth + Theme.spacingM * 2
        height: Math.max(queryRow.implicitHeight, 28) + Theme.spacingXS * 2
        radius: height / 2
        color: Theme.secondaryContainer

        Row {
            id: queryRow
            anchors.centerIn: parent
            spacing: Theme.spacingXS

            DIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 16
                color: Theme.onSecondaryContainer
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: menu.searchQuery
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.onSecondaryContainer
            }

            DActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconName: "close"
                iconSize: 14
                iconColor: Theme.onSecondaryContainer
                tooltipText: I18n.trFor("customMenu", "Clear search")
                onClicked: menu.searchQuery = ""
            }
        }
    }

    // Geometry of the tile rows (same for all sections)
    Item {
        id: appGrid
        width: parent.width
        height: parent.height
        readonly property real areaWidth: width
        onHeightChanged: menu.appsAreaHeight = height
        // Report the full row width, so the settings can keep the
        // look when "Single column" is turned off (see there).
        onAreaWidthChanged: {
            if (areaWidth > 0)
                if ((PluginService.globalVars[menu.pluginId]?.editInstance ?? "") === menu.instanceId) menu.publishVar("rowWidth", Math.floor(areaWidth));
            menu.appsAreaWidth = areaWidth;
        }
        Component.onCompleted: {
            if (areaWidth > 0)
                if ((PluginService.globalVars[menu.pluginId]?.editInstance ?? "") === menu.instanceId) menu.publishVar("rowWidth", Math.floor(areaWidth));
            menu.appsAreaWidth = areaWidth;
            menu.appsAreaHeight = height;
            menu.appColumns = columns;
            menu.appPageRows = pageRows;
        }
        // Never wider than the available row (the stored chip width
        // can be larger after the menu got narrower or the edge
        // distance grew)
        readonly property real tileWidth: menu.appFullWidth ? areaWidth : Math.min(menu.chipWidth, areaWidth)
        readonly property real tileHeight: menu.chipHeight
        readonly property int columns: menu.appFullWidth ? 1 : Math.max(1, Math.floor((areaWidth + menu.appSpacing) / (tileWidth + menu.appSpacing)))
        onColumnsChanged: menu.appColumns = columns
        readonly property int pageRows: Math.max(1, Math.floor(height / (tileHeight + menu.appRowSpacing)))
        onPageRowsChanged: menu.appPageRows = pageRows
        // Fewer apps than a row (in every section): only the columns
        // they use count (so they are centred, not the whole row)
        readonly property int maxApps: menu.appSections.reduce((m, sec) => Math.max(m, sec.apps?.length ?? 0), 0)
        readonly property int usedColumns: menu.appAlignAuto === "both" ? Math.max(1, Math.min(columns, maxApps)) : columns
        readonly property real usedWidth: usedColumns * tileWidth + (usedColumns - 1) * menu.appSpacing

        // Report the left inset, so a categories element of the
        // same width can align its chips with the first tile
        // Automatic alignment: does all content fit without scrolling?
        readonly property bool fits: sectionColumn.implicitHeight <= height + 0.5
        readonly property real alignX: menu.appAlignAuto === "both" ? 0.5 : menu.appAlignX
        readonly property real alignY: menu.appAlignAuto !== "off" ? (fits ? 0.5 : 0) : menu.appAlignY
        // Whole pixels (crisp 1 px borders)
        readonly property real inset: Math.round(Math.max(0, (areaWidth - usedWidth) * alignX))
        onInsetChanged: menu.appRowInset = inset

        DFlickable {
            id: appFlick
            fadeEdges: false
            // Scroll bar in the middle between the apps and the
            // element's edge (its background, incl. padding)
            QQC.ScrollBar.vertical: GutterScrollbar {
                host: appFlick.parent
                flick: appFlick
                contentRight: appFlick.x + appFlick.width
                edgeRight: appGrid.width + (menu.areaStyleFor("apps")?.padding ?? 0)
            }
            EdgeFade {
                menu: element.menu
                parent: appFlick.parent
                target: appFlick
            }
            x: appGrid.inset
            // Less content than room: placed by the vertical alignment
            y: Math.round((parent.height - height) * appGrid.alignY)
            width: appGrid.usedWidth
            height: Math.min(parent.height, contentHeight)
            clip: true
            contentWidth: width
            contentHeight: sectionColumn.implicitHeight
            // Edit mode: the element itself is dragged
            interactive: !menu.layoutEditing

            Column {
                id: sectionColumn
                width: appFlick.width
                // Between sections (search results); the flat list has one
                spacing: menu.searching ? menu.secGap : menu.appRowSpacing

                Repeater {
                    model: menu.appSections

                    // A section: heading + tiles; over it the drop area (sub-
                    // categories) outside the Column's layout
                    Item {
                        id: section
                        required property var modelData
                        required property int index
                        // Sub-category (not the top part, not search results)
                        readonly property bool isSub: !menu.searching && !!modelData.sub
                        // Look of the sub-category headings (also "Other apps")
                        readonly property bool subLook: isSub || (!menu.searching && !!modelData.rest)
                        readonly property bool isSubArea: !menu.searching && modelData.sub !== undefined && modelData.id !== "__flat"
                        width: sectionColumn.width
                        height: sectionBody.implicitHeight

                        // Drop an app here: into this sub-category (top part: out
                        // of all sub-categories)
                        DropArea {
                            id: subDrop
                            enabled: section.isSubArea
                            anchors.fill: parent
                            keys: ["custommenu-app"]
                            onDropped: menu.moveAppToSubcategory(menu.currentCategory, section.modelData.sub, menu.appKey(menu.dragApp))
                        }
                        Rectangle {
                            visible: subDrop.containsDrag
                            z: -1
                            x: -Theme.spacingXS
                            y: sectionBody.topPadding - Theme.spacingXS
                            width: section.width + Theme.spacingXS * 2
                            height: section.height - sectionBody.topPadding + Theme.spacingXS * 2
                            radius: Theme.cornerRadius
                            color: Theme.withAlpha(Theme.primary, 0.08)
                            border.width: 1
                            border.color: Theme.primary
                        }

                    Column {
                        id: sectionBody
                        width: parent.width
                        spacing: section.subLook ? menu.subTitleGap : menu.secTitleGap
                        // Space before a sub-category (the outer Column's spacing
                        // is the result sections' one)
                        topPadding: section.subLook && section.index > 0 ? Math.max(0, menu.subGap - sectionColumn.spacing) : 0

                        // Header (groups and "More apps"; none for the flat list)
                        Item {
                            readonly property string jumpSection: section.subLook ? "catSub" : "searchSections"
                            visible: section.modelData.name !== ""
                            width: parent.width
                            height: nameText.implicitHeight + Theme.spacingXS

                            StyledText {
                                id: nameText
                                anchors.verticalCenter: parent.verticalCenter
                                text: section.modelData.name
                                font.pixelSize: section.subLook ? menu.subTitleSize : menu.secTitleSize
                                font.weight: section.subLook ? menu.subTitleWeight : menu.secTitleWeight
                                color: section.subLook ? menu.subTitleColor : menu.secTitleColor
                            }

                            Rectangle {
                                visible: section.subLook ? menu.subLineShow : menu.secLineShow
                                anchors.left: nameText.right
                                anchors.leftMargin: Theme.spacingM
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 1
                                color: section.subLook ? menu.subLineColor : menu.secLineColor
                            }
                        }

                        // Empty sub-category (or empty top part while dragging):
                        // room to drop apps into
                        StyledText {
                            visible: section.modelData.apps.length === 0 && (section.isSub || (section.isSubArea && menu.appDragging))
                            width: section.width
                            height: menu.chipHeight / 2
                            verticalAlignment: Text.AlignVCenter
                            text: section.isSub ? I18n.trFor("customMenu", "Drag apps here") : I18n.trFor("customMenu", "Drop here to remove from subcategories")
                            font.pixelSize: menu.textSize
                            color: Theme.withAlpha(menu.appTextColor, 0.5)
                        }

                        Grid {
                            // A last row that is not full stays left
                            x: 0
                            columns: appGrid.usedColumns
                            columnSpacing: menu.appSpacing
                            rowSpacing: menu.appRowSpacing

                            Repeater {
                                model: section.modelData.apps

                                Item {
                                    id: tile
                                    required property var modelData
                                    required property int index
                                    width: appGrid.tileWidth
                                    height: appGrid.tileHeight
                                    // Keyboard selection: framed like a focus ring, kept in view
                                    readonly property bool kbSelected: menu.navShown && (menu.navOffsets[section.index] ?? 0) + index === menu.navIndex
                                    onKbSelectedChanged: if (kbSelected) {
                                        menu.navItem = chip;
                                        // One tick later the tile may be gone (results changed)
                                        const column = sectionColumn, flick = appFlick;
                                        Qt.callLater(() => {
                                            if (!column || !flick || tile.kbSelected !== true)
                                                return;
                                            const y = tile.mapToItem(column, 0, 0).y;
                                            if (y < flick.contentY)
                                                flick.contentY = Math.max(0, y - Theme.spacingS);
                                            else if (y + tile.height > flick.contentY + flick.height)
                                                flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), y + tile.height - flick.height + Theme.spacingS);
                                        });
                                    }
                                    Component.onCompleted: if (kbSelected) menu.navItem = chip

                                    // Chip (optional), content per layout inside, hover layer on top
                                    StyledRect {
                                        id: chip
                                        readonly property string jumpSection: "appChip"
                                        anchors.fill: parent
                                        // Level 4 blur (only with a visible chip)
                                        PieceBlur {
                                            menu: element.menu
                                            active: menu.chipEnabled
                                            radius: chip.radius
                                            viewport: appFlick
                                        }
                                        radius: menu.chipRadius
                                        clip: true
                                        color: menu.chipEnabled ? menu.chipColor : "transparent"
                                        // Border: own layer on top (below), otherwise the text
                                        // background would cover it

                                        AppTile {
                                            iconJumpSection: "appIcon"
                                            textJumpSection: "appText"
                                            anchors.fill: parent
                                            app: tile.modelData
                                            showIcon: menu.appShowIcon
                                            showName: menu.appShowLabels
                                            // Files and folders: their place (search settings)
                                            showDescription: menu.appShowDescription || (!!tile.modelData.isFileResult && menu.searchPathShow)
                                            iconPosition: menu.appIconPosition
                                            textAlign: menu.appTextAlign
                                            iconSize: menu.appIconSize
                                            textSize: menu.textSize
                                            textWeight: menu.appTextWeight
                                            textColor: menu.appTextColor
                                            textBackground: menu.appTextBackground
                                            textBackgroundColor: menu.catSurface("appTextBg", Theme.foregroundColor(Theme.chipSurfaceNested))
                                            fallbackColor: menu.fallbackIconColor
                                            fallbackLetterColor: menu.fallbackLetterColor
                                            iconColor: menu.appIconColors[menu.appKey(tile.modelData)] || ""
                                            cornerRadius: chip.radius
                                            iconOffset: menu.cfg.appIconOffset ?? Defaults.appIconOffset
                                            iconTextGap: menu.cfg.appIconTextGap ?? Defaults.appIconTextGap
                                            descriptionGap: menu.cfg.appDescriptionGap ?? Defaults.appDescriptionGap
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: parent.radius
                                            color: tileArea.containsMouse || tile.kbSelected ? Theme.withAlpha(Theme.onSurface, Theme.stateLayerHover) : "transparent"
                                            border.width: tile.kbSelected ? 2 : 0
                                            border.color: Theme.primary
                                        }

                                        Rectangle {
                                            visible: menu.chipEnabled && menu.chipBorderWidth > 0
                                            anchors.fill: parent
                                            radius: parent.radius
                                            color: "transparent"
                                            border.width: menu.chipBorderWidth
                                            border.color: menu.catColor("chipBorder", Theme.outlineVariant, "allPieceBorder")
                                        }

                                        TileTooltip {
                                            title: menu.tooltipTitle(tile.modelData, menu.appTooltips)
                                            description: menu.tooltipDescription(tile.modelData)
                                            target: tile
                                            hoverArea: tileArea
                                        }

                                        MouseArea {
                                            id: tileArea
                                            anchors.fill: parent
                                            // Edit mode: the element is dragged, not the apps
                                            enabled: !menu.layoutEditing
                                            hoverEnabled: true
                                            cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            // Drag & drop: past 8 px of movement the app is dragged
                                            // instead of launched
                                            preventStealing: true
                                            property point pressAt: Qt.point(0, 0)
                                            property bool dragging: false
                                            property bool wasDrag: false
                                            onPressed: mouse => {
                                                pressAt = Qt.point(mouse.x, mouse.y);
                                                wasDrag = false;
                                            }
                                            onPositionChanged: mouse => {
                                                if (!(mouse.buttons & Qt.LeftButton))
                                                    return;
                                                // Launcher results (files, plugins) are not dragged
                                                if (tile.modelData.launcherItem)
                                                    return;
                                                if (!dragging && Math.hypot(mouse.x - pressAt.x, mouse.y - pressAt.y) > 8) {
                                                    dragging = true;
                                                    menu.startAppDrag(tile.modelData, tileArea, mouse.x, mouse.y);
                                                } else if (dragging) {
                                                    menu.moveAppDrag(tileArea, mouse.x, mouse.y);
                                                }
                                            }
                                            onReleased: {
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
                                            }
                                            onClicked: mouse => {
                                                if (wasDrag) {
                                                    wasDrag = false;
                                                    return;
                                                }
                                                if (mouse.button === Qt.RightButton) {
                                                    // App menu only for apps
                                                    if (tile.modelData.launcherItem)
                                                        return;
                                                    menu.menuContext = { "type": "apps" };
                                                    menu.appContextMenu.showFor(chip, tile.modelData, menu.activePopout?.screen ?? menu.parentScreen);
                                                    return;
                                                }
                                                // Close first: launching updates the usage ranking,
                                                // the list is rebuilt and this delegate destroyed,
                                                // so nothing after the launch would run
                                                menu.activateTile(tile.modelData);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    }
                }
            }
        }
    }
}
