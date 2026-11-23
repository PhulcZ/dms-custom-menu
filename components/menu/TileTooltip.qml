import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Tooltip for app and button tiles: DMS' tooltip, the name and (when there
// is one) the description on its own line, below the tile after a short
// pause while the mouse rests on it.
Item {
    id: root

    property string title: ""
    property string description: ""
    property Item target: null
    property MouseArea hoverArea: null

    readonly property bool wanted: !!hoverArea && hoverArea.containsMouse && title !== ""
    readonly property string shownText: description !== "" ? title + "\n" + description : title

    onWantedChanged: {
        if (wanted) {
            showTimer.restart();
        } else {
            showTimer.stop();
            tip.hide();
        }
    }
    onTitleChanged: if (title === "") tip.hide()

    Timer {
        id: showTimer
        interval: 400
        onTriggered: if (root.wanted) tip.show(root.shownText, root.target, 0, 0, "bottom")
    }

    DTooltipV2 {
        id: tip
        multiline: root.description !== ""
    }
}
