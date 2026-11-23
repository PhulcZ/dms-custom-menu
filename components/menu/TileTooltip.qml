import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Tooltip for app and button tiles: DMS' tooltip, below the tile after a
// short pause while the mouse rests on it. Shows what the tile itself does
// not: the name when it is hidden or cut, the description when there is one
// and it is not on the tile in full; nothing new, no tooltip.
Item {
    id: root

    property string title: ""
    property string description: ""
    property Item target: null
    property MouseArea hoverArea: null
    // What the tile shows in full already
    property bool nameShown: false
    property bool descriptionShown: false

    readonly property string titlePart: nameShown ? "" : title
    readonly property string descriptionPart: descriptionShown ? "" : description
    readonly property string shownText: [titlePart, descriptionPart].filter(s => s !== "").join("\n")
    // title "" = tooltips off for this tile
    readonly property bool wanted: !!hoverArea && hoverArea.containsMouse && title !== "" && shownText !== ""

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
        multiline: root.shownText.indexOf("\n") >= 0 || root.shownText.length > 40
    }
}
