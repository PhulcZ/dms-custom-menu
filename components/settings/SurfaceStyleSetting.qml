import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "../../ColorRoles.js" as ColorRoles

// Colour of a layer (card, chip, text) following DMS' surface settings:
// "default" follows the DMS theme, otherwise a theme role or a custom
// colour. Optional transparency (off = opaque, on = slider in percent).
//
// Stored keys, with keyPrefix = e.g. "card":
//   cardColorMode, cardCustomColor, cardTransparent, cardTransparency
Column {
    id: root

    required property string keyPrefix
    required property string label
    property string description: ""
    property color defaultColor: Theme.cardSurface
    property bool textRoles: false
    // Which option list: "surface" (surfaces), "text", "border"
    property string optionSet: textRoles ? "text" : "surface"
    // Label of the default entry, e.g. "Default (Outline)", shows which
    // DMS value is behind it.
    property string defaultLabel: I18n.trFor("customMenu", "Default")
    readonly property bool isNone: mode.value === "none"
    readonly property string modeValue: mode.value
    property bool withTransparency: true
    property bool defaultTransparent: false
    property int defaultTransparency: 0

    width: parent.width
    spacing: Theme.spacingM

    // One list for surfaces, text and borders: default, none, custom;
    // DMS' surface levels (names from DMS' own translation, colours from
    // its settings); black and white 85 % transparent; the accent colours;
    // then the rest of DMS' colour roles (resolved in ColorRoles.js)
    readonly property var allOptions: [
        { label: root.defaultLabel, value: "default" },
        { label: I18n.trFor("customMenu", "None"), value: "none" },
        { label: I18n.trFor("customMenu", "Custom"), value: "custom" },
        { label: "DMS Level 1 " + I18n.tr("Host"), value: "host" },
        { label: "DMS Level 2 " + I18n.tr("Cards"), value: "card" },
        { label: "DMS Level 3 " + I18n.tr("Chip", "surface role"), value: "chip" },
        { label: "DMS Level 4 " + I18n.tr("Nested chip", "surface role"), value: "chipNested" },
        { label: I18n.trFor("customMenu", "Black, 85% transparent"), value: "black85" },
        { label: I18n.trFor("customMenu", "White, 85% transparent"), value: "white85" },
        { label: I18n.trFor("customMenu", "Primary"), value: "primary" },
        { label: I18n.trFor("customMenu", "Secondary"), value: "secondary" },
        { label: I18n.trFor("customMenu", "Tertiary"), value: "tertiary" },
        { label: I18n.trFor("customMenu", "Primary Container"), value: "primaryContainer" },
        { label: I18n.trFor("customMenu", "Secondary Container"), value: "secondaryContainer" },
        { label: I18n.trFor("customMenu", "Tertiary Container"), value: "tertiaryContainer" },
        { label: I18n.trFor("customMenu", "Text"), value: "surfaceText" },
        { label: I18n.trFor("customMenu", "Surface Variant"), value: "surfaceVariant" },
        { label: I18n.trFor("customMenu", "Surface"), value: "s" },
        { label: I18n.trFor("customMenu", "Surface Lowest"), value: "scll" },
        { label: I18n.trFor("customMenu", "Surface Low"), value: "scl" },
        { label: I18n.trFor("customMenu", "Surface Container"), value: "sc" },
        { label: I18n.trFor("customMenu", "Surface High"), value: "sch" },
        { label: I18n.trFor("customMenu", "Surface Highest"), value: "schh" },
        { label: I18n.trFor("customMenu", "Error"), value: "error" }
    ]

    // PluginSettings only reloads its direct children after changes (e.g. a
    // reset), so reload the building blocks in here ourselves.
    Connections {
        target: PluginService
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId !== "customMenu")
                return;
            for (let i = 0; i < root.children.length; i++) {
                if (root.children[i].loadValue)
                    root.children[i].loadValue();
            }
        }
    }

    // Swatch per entry: the role's colour from the current theme (without
    // the transparency setting below; black/white 85 % bring their own),
    // "Default" the colour that applies without a choice, "Custom" the own one
    readonly property var optionColors: {
        const out = { "default": root.defaultColor, "none": "transparent", "custom": customColor.value };
        for (const o of allOptions) {
            if (out[o.value] === undefined)
                out[o.value] = ColorRoles.resolve(Theme, o.value, "", Theme.surface);
        }
        return out;
    }
    TextMetrics {
        id: longestLabel
        font.pixelSize: Theme.fontSizeMedium
        text: root.allOptions.reduce((a, o) => o.label.length > a.length ? o.label : a, "")
    }

    PluginSelection {
        id: mode
        settingKey: root.keyPrefix + "ColorMode"
        label: root.label
        description: root.description
        options: root.allOptions
        defaultValue: "default"
        optionColors: root.optionColors
        // Wide enough for the longest entry with its swatch
        popupWidth: Math.ceil(longestLabel.width + Theme.iconSizeSmall + Theme.spacingS + Theme.spacingM * 2 + Theme.spacingL)
    }

    ColorSwatchSetting {
        id: customColor
        visible: mode.value === "custom"
        settingKey: root.keyPrefix + "CustomColor"
        label: I18n.trFor("customMenu", "Custom color")
        defaultValue: root.defaultColor
    }

    // Off = fully opaque. On = the slider adds transparency from 0 %.
    PluginToggle {
        id: transparent
        visible: root.withTransparency && !root.isNone
        settingKey: root.keyPrefix + "Transparent"
        label: I18n.trFor("customMenu", "Transparency")
        description: I18n.trFor("customMenu", "Off: fully opaque")
        defaultValue: root.defaultTransparent
    }

    PluginSlider {
        visible: root.withTransparency && !root.isNone && transparent.value
        settingKey: root.keyPrefix + "Transparency"
        label: I18n.trFor("customMenu", "Transparency level")
        description: I18n.trFor("customMenu", "0% is fully opaque")
        defaultValue: root.defaultTransparency
        minimum: 0
        maximum: 100
        unit: "%"
    }
}
