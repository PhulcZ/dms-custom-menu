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

// Vertical scroll bar in the middle of the free strip between the content
// (contentRight) and the element edge (edgeRight), both in the bar's
// parent; in DMS' DScrollbar look (thin, rounded, shown while scrolling
// or hovered, fades out). Attached to the Flickable (Qt keeps position
// and dragging in sync); position and height held by Bindings, as the
// attaching sets them itself (like DMS' DScrollbar).
QQC.ScrollBar {
    id: gs
    property Flickable flick: null
    property Item host: null
    property real contentRight: 0
    property real edgeRight: 0
    readonly property real thickness: DC.Style.scrollbarThickness
    property bool recent: false
    Binding on parent {
        when: gs.host !== null
        value: gs.host
    }
    Binding on x {
        // Too narrow a strip: at the edge
        value: Math.max(gs.contentRight, Math.min(gs.edgeRight - gs.thickness, (gs.contentRight + gs.edgeRight - gs.thickness) / 2))
    }
    Binding on y {
        value: gs.flick?.y ?? 0
    }
    Binding on height {
        value: gs.flick?.height ?? 0
    }
    width: thickness
    padding: 0
    topPadding: DC.Style.spacingXXS
    bottomPadding: DC.Style.spacingXXS
    z: 3
    orientation: Qt.Vertical
    minimumSize: 0.08
    hoverEnabled: true
    policy: DC.Style.scrollbarsEnabled && gs.flick && gs.flick.contentHeight > gs.flick.height + 1 ? QQC.ScrollBar.AsNeeded : QQC.ScrollBar.AlwaysOff
    visible: policy !== QQC.ScrollBar.AlwaysOff
    opacity: pressed || hovered || active || (gs.flick?.moving ?? false) || recent ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: 200
        }
    }
    contentItem: Rectangle {
        implicitWidth: gs.thickness
        radius: DC.Style.fullRadius(width, height)
        color: gs.pressed ? DC.Style.primary : DC.Style.outline
    }
    background: Item {}
    Connections {
        target: gs.flick
        function onContentYChanged() {
            gs.recent = true;
            gsHide.restart();
        }
    }
    Timer {
        id: gsHide
        interval: DC.Style.scrollbarHideDelay
        onTriggered: gs.recent = false
    }
}
