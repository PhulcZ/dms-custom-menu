import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets
import "../common"

// IconPicker as a dialog over the settings window (a Popup in the same
// window, like DMS' own DIconPicker). In CustomMenu itself the picker
// is shown inside the card instead, since windows would end up below it.
Popup {
    id: root

    property string currentIcon: ""
    property var hintFolders: []
    property var favorites: []
    // Symbol names for the "Suggestions" chip
    property var suggestions: []

    signal picked(string path)

    parent: Overlay.overlay
    modal: true
    dim: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    anchors.centerIn: parent
    width: Math.min(960, (parent?.width ?? 960) - Theme.spacingXL * 2)
    height: Math.min(680, (parent?.height ?? 680) - Theme.spacingXL * 2)
    padding: Theme.spacingL

    background: StyledRect {
        radius: Theme.cornerRadiusL
        color: Theme.hostSurface
        border.width: 1
        border.color: Theme.outlineVariant
    }

    onOpened: picker.open()

    contentItem: IconPicker {
        id: picker
        currentIcon: root.currentIcon
        hintFolders: root.hintFolders
        favorites: root.favorites
        suggestions: root.suggestions
        // Bar, search and category icons are drawn by FlexIcon: logos work
        allowLogos: true
        onPicked: path => {
            root.picked(path);
            root.close();
        }
        onCancelled: root.close()
    }
}
