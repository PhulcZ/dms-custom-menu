import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets

// Own border of an element
Section {
    id: areaBorder
    property string prefix: ""
    title: I18n.trFor("customMenu", "Element border")
    property string scopeNote: ""

    body: Component {
        Item {
            // What it applies to (e.g. tiles: all or the chosen element)
            StyledText {
                visible: text !== ""
                x: Theme.spacingM
                width: parent.width - Theme.spacingM * 2
                wrapMode: Text.WordWrap
                text: areaBorder.scopeNote
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primary
            }

            PluginSlider {
                id: borderWidth
                settingKey: areaBorder.prefix + "BorderWidth"
                label: I18n.trFor("customMenu", "Width")
                description: I18n.trFor("customMenu", "0 = no border")
                resettable: true
                defaultValue: areaBorder.prefix !== "allArea" ? areaBorder.settings?.sharedOr("allAreaBorderWidth", 0) : 0
                minimum: 0
                maximum: 6
                unit: "px"
            }

            SurfaceStyleSetting {
                keyPrefix: areaBorder.prefix + "Border"
                defaultLabel: areaBorder.prefix !== "allArea" ? areaBorder.settings?.inheritLabel : I18n.trFor("customMenu", "Default (Outline)")
                label: I18n.trFor("customMenu", "Color")
                defaultColor: Theme.outlineVariant
                optionSet: "border"
            }
        }
    }
}
