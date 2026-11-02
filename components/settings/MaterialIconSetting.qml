import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import "../common"

// Picks one icon via IconPickerDialog: an icon file (coloured, stored as a
// path) or a Material Symbols icon (stored as its name). Empty = defaultValue.
// Optional colorKey: colour of symbol icons in the same row (swatch next to
// the folder button; icon files keep their colours).
Column {
    id: root

    required property string settingKey
    property string label: ""
    property string description: ""
    property string defaultValue: "apps"
    // Theme subfolders the file picker opens when no file is chosen
    property var hintFolders: []
    // Symbol names for the picker's "Suggestions" chip
    property var suggestions: []
    readonly property string value: store.value || defaultValue
    readonly property bool isFile: value.startsWith("/")
    property string colorKey: ""
    property color defaultColor: Theme.surfaceText
    readonly property color iconColor: colorStore.value ? colorStore.value : defaultColor

    // Same indent as DMS' toggles (label and switch inset by spacingM)
    x: Theme.spacingM
    width: parent ? parent.width - Theme.spacingM * 2 : 0
    spacing: Theme.spacingS

    SettingValue {
        id: store
        host: root
        settingKey: root.settingKey
        defaultValue: ""
    }

    SettingValue {
        id: colorStore
        host: root
        settingKey: root.colorKey
        defaultValue: ""
    }

    StyledText {
        visible: root.label !== ""
        text: root.label
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Theme.fontWeightMedium
        color: Theme.surfaceText
    }

    StyledText {
        visible: root.description !== ""
        width: parent.width
        text: root.description
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    // Preview, name or file name (display only), colour, icon picker
    Row {
        id: line
        width: parent.width
        spacing: Theme.spacingM

        FlexIcon {
            id: preview
            anchors.verticalCenter: parent.verticalCenter
            icon: root.value
            size: Theme.iconSize
            color: root.iconColor
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: line.width - preview.width - colorBox.width - chooseButton.width - line.spacing * 3
            text: root.isFile ? root.value.substring(root.value.lastIndexOf("/") + 1) : root.value
            // As small as the description text
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            elide: Text.ElideMiddle
        }

        // Colour swatch + reset (only with colorKey, only symbol icons)
        Row {
            id: colorBox
            anchors.verticalCenter: parent.verticalCenter
            visible: root.colorKey !== ""
            spacing: Theme.spacingXS

            DActionButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: colorStore.value !== "" && !root.isFile
                iconName: "restart_alt"
                tooltipText: I18n.trFor("customMenu", "Default color")
                onClicked: colorStore.save("")
            }

            Rectangle {
                id: swatch
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 28
                radius: Theme.cornerRadiusS
                opacity: root.isFile ? 0.3 : 1
                color: "transparent"
                border.width: 2
                border.color: swatchArea.containsMouse && !root.isFile ? Theme.primary : Theme.surfaceText

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: Math.max(0, parent.radius - 4)
                    color: root.iconColor
                }

                MouseArea {
                    id: swatchArea
                    anchors.fill: parent
                    enabled: !root.isFile
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const picker = PopoutService.colorPickerModal;
                        if (!picker)
                            return;
                        picker.selectedColor = root.iconColor;
                        picker.pickerTitle = root.label || root.description;
                        picker.onColorSelectedCallback = selected => colorStore.save(selected.toString());
                        picker.show();
                    }
                }
            }
        }

        DActionButton {
            id: chooseButton
            anchors.verticalCenter: parent.verticalCenter
            iconName: "folder_open"
            tooltipText: I18n.trFor("customMenu", "Choose icon")
            onClicked: {
                const st = store.findSettings();
                fileDialog.currentIcon = root.value;
                fileDialog.favorites = st ? [st.loadValue("iconFavorite1", ""), st.loadValue("iconFavorite2", ""), st.loadValue("iconFavorite3", "")] : [];
                fileDialog.open();
            }
        }
    }

    IconPickerDialog {
        id: fileDialog
        hintFolders: root.hintFolders
        suggestions: root.suggestions
        onPicked: path => store.save(path)
    }
}
