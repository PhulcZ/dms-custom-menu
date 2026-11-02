import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets

// Removes all own look values of an element (it follows General again)
Item {
    id: lookReset
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
    property var keys: []
    width: parent ? parent.width : 0
    height: lookResetButton.height
    DButton {
        id: lookResetButton
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingM
        iconName: "restart_alt"
        text: I18n.trFor("customMenu", "Same as Appearance")
        onClicked: lookReset.settings?.resetLook(lookReset.keys)
    }
}
