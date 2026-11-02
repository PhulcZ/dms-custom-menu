import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets

// Font weight
PluginSelection {
    label: I18n.trFor("customMenu", "Weight")
    options: [
        { label: I18n.trFor("customMenu", "Normal"), value: "normal" },
        { label: I18n.trFor("customMenu", "Medium"), value: "medium" },
        { label: I18n.trFor("customMenu", "Bold"), value: "bold" }
    ]
}
