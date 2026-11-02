import QtQuick
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets

// Toggle setting in DMS' look (DToggle), see SettingValue.qml.
Item {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    property bool defaultValue: false
    readonly property bool value: store.value === true

    signal userToggled(bool checked)

    width: parent ? parent.width : 0
    // DToggle sets height, not implicitHeight
    implicitHeight: toggle.height
    height: implicitHeight

    SettingValue {
        id: store
        host: root
        settingKey: root.settingKey
        defaultValue: root.defaultValue
    }

    onValueChanged: if (toggle.checked !== value) toggle.checked = value

    DToggle {
        id: toggle
        width: parent.width
        text: root.label
        description: root.description
        checked: root.value
        onToggled: isChecked => {
            store.save(isChecked);
            root.userToggled(isChecked);
        }
    }
}
