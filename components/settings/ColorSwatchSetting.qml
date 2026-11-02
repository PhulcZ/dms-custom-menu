import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets

// Colour setting like DMS' ColorSetting, but with a swatch that always
// stands out from the background: DMS' swatch only has a faint border
// (outlineStrong) and disappears when the colour equals the card colour of
// the settings page, which is exactly the case when switching from "Default".
Column {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    property color defaultValue: Theme.primary
    property color value: defaultValue
    // Optional reset button (back to defaultValue, stored as empty)
    property bool resettable: false
    property bool isSet: false

    property bool isInitialized: false

    // Same indent as DMS' toggles (label and switch inset by spacingM)
    x: Theme.spacingM
    width: parent ? parent.width - Theme.spacingM * 2 : 0
    spacing: Theme.spacingS

    // Like QmlUtils.findSettings in DMS: find the enclosing PluginSettings.
    function findSettings() {
        let item = root.parent;
        while (item) {
            if (item.saveValue !== undefined && item.loadValue !== undefined)
                return item;
            item = item.parent;
        }
        return null;
    }

    function loadValue() {
        const settings = findSettings();
        if (!settings || !settings.pluginService)
            return;
        // Stored value, else the chosen template's
        const loaded = settings.effectiveValue ? settings.effectiveValue(settingKey, "") : settings.loadValue(settingKey, "");
        isSet = typeof loaded === "string" && loaded !== "";
        value = isSet ? loaded : defaultValue;
        isInitialized = true;
    }

    Component.onCompleted: Qt.callLater(loadValue)

    onValueChanged: {
        if (!isInitialized)
            return;
        const settings = findSettings();
        if (settings)
            settings.saveValue(settingKey, value.toString());
        isSet = true;
    }

    function reset() {
        isInitialized = false;
        value = defaultValue;
        findSettings()?.saveValue(settingKey, "");
        isSet = false;
        isInitialized = true;
    }

    StyledText {
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

    Row {
        spacing: Theme.spacingM

        // Two rings: outer in text colour, inner in the page background colour.
        // The swatch stays visible with any colour, even an identical one.
        Rectangle {
            id: swatchRing
            width: 100
            height: 36
            radius: Theme.cornerRadius
            color: "transparent"
            border.color: swatchArea.containsMouse ? Theme.primary : Theme.surfaceText
            border.width: 2

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: Math.max(0, swatchRing.radius - 4)
                color: root.value
            }

            MouseArea {
                id: swatchArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const picker = PopoutService.colorPickerModal;
                    if (!picker)
                        return;
                    picker.selectedColor = root.value;
                    picker.pickerTitle = root.label;
                    picker.onColorSelectedCallback = selectedColor => root.value = selectedColor;
                    picker.show();
                }
            }
        }

        DActionButton {
            visible: root.resettable && root.isSet
            anchors.verticalCenter: parent.verticalCenter
            iconName: "restart_alt"
            tooltipText: I18n.trFor("customMenu", "Default")
            onClicked: root.reset()
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.value.toString()
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
        }
    }
}
