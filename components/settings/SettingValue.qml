import QtQuick
import qs.Services

// Shared logic of the plugin setting controls (PluginSlider, PluginToggle,
// PluginSelection). Replaces DMS' SliderSetting/ToggleSetting/
// SelectionSetting, which store their default once while being created and
// can overwrite the stored value with it (seen after rebuilding the page).
// Here:
//   - value is read live from the plugin data (updates on every change,
//     e.g. presets or reset, without rebuilding the page)
//   - only a user action writes (save())
QtObject {
    id: root

    required property Item host
    required property string settingKey
    property var defaultValue

    property int _revision: 0
    readonly property var value: {
        _revision;
        const settings = findSettings();
        if (!settings)
            return defaultValue;
        const v = settings.loadValue(settingKey, undefined);
        if (v !== undefined && v !== null)
            return v;
        // Not stored: the chosen template, then the default
        const t = settings.templateValue ? settings.templateValue(settingKey) : undefined;
        return t === undefined || t === null ? defaultValue : t;
    }

    function findSettings() {
        let item = host?.parent;
        while (item) {
            if (item.saveValue !== undefined && item.loadValue !== undefined)
                return item;
            item = item.parent;
        }
        return null;
    }

    // Stored at all (else the default, e.g. inherited from General, applies)
    readonly property bool isSet: {
        _revision;
        const settings = findSettings();
        if (!settings)
            return false;
        const v = settings.loadValue(settingKey, undefined);
        return v !== undefined && v !== null;
    }

    // Back to the default (removes the stored value)
    function clear() {
        findSettings()?.saveValue(settingKey, undefined);
        _revision++;
    }

    function save(v) {
        findSettings()?.saveValue(settingKey, v);
        _revision++;
    }

    // Plugin data changed elsewhere (other control, preset, reset)
    readonly property Connections _watch: Connections {
        target: PluginService
        function onPluginDataChanged(pluginId) {
            root._revision++;
        }
    }

    // Parents (SettingsCard slots) are attached after creation
    Component.onCompleted: Qt.callLater(() => _revision++)
}
