import QtQuick
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets

// Dropdown setting in DMS' look (DDropdown), see SettingValue.qml.
// options: [{ label, value, hidden }] — hidden entries can be shown as the
// current value but are not offered in the list (e.g. "Custom" for presets).
Item {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    required property var options
    property string defaultValue: ""
    // Optional first entry that removes the own value (inherit, e.g. from
    // General › Element look); shown while nothing is stored
    property string inheritLabel: ""
    readonly property string value: store.value ?? ""
    readonly property var allOptions: inheritLabel !== "" ? [{ label: inheritLabel, value: "__inherit" }].concat(options) : options
    readonly property string shownValue: inheritLabel !== "" && !store.isSet ? "__inherit" : value

    // Optional colour per option value: shown as a swatch before the entry
    // (and in the closed field), see DDropdown.optionColorMap
    property var optionColors: ({})
    // Width of the open list, if wider than the field is needed (0 = field)
    property int popupWidth: 0

    signal userSelected(string value)

    // Same indent as DMS' toggles (label and switch inset by spacingM)
    x: Theme.spacingM
    width: parent ? parent.width - Theme.spacingM * 2 : 0
    implicitHeight: dropdown.implicitHeight
    height: implicitHeight

    SettingValue {
        id: store
        host: root
        settingKey: root.settingKey
        defaultValue: root.defaultValue
    }

    function labelFor(v) {
        const o = allOptions.find(x => x.value === v);
        return o ? o.label : v;
    }

    // DDropdown overwrites currentValue on selection (binding lost)
    onShownValueChanged: dropdown.currentValue = labelFor(shownValue)
    onAllOptionsChanged: dropdown.currentValue = labelFor(shownValue)

    DDropdown {
        id: dropdown
        width: parent.width
        text: root.label
        description: root.description
        options: root.allOptions.filter(o => !o.hidden).map(o => o.label)
        optionColorMap: {
            const map = {};
            for (const o of root.allOptions) {
                if (root.optionColors[o.value] !== undefined)
                    map[o.label] = root.optionColors[o.value];
            }
            return map;
        }
        popupWidth: root.popupWidth
        currentValue: root.labelFor(root.shownValue)
        onValueChanged: label => {
            const o = root.allOptions.find(x => x.label === label);
            if (!o)
                return;
            if (o.value === "__inherit") {
                store.clear();
                return;
            }
            // Also on re-selecting the current entry (e.g. "Center" resets the offset)
            if (o.value !== store.value)
                store.save(o.value);
            root.userSelected(o.value);
        }
    }
}
