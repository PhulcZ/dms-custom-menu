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
import "../common"

Item {
    id: element
    // The menu widget (CustomMenuWidget): its settings and functions
    required property Item menu

    // Own icon file in the field (instead of a symbol)
    Component {
        id: searchFileIcon
        FlexIcon {
            icon: menu.searchIconName
            size: Theme.iconSize
        }
    }

    enabled: !menu.layoutEditing
    // Real height (field, scope chips): background and edit frame
    // hug it; the element's grid rows can be a little higher
    readonly property real contentFitHeight: menu.searchHeight + menu.searchScopeExtra
    // Settings open: the icon area of the field (magnifier or
    // own icon) leads to the icon settings
    Item {
        readonly property string jumpSection: "searchIcon"
        visible: menu.searchIconVisible
        x: searchField.x
        y: searchField.y
        z: searchField.z + 1
        width: searchField.leftPadding
        height: searchField.height
    }
    DTextField {
        id: searchField
        readonly property string jumpSection: "searchBackground"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        // Room for the scope chips above or beside it
        anchors.topMargin: menu.searchScopeBelow && menu.searchScopeSide === "top" ? menu.searchScopeHeight + Theme.spacingS : 0
        anchors.leftMargin: menu.searchScopeBelow && menu.searchScopeSide === "left" ? scopeSwitcher.width + Theme.spacingS : 0
        anchors.rightMargin: menu.searchScopeBelow && menu.searchScopeSide === "right" ? scopeSwitcher.width + Theme.spacingS : 0
        height: menu.searchHeight
        // Symbol icon: DMS draws it (incl. colour change on focus);
        // icon file: in the leading slot, own colours
        leftIconName: menu.searchIconVisible && !menu.searchIconIsFile ? menu.searchIconName : ""
        leadingContent: menu.searchIconVisible && menu.searchIconIsFile ? searchFileIcon : null
        // While the settings are open the settings window has the
        // keyboard focus, so the field would show its unfocused
        // look. The open menu always has the field focused: the
        // preview shows that (focused) look throughout.
        readonly property color iconResting: menu.catColor("searchIcon", Theme.onSurfaceVariant, "allPieceIcon")
        // "Highlight with focus" off (setting): focused = resting look.
        // Icon default with focus: the same colour as without.
        readonly property bool highlight: menu.cfg.searchFocusHighlight ?? Defaults.searchFocusHighlight
        readonly property color iconFocused: highlight ? menu.catColor("searchIconFocus", iconResting) : iconResting
        readonly property color borderResting: menu.catColor("searchBorder", Theme.outlineVariant, "allPieceBorder")
        readonly property color borderFocused: highlight ? menu.catColor("searchBorderFocus", Theme.primary) : borderResting
        // Focused: one pixel thicker, like DMS
        readonly property real borderWidthFocused: highlight && menu.searchBorderWidth > 0 ? menu.searchBorderWidth + 1 : menu.searchBorderWidth
        leftIconColor: menu.previewActive ? iconFocused : iconResting
        leftIconFocusedColor: iconFocused
        cornerRadius: menu.searchRadius
        // Default like the other chips: DMS level 4 (nested chip)
        backgroundColor: menu.catSurface("searchBg", Theme.chipSurfaceNested, "allPiece")
        color: menu.catSurface("searchBg", Theme.chipSurfaceNested, "allPiece")
        borderWidth: menu.previewActive ? borderWidthFocused : menu.searchBorderWidth
        focusedBorderWidth: borderWidthFocused
        normalBorderColor: menu.previewActive ? borderFocused : borderResting
        focusedBorderColor: borderFocused
        // Typed text: by default the hint colour, but opaque
        textColor: menu.catColor("searchText", menu.searchHintBaseColor, "allPieceText")
        placeholderColor: menu.searchHintColor
        font.pixelSize: menu.searchTextSize
        font.weight: menu.fontWeight(menu.inherit("searchTextWeight", "allPieceTextWeight", Defaults.searchTextWeight))
        placeholderText: (menu.cfg.searchPlaceholderText ?? "").trim() || I18n.trFor("customMenu", "Search apps")
        showClearButton: true
        // Arrows, Enter & Co. go to the result navigation first
        keyForwardTargets: [navKeys]
        // Room for the scope chip on the right (clear button left of it)
        rightAccessoryWidth: scopeChip.visible ? scopeChip.width + Theme.spacingXS : 0
        text: menu.searchQuery
        onTextChanged: menu.searchQuery = text
        Keys.onReturnPressed: {
            if (menu.searchEnterLaunches && menu.searching && menu.firstResult)
                menu.activateTile(menu.firstResult);
        }
        // Focus on every opening, so typing filters right away.
        // DMS focuses the popout container after opening, so
        // take the focus back shortly afterwards.
        function takeFocus() {
            if (!menu.previewActive)
                focusTimer.restart();
        }
        Timer {
            id: focusTimer
            interval: 80
            onTriggered: searchField.forceActiveFocus()
        }
        Connections {
            target: root
            function onSearchFocusRequestChanged() {
                searchField.takeFocus();
            }
        }
        Component.onCompleted: takeFocus()
    }

    Item {
        id: navKeys
        Keys.onPressed: event => {
            if (menu.handleNavKey(event))
                event.accepted = true;
        }
    }

    // Search scope as chip in the field: shows the current scope,
    // a click opens the list
    Rectangle {
        id: scopeChip
        readonly property string jumpSection: "searchScope"
        visible: menu.searchScopeInField
        anchors.right: searchField.right
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: searchField.verticalCenter
        height: Math.min(searchField.height - Theme.spacingS * 2, Math.round(menu.searchScopeTextSize * 2))
        width: scopeRow.implicitWidth + Theme.spacingM * 2
        radius: Math.min(menu.searchRadius, height / 2)
        color: scopeArea.containsMouse ? Qt.tint(bgColor, Theme.withAlpha(Theme.onSurface, Theme.stateLayerHover)) : bgColor
        readonly property color bgColor: menu.catSurface("searchScopeBg", Theme.secondaryContainer)
        readonly property color textColor: menu.catColor("searchScopeText", Theme.onSecondaryContainer)

        Row {
            id: scopeRow
            anchors.centerIn: parent
            spacing: 2
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: menu.searchScopeLabel
                font.pixelSize: menu.searchScopeTextSize
                color: scopeChip.textColor
            }
            DIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "arrow_drop_down"
                size: Math.round(menu.searchScopeTextSize * 1.4)
                color: scopeChip.textColor
            }
        }
        MouseArea {
            id: scopeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // The list is drawn on the card (above all elements;
            // DMS' context menu window does not get the clicks here)
            onClicked: {
                if (menu.scopeListOpen) {
                    menu.scopeListOpen = false;
                    return;
                }
                const p = scopeChip.mapToItem(menu.canvasCard, 0, scopeChip.height + Theme.spacingXS);
                menu.scopeListPos = Qt.point(p.x, p.y);
                menu.scopeListOpen = true;
            }
        }
    }

    // Level 4 blur behind the search field
    PieceBlur {
        menu: element.menu
        piece: searchField
        radius: menu.searchRadius
    }

    // Search scope: chips outside the field. Above/below: one row
    // (full width shared, or as wide as the chips need, aligned),
    // two per row if they do not fit; beside: one row next to the
    // field, aligned with it vertically
    CategorySwitcher {
        id: scopeSwitcher
        chipJumpSection: "scopeChips"
        visible: menu.searchScopeBelow
        readonly property bool across: menu.searchScopeAcross
        readonly property int count: menu.searchScopes.length
        readonly property real natural: needed * count + chipSpacing * (count - 1)
        readonly property bool fill: across && menu.searchScopeAlign === "fill"
        readonly property bool oneRow: parent.width >= natural
        width: across ? (fill || !oneRow ? parent.width : natural) : Math.min(natural, parent.width * 0.6)
        x: across ? (parent.width - width) * menu.alignShare(menu.searchScopeAlign) : (menu.searchScopeSide === "left" ? 0 : parent.width - width)
        y: across ? (menu.searchScopeSide === "top" ? 0 : menu.searchHeight + Theme.spacingS) : Math.max(0, (menu.searchHeight - height) * menu.alignShare(menu.searchScopeAlign))
        height: implicitHeight
        onImplicitHeightChanged: if (implicitHeight > 0) menu.searchScopeHeight = implicitHeight
        Component.onCompleted: if (implicitHeight > 0) menu.searchScopeHeight = implicitHeight
        style: "chips"
        categories: menu.searchScopes
        currentKey: menu.searchScope
        chipHeight: menu.scopeChipHeight
        chipRadius: menu.scopeChipRadius
        chipTextAlign: "center"
        chipSpacing: menu.scopeChipSpacing
        chipRowSpacing: menu.scopeChipSpacing
        // All in one row if the longest name fits, otherwise as many
        // per row as fit (beside the field always one row)
        readonly property real needed: scopeMetrics.width + Theme.spacingL * 2 + 2
        readonly property int perRow: !across ? count : Math.max(1, Math.min(count, Math.floor((width + chipSpacing) / (needed + chipSpacing))))
        chipWidth: Math.max(1, (width - chipSpacing * (perRow - 1)) / perRow)
        TextMetrics {
            id: scopeMetrics
            font.pixelSize: menu.scopeTextSize
            font.weight: menu.scopeTextWeight
            text: menu.searchScopes.reduce((a, c) => c.text.length > a.length ? c.text : a, "")
        }
        chipBorderWidth: menu.scopeChipBorderWidth
        chipBorderColor: menu.catColor("scopeChipBorder", menu.catChipBorderColor)
        chipBackground: menu.catSurface("scopeChipBg", menu.catChipBgColor)
        chipSelected: menu.catSurface("scopeChipSel", menu.catChipSelColor)
        chipText: menu.catColor("scopeChipText", menu.catChipTextColor)
        chipSelectedText: menu.catColor("scopeChipSelText", menu.catChipSelTextColor)
        chipSelectedBorder: menu.catColor("scopeChipSelBorder", menu.catChipSelBorderColor)
        chipSelectedTextWeight: menu.cfg.scopeChipSelTextWeight ? menu.fontWeight(menu.cfg.scopeChipSelTextWeight) : menu.catSelTextWeight
        chipHover: menu.catSurface("scopeChipHoverBg", menu.catChipHoverColor)
        chipHoverBorder: menu.catColor("scopeChipHoverBorder", menu.catChipHoverBorderColor)
        chipHoverText: menu.catColor("scopeChipHoverText", menu.catChipHoverTextColor)
        chipHoverTextWeight: menu.cfg.scopeChipHoverTextWeight ? menu.fontWeight(menu.cfg.scopeChipHoverTextWeight) : menu.catHoverTextWeight
        chipTextSize: menu.scopeTextSize
        chipTextWeight: menu.scopeTextWeight
        onSelected: key => {
            menu.searchScope = key;
            searchField.forceActiveFocus();
        }
    }
}
