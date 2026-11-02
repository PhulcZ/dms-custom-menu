import QtQuick
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets

// Small modal dialog over the settings window: title, message, optional
// content (e.g. a name field) and buttons, right-aligned. Escape or a
// click beside it closes it (= cancel). Created on demand in the layer DMS
// uses for its own dialogs (an item moved there later is not drawn).
Item {
    id: root

    property string title: ""
    property string message: ""
    property bool open: false
    // Content between message and buttons (not the default property: that
    // would also take this file's own children)
    property alias content: contentColumn.data
    property alias buttons: buttonRow.data

    signal cancelled

    // Created where it is shown (see TemplateBar.openDialog) and destroyed
    // when it closes
    function close() {
        if (!open)
            return;
        open = false;
        cancelled();
        root.destroy();
    }
    function done() {
        open = false;
        root.destroy();
    }

    visible: open
    z: 1000
    anchors.fill: parent
    onOpenChanged: if (open) card.forceActiveFocus()
    Component.onCompleted: if (open) card.forceActiveFocus()

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, Theme.scrimAlpha)
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.spacingL * 2, 440)
        height: column.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadiusL
        color: Theme.surfaceContainerHigh
        border.width: Theme.layerOutlineWidth
        border.color: Theme.outlineMedium
        focus: true
        Keys.onEscapePressed: root.close()

        // Clicks on the card stay on it
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column
            x: Theme.spacingL
            y: Theme.spacingL
            width: parent.width - Theme.spacingL * 2
            spacing: Theme.spacingM

            StyledText {
                visible: text !== ""
                width: parent.width
                wrapMode: Text.WordWrap
                text: root.title
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceText
            }
            StyledText {
                visible: text !== ""
                width: parent.width
                wrapMode: Text.WordWrap
                text: root.message
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
            }
            Column {
                id: contentColumn
                width: parent.width
                spacing: Theme.spacingS
            }
            Flow {
                id: buttonRow
                width: parent.width
                spacing: Theme.spacingS
                layoutDirection: Qt.RightToLeft
            }
        }
    }
}
