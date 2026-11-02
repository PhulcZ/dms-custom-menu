import QtQuick
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets

// Switcher for the app categories, depending on the "style" setting:
//   chips    – CategoryChips (looks like DFilterChips, but stylable)
//   dropdown – DDropdown (selection list, saves space)
// vertical: on the left instead of on top (chips only).
//
// categories: [{ key, text, icon }]; currentKey: selected key.
Item {
    id: root

    property var categories: []
    property string currentKey: ""
    property string style: "chips"
    property bool vertical: false
    property color textColor: Theme.surfaceText

    // Chip styling (style "chips" only)
    property real chipHeight: Theme.buttonHeightXS
    property real chipWidth: 120
    property real chipSpacing: Theme.spacingS
    property real chipRowSpacing: Theme.spacingS
    property real chipBorderWidth: Theme.outlineWidth
    property real chipRadius: Theme.cornerRadiusS
    property string chipTextAlign: "auto"
    property color chipBorderColor: Theme.outlineVariant
    property color chipBackground: "transparent"
    property color chipSelected: Theme.secondaryContainer
    property color chipText: Theme.onSurfaceVariant
    property color chipSelectedText: Theme.onSecondaryContainer
    // See CategoryChips (selected and hovered chip)
    property color chipSelectedBorder: "transparent"
    property int chipSelectedTextWeight: -1
    property color chipHover: Theme.withAlpha(Theme.onSurface, Theme.stateLayerHover)
    property color chipHoverBorder: chipBorderColor
    property color chipHoverText: chipText
    property int chipHoverTextWeight: -1
    property real chipTextSize: Theme.fontSizeSmall
    property int chipTextWeight: Font.Normal
    property bool showIcons: false
    property real iconSize: Theme.iconSizeSmall
    property color iconColor: Theme.onSurfaceVariant
    property var iconColors: ({})
    property var iconOverrides: ({})

    signal selected(string key)
    // An app was dropped on a chip (drag & drop, chips style only)
    signal appDropped(string key)
    // An app is being dragged (see CategoryChips.dropHint)
    property bool dropHint: false
    // See CategoryChips.chipDecoration
    property Component chipDecoration: null
    // See CategoryChips.chipJumpSection; the dropdown style: the whole switcher
    property string chipJumpSection: ""
    readonly property string jumpSection: effectiveStyle === "dropdown" ? chipJumpSection : ""

    readonly property int currentIndex: Math.max(0, categories.findIndex(c => c.key === currentKey))
    // Only two styles: chips (stylable, also vertical) and dropdown.
    // Older stored styles (tabs, buttons, nav) fall back to chips.
    readonly property string effectiveStyle: style === "dropdown" ? "dropdown" : "chips"
    readonly property bool canBeVertical: effectiveStyle === "chips"
    readonly property bool isVertical: vertical && canBeVertical

    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: loader.item ? loader.item.implicitHeight : 0

    // Chips: the grid as wide as its columns and centred, so what is left
    // of the width goes to both sides equally (a single, not full row sits
    // in the middle too); the dropdown takes the whole width
    Loader {
        id: loader
        width: root.effectiveStyle === "dropdown" ? root.width : Math.min(root.width, item?.implicitWidth ?? 0)
        x: Math.max(0, (root.width - width) / 2)
        sourceComponent: {
            switch (root.effectiveStyle) {
            case "dropdown":
                return dropdownComp;
            default:
                return chipsComp;
            }
        }
    }

    Component {
        id: chipsComp
        CategoryChips {
            availableWidth: root.isVertical ? widestChip : root.width
            vertical: root.isVertical
            columnSpacing: root.chipSpacing
            rowSpacing: root.chipRowSpacing
            categories: root.categories
            currentIndex: root.currentIndex
            chipHeight: root.chipHeight
            chipWidth: root.chipWidth
            chipRadius: root.chipRadius
            textAlign: root.chipTextAlign
            borderWidth: root.chipBorderWidth
            borderColor: root.chipBorderColor
            backgroundColor: root.chipBackground
            selectedColor: root.chipSelected
            textColor: root.chipText
            selectedTextColor: root.chipSelectedText
            selectedBorderColor: root.chipSelectedBorder
            selectedTextWeight: root.chipSelectedTextWeight
            hoverColor: root.chipHover
            hoverBorderColor: root.chipHoverBorder
            hoverTextColor: root.chipHoverText
            hoverTextWeight: root.chipHoverTextWeight
            chipJumpSection: root.chipJumpSection
            textSize: root.chipTextSize
            textWeight: root.chipTextWeight
            showIcons: root.showIcons
            iconSize: root.iconSize
            iconColor: root.iconColor
            iconColors: root.iconColors
            iconOverrides: root.iconOverrides
            onSelected: index => root.selected(root.categories[index].key)
            onAppDropped: index => root.appDropped(root.categories[index].key)
            dropHint: root.dropHint
            chipDecoration: root.chipDecoration
        }
    }

    Component {
        id: dropdownComp
        DDropdown {
            width: Math.min(root.width, 320)
            options: root.categories.map(c => c.text)
            currentValue: root.categories[root.currentIndex]?.text ?? ""
            onValueChanged: value => {
                const c = root.categories.find(x => x.text === value);
                if (c)
                    root.selected(c.key);
            }
        }
    }
}
