import QtQuick
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets
import qs.Services

// Slider setting in DMS' look (DSlider), see SettingValue.qml for why
// it does not use DMS' SliderSetting.
Column {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    property int defaultValue: 0
    property int minimum: 0
    property int maximum: 100
    property string unit: ""
    // Slider steps (e.g. 5 for percent in 5 % steps)
    property int step: 1
    // Number field next to the slider for exact values
    property bool showInput: true
    // Reset button while a value is stored: back to defaultValue (which may be
    // the value inherited from General › Element look)
    property bool resettable: false
    // Text shown instead of the value while nothing is stored (e.g. "not set")
    property string unsetText: ""
    readonly property int value: store.value

    // Same indent as DMS' toggles (label and switch inset by spacingM)
    x: Theme.spacingM
    width: parent ? parent.width - Theme.spacingM * 2 : 0
    spacing: Theme.spacingS

    SettingValue {
        id: store
        host: root
        settingKey: root.settingKey
        defaultValue: root.defaultValue
    }

    // DSlider sets its own value while dragging (binding lost), so keep
    // it in sync by hand when the stored value changes elsewhere.
    onValueChanged: {
        if (slider.value !== value)
            slider.value = value;
        // The field shows the stored value unless it is being typed in
        if (!valueInput.activeFocus)
            valueInput.text = String(value);
    }

    Item {
        width: parent.width
        height: Math.max(labelText.implicitHeight, resetButton.visible ? resetButton.height : 0)

        StyledText {
            id: labelText
            anchors.verticalCenter: parent.verticalCenter
            text: root.label + (root.unsetText !== "" && !store.isSet ? "  ·  " + root.unsetText : "")
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Theme.fontWeightMedium
            color: Theme.surfaceText
        }

        DActionButton {
            id: resetButton
            visible: root.resettable && store.isSet
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconName: "restart_alt"
            buttonSize: 28
            iconSize: 16
            tooltipText: I18n.trFor("customMenu", "Default")
            onClicked: store.clear()
        }
    }

    StyledText {
        visible: root.description !== ""
        width: parent.width
        text: root.description
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    // Tells the menu that a slider is being dragged: it then holds back
    // moving the settings window until release (the window moving under
    // the mouse would shift the slider under the cursor).
    function reportDragging(dragging) {
        const id = store.findSettings()?.pluginId;
        if (id)
            PluginService.setGlobalVar(id, "sliderDragging", dragging);
    }
    Component.onDestruction: if (slider.isDragging) reportDragging(false)

    Row {
        width: parent.width
        spacing: Theme.spacingS

        DSlider {
            id: slider
            anchors.verticalCenter: parent.verticalCenter
            onIsDraggingChanged: root.reportDragging(isDragging)
            width: parent.width - (valueInput.visible ? valueInput.width + parent.spacing : 0)
            value: root.value
            minimum: root.minimum
            maximum: root.maximum
            step: root.step
            unit: root.unit
            wheelEnabled: false
            onSliderValueChanged: newValue => {
                if (newValue !== store.value)
                    store.save(newValue);
            }
        }

        // Exact value: typed in, saved on Enter or leaving the field
        DTextField {
            id: valueInput
            visible: root.showInput
            anchors.verticalCenter: parent.verticalCenter
            width: 90
            height: 36
            text: String(root.value)
            // Digits only; the range is applied when taking the value (a range
            // in the validator would make e.g. "30" below a minimum of 50
            // "intermediate": then Enter does nothing and the field keeps it)
            validator: RegularExpressionValidator {
                regularExpression: root.minimum < 0 ? /^-?\d{0,6}$/ : /^\d{0,6}$/
            }
            onEditingFinished: {
                const v = parseInt(text);
                if (!isNaN(v)) {
                    const clamped = Math.max(root.minimum, Math.min(root.maximum, v));
                    if (clamped !== store.value)
                        store.save(clamped);
                }
                text = String(root.value);
            }
        }
    }
}
