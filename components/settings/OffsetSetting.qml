import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets

// Collapsible section (DMS' SettingsCard); open state remembered per key
// Offset slider plus a button that re-centres (offset 0)
Row {
    id: offsetRow
    // The settings page (CustomMenuSettings): found up the parents, also
    // when built later inside a section's lazy body
    property Item settings: null
    function findSettings() {
        for (let p = parent; p; p = p.parent) {
            if (p.loadValue !== undefined && p.saveValue !== undefined && p.sectionExpanded !== undefined)
                return p;
        }
        return null;
    }
    onParentChanged: if (!settings) settings = findSettings()
    Component.onCompleted: if (!settings) settings = findSettings()
    property alias settingKey: offsetSlider.settingKey
    property alias label: offsetSlider.label
    property alias description: offsetSlider.description
    property int range: 1000
    // Same indent as DMS' toggles; the slider inside sits at 0
    x: Theme.spacingM
    width: parent ? parent.width - Theme.spacingM * 2 : 0
    spacing: Theme.spacingS

    PluginSlider {
        id: offsetSlider
        width: offsetRow.width - centreButton.width - offsetRow.spacing
        settingKey: ""
        label: ""
        defaultValue: 0
        minimum: -offsetRow.range
        maximum: offsetRow.range
        unit: "px"
    }

    DActionButton {
        id: centreButton
        anchors.bottom: parent.bottom
        iconName: "filter_center_focus"
        tooltipText: I18n.trFor("customMenu", "Center")
        onClicked: offsetRow.settings?.saveValue(offsetRow.settingKey, 0)
    }
}
