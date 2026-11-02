import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets
import "../../Defaults.js" as Defaults

// Own background of an element (search, categories, apps)
Section {
    id: area
    property string prefix: ""
    property string defaultLabel: I18n.trFor("customMenu", "Default (DMS level 3 chip)")
    property color defaultColor: Theme.chipSurface
    title: I18n.trFor("customMenu", "Element background")
    // Element sections inherit from the shared frame (prefix "allArea")
    readonly property bool inherits: prefix !== "allArea"
    // The shared padding lives in General › Spacing
    property bool showPadding: true
    // Shown at the top (e.g. "applies to all tile elements")
    property string scopeNote: ""

    body: Component {
        Item {
            // What it applies to (e.g. tiles: all or the chosen element)
            StyledText {
                visible: text !== ""
                x: Theme.spacingM
                width: parent.width - Theme.spacingM * 2
                wrapMode: Text.WordWrap
                text: area.scopeNote
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primary
            }

            SurfaceStyleSetting {
                id: areaColor
                keyPrefix: area.prefix
                defaultLabel: area.inherits ? area.settings?.inheritLabel : area.defaultLabel
                label: I18n.trFor("customMenu", "Color")
                description: I18n.trFor("customMenu", "Makes the element stand out, e.g. when the canvas is turned off")
                defaultColor: area.defaultColor
            }

            PluginSlider {
                settingKey: area.prefix + "Radius"
                label: I18n.trFor("customMenu", "Corner radius")
                resettable: true
                defaultValue: area.inherits ? area.settings?.sharedOr("allAreaRadius", Math.round(Theme.cornerRadius)) : Math.round(Theme.cornerRadius)
                minimum: 0
                maximum: 64
                unit: "px"
            }

            PluginSlider {
                visible: area.showPadding
                settingKey: area.prefix + "Padding"
                label: I18n.trFor("customMenu", "Padding")
                description: I18n.trFor("customMenu", "Space between the background edge and the content (only with a background or border)")
                resettable: true
                defaultValue: area.inherits ? area.settings?.sharedOr("allAreaPadding", Defaults.areaPadding) : Defaults.areaPadding
                minimum: 0
                maximum: 48
                unit: "px"
            }

            PluginToggle {
                settingKey: area.prefix + "Blur"
                label: I18n.trFor("customMenu", "Background blur")
                description: I18n.trFor("customMenu", "Blurs whatever is behind the background, following its shape. Visible only with a custom, translucent menu surface (Appearance › Level 1) and a translucent or no background color.")
                defaultValue: area.inherits ? area.settings?.sharedOr("allAreaBlur", false) : false
            }
        }
    }
}
