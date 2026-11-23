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
    // Most of the settings window, its margin from the theme
    width: Math.max(0, (parent?.width ?? 0) * 0.8 - Theme.spacingXL * 2)
    height: Math.max(0, (parent?.height ?? 0) * 0.85 - Theme.spacingXL * 2)
    padding: Theme.spacingL

    background: StyledRect {
        radius: Theme.cornerRadiusL
        color: Theme.hostSurface
        border.width: Theme.outlineWidth
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
