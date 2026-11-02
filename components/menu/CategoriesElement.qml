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
    id: catElement
    // The menu widget (CustomMenuWidget): its settings and functions
    required property Item menu

    onWidthChanged: menu.catAreaWidth = width
    onHeightChanged: menu.catAreaHeight = height
    Component.onCompleted: {
        menu.catAreaWidth = width;
        menu.catAreaHeight = height;
    }
    // Aligned with the first app tile when spanning the
    // same columns as the apps element
    readonly property var appsSlot: menu.layoutItems.find(i => i.id === "apps")
    readonly property real inset: appsSlot && parent?.slotData && appsSlot.col === parent.slotData.col && appsSlot.w === parent.slotData.cols ? menu.appRowInset : 0

    // Only complete chip rows are visible; further rows are
    // reached with the mouse wheel, one row per step.
    readonly property real rowStep: menu.catChipHeight + menu.catChipRowSpacing
    readonly property int visibleRows: Math.max(1, Math.floor((height + menu.catChipRowSpacing) / rowStep))

    Flickable {
        id: catFlick
        enabled: !menu.layoutEditing
        x: catElement.inset
        width: catElement.width - catElement.inset * 2
        // Chips: whole rows; all fitting: as tall as they are,
        // placed by the vertical alignment (setting)
        readonly property real rowsHeight: Math.min(catElement.height, catElement.visibleRows * catElement.rowStep - menu.catChipRowSpacing)
        readonly property bool fitsAll: catSwitcher.implicitHeight <= rowsHeight + 0.5
        height: menu.categoryStyle === "dropdown" ? catElement.height : fitsAll ? catSwitcher.implicitHeight : rowsHeight
        y: menu.categoryStyle === "dropdown" || !fitsAll ? 0 : Math.max(0, (catElement.height - height) * menu.alignShare(menu.cfg.catAlignV ?? Defaults.catAlignV))
        contentWidth: width
        contentHeight: catSwitcher.implicitHeight
        clip: true
        interactive: false
        boundsBehavior: Flickable.StopAtBounds

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const max = Math.max(0, catFlick.contentHeight - catFlick.height);
                const dir = event.angleDelta.y < 0 ? 1 : -1;
                const next = Math.round(catFlick.contentY / catElement.rowStep) + dir;
                catFlick.contentY = Math.max(0, Math.min(max, next * catElement.rowStep));
            }
        }

    CategorySwitcher {
        id: catSwitcher
        chipJumpSection: "catChip"
        width: catFlick.width
        height: implicitHeight
        // Narrow element → chips stacked vertically
        vertical: catElement.width < menu.catChipWidth * 2 + menu.catChipSpacing
        chipHeight: menu.catChipHeight
        chipRadius: menu.catChipRadius
        chipTextAlign: menu.catTextAlign
        // Never wider than the area (stored width may be from a
        // wider element, or the padding grew)
        chipWidth: Math.min(menu.catChipWidth, catFlick.width)
        chipSpacing: menu.catChipSpacing
        chipRowSpacing: menu.catChipRowSpacing
        chipBorderWidth: menu.catChipBorderWidth
        chipBorderColor: menu.catChipBorderColor
        chipBackground: menu.catChipBgColor
        chipSelected: menu.catChipSelColor
        chipText: menu.catChipTextColor
        chipSelectedText: menu.catChipSelTextColor
        chipSelectedBorder: menu.catChipSelBorderColor
        chipSelectedTextWeight: menu.catSelTextWeight
        chipHover: menu.catChipHoverColor
        chipHoverBorder: menu.catChipHoverBorderColor
        chipHoverText: menu.catChipHoverTextColor
        chipHoverTextWeight: menu.catHoverTextWeight
        chipTextSize: menu.catTextSize
        chipTextWeight: menu.catTextWeight
        showIcons: menu.cfg.catShowIcons ?? Defaults.catShowIcons
        iconSize: menu.cfg.catIconSize ?? Defaults.catIconSize
        // Own colour for all icons, per category overridable;
        // not tied to the chip text colour
        iconColor: menu.catColor("catIcon", Theme.onSurfaceVariant, "allPieceIcon")
        iconColors: menu.cfg.catIconColors ?? ({})
        iconOverrides: menu.cfg.catIcons ?? ({})
        categories: menu.categories
        currentKey: menu.currentCategory
        style: menu.categoryStyle
        textColor: menu.appTextColor
        onAppDropped: key => menu.dropOnCategory(key)
        // Level 4 blur per chip, cut to the scrolling area
        chipDecoration: Component {
            PieceBlur {
                menu: catElement.menu
                radius: parent?.chipRadius ?? 0
                viewport: catFlick
            }
        }
        // An app (no button) being dragged: show the targets
        dropHint: menu.appDragging && !String(menu.appKey(menu.dragApp)).startsWith("act:")
        onSelected: key => {
            menu.searchQuery = "";
            menu.currentCategory = key;
        }
    }
    }
}
