import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

// Tooltip for app and button tiles: like DMS' tooltip, but with a minimum
// width (above it text width + padding), name and description on own lines
// and DMS' tooltip colours. Shown below the target (moved inside
// the window by the popup margins) after DMS' tooltip delay.
ToolTip {
    id: root

    property string title: ""
    property string description: ""
    property Item target: null
    property MouseArea hoverArea: null

    readonly property real minWidth: 120
    readonly property real maxWidth: 320
    readonly property bool wanted: !!hoverArea && hoverArea.containsMouse && title !== ""

    parent: target
    x: target ? (target.width - width) / 2 : 0
    y: target ? target.height + Theme.spacingS : 0
    margins: Theme.spacingXS
    leftPadding: Theme.spacingM
    rightPadding: Theme.spacingM
    topPadding: Theme.spacingS
    bottomPadding: Theme.spacingS
    closePolicy: Popup.NoAutoClose
    modal: false
    dim: false

    onWantedChanged: {
        if (wanted) {
            showTimer.restart();
        } else {
            showTimer.stop();
            close();
        }
    }
    onTitleChanged: if (title === "") close()

    Timer {
        id: showTimer
        interval: 400
        onTriggered: if (root.wanted) root.open()
    }

    background: Rectangle {
        color: Theme.inverseSurface
        radius: Theme.cornerRadiusXS
    }

    contentItem: Column {
        // Text width, at least the minimum, wrapped at the maximum
        readonly property real textWidth: Math.max(titleMetrics.width, root.description ? descriptionMetrics.width : 0)
        width: Math.max(root.minWidth - root.leftPadding - root.rightPadding, Math.min(root.maxWidth - root.leftPadding - root.rightPadding, Math.ceil(textWidth)))
        spacing: 2

        TextMetrics {
            id: titleMetrics
            font: titleText.font
            text: root.title
        }
        TextMetrics {
            id: descriptionMetrics
            font: descriptionText.font
            text: root.description
        }

        // StyledText: follows DMS' text renderer setting
        StyledText {
            id: titleText
            width: parent.width
            text: root.title
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            font.weight: Font.Normal
            color: Theme.inverseOnSurface
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }
        // StyledText: follows DMS' text renderer setting
        StyledText {
            id: descriptionText
            visible: root.description !== ""
            width: parent.width
            text: root.description
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            color: Theme.inverseOnSurface
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
