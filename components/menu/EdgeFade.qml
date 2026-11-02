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

// Soft edges of a scrolling area (instead of DMS' DFlickable fade, which
// paints the colour of the nearest opaque surface: on see-through
// elements that is the window, i.e. dark): the content itself fades to
// transparent at the top and bottom, over `length`, growing with the
// distance scrolled (like DMS'). Put it next to the target, not inside.
Item {
    id: ef
    // The menu widget (CustomMenuWidget): its settings and functions
    required property Item menu
    property Flickable target: null
    property real length: Theme.spacingXL
    readonly property bool active: menu.scrollFade && target !== null && target.visible && target.contentHeight > target.height + 1
    readonly property real topStrength: target ? Math.min(1, Math.max(0, (target.contentY - target.originY) / length)) : 0
    readonly property real bottomStrength: target ? Math.min(1, Math.max(0, (target.originY + target.contentHeight - target.height - target.contentY) / length)) : 0
    readonly property real share: target && target.height > 0 ? Math.min(0.5, length / target.height) : 0
    visible: false
    x: target?.x ?? 0
    y: target?.y ?? 0
    width: target?.width ?? 0
    height: target?.height ?? 0
    // The mask: opaque in the middle, the edges fade by their strength
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 1 - ef.topStrength) }
            GradientStop { position: ef.share; color: "black" }
            GradientStop { position: 1 - ef.share; color: "black" }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 1 - ef.bottomStrength) }
        }
    }
    Binding {
        target: ef.target
        property: "layer.enabled"
        value: ef.active
    }
    Binding {
        target: ef.target
        property: "layer.effect"
        value: fadeEffect
    }
    Component {
        id: fadeEffect
        OpacityMask {
            maskSource: ef
        }
    }
}
