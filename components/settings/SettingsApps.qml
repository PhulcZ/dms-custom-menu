import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets
import "../../Defaults.js" as Defaults

// ── Apps ──
Section {
    id: sectionRoot
    key: "apps"
    title: I18n.trFor("customMenu", "Apps")

    body: Component {
        Item {

            LookResetButton {
                keys: sectionRoot.settings.lookKeys(["chip", "chipBorder", "appText", "appsArea", "appsAreaBorder"], ["chipBorderWidth", "chipRadius", "textSize", "appTextWeight", "appsAreaRadius", "appsAreaPadding", "appsAreaBorderWidth"])
            }

            AreaSection {
                key: "appsArea"
                prefix: "appsArea"
                title: I18n.trFor("customMenu", "Background of this apps element")
            }

            AreaBorderSection {
                key: "appsAreaBorder"
                prefix: "appsArea"
                title: I18n.trFor("customMenu", "Border of this apps element")
            }

            // Basics
            // Preset: sets the building blocks below in one go,
            // everything can be changed afterwards.
            PluginSelection {
                id: layoutMode
                settingKey: "layoutMode"
                label: I18n.trFor("customMenu", "Preset")
                description: I18n.trFor("customMenu", "Sets the options below; you can change them afterwards")
                options: [
                    { label: I18n.trFor("customMenu", "Grid"), value: "grid" },
                    { label: I18n.trFor("customMenu", "Tiles"), value: "tile" },
                    { label: I18n.trFor("customMenu", "List"), value: "list" },
                    { label: I18n.trFor("customMenu", "Custom"), value: "custom", hidden: true }
                ]
                defaultValue: Defaults.layoutMode
                onUserSelected: v => sectionRoot.settings.applyPreset(v)
            }

            PluginSlider {
                settingKey: "appIconSize"
                label: I18n.trFor("customMenu", "Icon size")
                defaultValue: Defaults.appIconSize
                minimum: 24
                maximum: 128
                unit: "px"
            }

            PluginSlider {
                settingKey: "appSpacing"
                label: I18n.trFor("customMenu", "Horizontal spacing")
                description: I18n.trFor("customMenu", "Space between apps in a row")
                defaultValue: Defaults.appSpacing
                minimum: 0
                maximum: 64
                unit: "px"
            }

            PluginSlider {
                settingKey: "appRowSpacing"
                label: I18n.trFor("customMenu", "Vertical spacing")
                description: I18n.trFor("customMenu", "Space between rows")
                defaultValue: Defaults.appRowSpacing
                minimum: 0
                maximum: 64
                unit: "px"
            }

            // Building blocks: icon or name always stays on
            PluginToggle {
                id: appShowIcon
                enabled: appShowLabels.value
                settingKey: "appShowIcon"
                label: I18n.trFor("customMenu", "Show icon")
                defaultValue: Defaults.appShowIcon
            }

            PluginToggle {
                id: appShowLabels
                enabled: appShowIcon.value
                settingKey: "appShowLabels"
                label: I18n.trFor("customMenu", "Show app names")
                defaultValue: Defaults.appShowLabels
            }

            PluginToggle {
                settingKey: "appTooltips"
                label: I18n.trFor("customMenu", "Tooltips")
                description: I18n.trFor("customMenu", "Name and description when hovering over an app")
                defaultValue: Defaults.appTooltips
            }

            PluginToggle {
                id: appShowDescription
                settingKey: "appShowDescription"
                label: I18n.trFor("customMenu", "Show descriptions")
                description: I18n.trFor("customMenu", "App description in a line below the name")
                defaultValue: Defaults.appShowDescription
            }

            PluginSelection {
                id: appIconPosition
                visible: appShowIcon.value && (appShowLabels.value || appShowDescription.value)
                settingKey: "appIconPosition"
                label: I18n.trFor("customMenu", "Icon position")
                options: [
                    { label: I18n.trFor("customMenu", "Top"), value: "top" },
                    { label: I18n.trFor("customMenu", "Left"), value: "left" },
                    { label: I18n.trFor("customMenu", "Right"), value: "right" }
                ]
                defaultValue: Defaults.appIconPosition
            }

            PluginSlider {
                visible: appShowIcon.value && appIconPosition.value !== "top" && (appShowLabels.value || appShowDescription.value)
                settingKey: "appIconOffset"
                label: I18n.trFor("customMenu", "Icon offset")
                description: I18n.trFor("customMenu", "Moves the icon toward the text")
                defaultValue: Defaults.appIconOffset
                minimum: 0
                maximum: 64
                unit: "px"
            }

            PluginSlider {
                visible: appShowIcon.value && (appShowLabels.value || appShowDescription.value)
                settingKey: "appIconTextGap"
                label: I18n.trFor("customMenu", "Gap between icon and text")
                defaultValue: Defaults.appIconTextGap
                minimum: 0
                maximum: 64
                unit: "px"
            }

            PluginSlider {
                visible: appShowLabels.value && appShowDescription.value
                settingKey: "appDescriptionGap"
                label: I18n.trFor("customMenu", "Gap between name and description")
                description: I18n.trFor("customMenu", "Negative values move the lines closer together")
                defaultValue: Defaults.appDescriptionGap
                minimum: -10
                maximum: 32
                unit: "px"
            }

            PluginSelection {
                visible: appShowLabels.value || appShowDescription.value
                settingKey: "appTextAlign"
                label: I18n.trFor("customMenu", "Text alignment")
                options: [
                    { label: I18n.trFor("customMenu", "Left"), value: "left" },
                    { label: I18n.trFor("customMenu", "Center"), value: "center" },
                    { label: I18n.trFor("customMenu", "Right"), value: "right" }
                ]
                defaultValue: Defaults.appTextAlign
            }

            PluginToggle {
                id: appFullWidth
                settingKey: "appFullWidth"
                onUserToggled: checked => sectionRoot.settings.singleColumnChanged(checked)
                label: I18n.trFor("customMenu", "Single column")
                description: I18n.trFor("customMenu", "One app per row, full canvas width")
                defaultValue: Defaults.appFullWidth
            }

            PluginSelection {
                id: appAlignAuto
                settingKey: "appAlignAuto"
                label: I18n.trFor("customMenu", "Align automatically")
                description: I18n.trFor("customMenu", "If everything fits: centered. If not (the list scrolls, e.g. a search with files and sections): at the top (and left).")
                options: [
                    { label: I18n.trFor("customMenu", "Off"), value: "off" },
                    { label: I18n.trFor("customMenu", "Vertically only"), value: "v" },
                    { label: I18n.trFor("customMenu", "Vertically and horizontally"), value: "both" }
                ]
                defaultValue: Defaults.appAlignAuto
                // value is a string here; former true/false = both/off
                readonly property string mode: value === "true" ? "both" : value === "false" ? "off" : (value || "both")
            }
            PluginSelection {
                visible: appAlignAuto.mode !== "both"
                settingKey: "appAlignH"
                label: I18n.trFor("customMenu", "Horizontal alignment")
                options: [
                    { label: I18n.trFor("customMenu", "Left"), value: "start" },
                    { label: I18n.trFor("customMenu", "Centered"), value: "center" },
                    { label: I18n.trFor("customMenu", "Right"), value: "end" }
                ]
                defaultValue: Defaults.appAlignH
            }
            PluginSelection {
                visible: appAlignAuto.mode === "off"
                settingKey: "appAlignV"
                label: I18n.trFor("customMenu", "Vertical alignment")
                description: I18n.trFor("customMenu", "Where the content sits when the element is larger than it")
                options: [
                    { label: I18n.trFor("customMenu", "Top"), value: "start" },
                    { label: I18n.trFor("customMenu", "Centered"), value: "center" },
                    { label: I18n.trFor("customMenu", "Bottom"), value: "end" }
                ]
                defaultValue: Defaults.appAlignV
            }

            Section {
                key: "appChip"
                title: I18n.trFor("customMenu", "Chips")

                body: Component {
                    Item {

                        PluginToggle {
                            id: chipEnabled
                            settingKey: "chipEnabled"
                            label: I18n.trFor("customMenu", "Show chips")
                            description: I18n.trFor("customMenu", "Gives each app its own background")
                            defaultValue: Defaults.chipEnabled
                        }

                        PluginSlider {
                            visible: !appFullWidth.value
                            settingKey: "chipWidth"
                            label: I18n.trFor("customMenu", "Width")
                            description: I18n.trFor("customMenu", "Also applies without visible chips")
                            defaultValue: Defaults.chipWidth
                            minimum: 40
                            maximum: Math.max(400, PluginService.globalVars[sectionRoot.settings.pluginId]?.rowWidth ?? 400)
                            unit: "px"
                            step: 5
                        }

                        PluginSlider {
                            id: appChipHeight
                            settingKey: "chipHeight"
                            label: I18n.trFor("customMenu", "Height")
                            defaultValue: Defaults.chipHeight
                            minimum: 40
                            maximum: 400
                            unit: "px"
                            step: 5
                        }

                        PluginSlider {
                            settingKey: "chipRadius"
                            label: I18n.trFor("customMenu", "Corner radius")
                            description: I18n.trFor("customMenu", "Maximum = half the height: fully round ends")
                            resettable: true
                            defaultValue: sectionRoot.settings.sharedOr("allPieceRadius", Math.round(Theme.cornerRadius))
                            minimum: 0
                            maximum: Math.floor(appChipHeight.value / 2)
                            unit: "px"
                            step: 5
                        }

                        Section {
                            visible: chipEnabled.value
                            key: "appBackground"
                            title: I18n.trFor("customMenu", "Background of each chip")

                            body: Component {
                                Item {

                                    SurfaceStyleSetting {
                                        keyPrefix: "chip"
                                        defaultTransparent: Defaults.chipTransparent
                                        defaultTransparency: Defaults.chipTransparency
                                        defaultLabel: sectionRoot.settings.inheritLabel
                                        label: I18n.trFor("customMenu", "Color")
                                        defaultColor: Theme.chipSurfaceNested
                                    }
                                }
                            }
                        }

                        Section {
                            visible: chipEnabled.value
                            key: "appBorder"
                            title: I18n.trFor("customMenu", "Border of each chip")

                            body: Component {
                                Item {

                                    PluginSlider {
                                        id: chipBorderWidth
                                        settingKey: "chipBorderWidth"
                                        label: I18n.trFor("customMenu", "Width")
                                        description: I18n.trFor("customMenu", "0 = no border")
                                        resettable: true
                                        defaultValue: sectionRoot.settings.sharedOr("allPieceBorderWidth", Defaults.chipBorderWidth)
                                        minimum: 0
                                        maximum: 6
                                        unit: "px"
                                    }

                                    SurfaceStyleSetting {
                                        visible: chipBorderWidth.value > 0
                                        keyPrefix: "chipBorder"
                                        defaultLabel: sectionRoot.settings.inheritLabel
                                        label: I18n.trFor("customMenu", "Color")
                                        defaultColor: Theme.outlineVariant
                                        optionSet: "border"
                                    }
                                }
                            }
                        }

                        Section {
                            visible: appShowLabels.value || appShowDescription.value
                            key: "appText"
                            title: I18n.trFor("customMenu", "Text")

                            body: Component {
                                Item {

                                    SurfaceStyleSetting {
                                        keyPrefix: "appText"
                                        defaultLabel: sectionRoot.settings.inheritLabel
                                        label: I18n.trFor("customMenu", "Color")
                                        defaultColor: Theme.surfaceText
                                        textRoles: true
                                    }

                                    PluginSlider {
                                        settingKey: "textSize"
                                        label: I18n.trFor("customMenu", "Size")
                                        resettable: true
                                        defaultValue: sectionRoot.settings.sharedOr("allPieceTextSize", Defaults.textSize)
                                        minimum: 8
                                        maximum: 32
                                        unit: "px"
                                    }

                                    WeightSetting {
                                        settingKey: "appTextWeight"
                                        inheritLabel: sectionRoot.settings.inheritLabel
                                        defaultValue: sectionRoot.settings.sharedOr("allPieceTextWeight", Defaults.appTextWeight)
                                    }

                                    PluginToggle {
                                        id: appTextBackground
                                        settingKey: "appTextBackground"
                                        label: I18n.trFor("customMenu", "Text background")
                                        description: I18n.trFor("customMenu", "Icon on top: strip along the bottom edge. Icon on the side: behind the text")
                                        defaultValue: Defaults.appTextBackground
                                    }

                                    SurfaceStyleSetting {
                                        visible: appTextBackground.value
                                        keyPrefix: "appTextBg"
                                        defaultLabel: I18n.trFor("customMenu", "Default (Nested chip)")
                                        label: I18n.trFor("customMenu", "Background color")
                                        defaultColor: Theme.chipSurfaceNested
                                    }
                                }
                            }
                        }

                        Section {
                            key: "appIcon"
                            title: I18n.trFor("customMenu", "Icon")

                            body: Component {
                                Item {

                                    SurfaceStyleSetting {
                                        keyPrefix: "fallbackIcon"
                                        defaultLabel: I18n.trFor("customMenu", "Default (Primary Container)")
                                        label: I18n.trFor("customMenu", "Background")
                                        description: I18n.trFor("customMenu", "Letter icon for apps without an icon")
                                        defaultColor: Theme.primaryContainer
                                    }

                                    SurfaceStyleSetting {
                                        keyPrefix: "fallbackLetter"
                                        defaultLabel: I18n.trFor("customMenu", "Default (On Primary Container)")
                                        label: I18n.trFor("customMenu", "Letter")
                                        defaultColor: Theme.onPrimaryContainer
                                        textRoles: true
                                    }

                                    PluginSelection {
                                        settingKey: "editScope"
                                        label: I18n.trFor("customMenu", "Where app changes apply")
                                        description: I18n.trFor("customMenu", "DMS only: same as the DMS launcher. System-wide: a custom desktop file in ~/.local/share/applications; the command can be edited")
                                        options: [
                                            { label: I18n.trFor("customMenu", "DMS only"), value: "dms" },
                                            { label: I18n.trFor("customMenu", "System-wide"), value: "system" }
                                        ]
                                        defaultValue: Defaults.editScope
                                    }

                                    StringSetting {
                                        x: Theme.spacingM
                                        width: parent.width - Theme.spacingM * 2
                                        settingKey: "iconFavorite1"
                                        label: I18n.trFor("customMenu", "Favorite folder") + " 1"
                                        description: I18n.trFor("customMenu", "Quick access in the icon picker (Edit App)")
                                        placeholder: "~/Bilder/Icons"
                                        defaultValue: ""
                                    }

                                    StringSetting {
                                        x: Theme.spacingM
                                        width: parent.width - Theme.spacingM * 2
                                        settingKey: "iconFavorite2"
                                        label: I18n.trFor("customMenu", "Favorite folder") + " 2"
                                        description: ""
                                        placeholder: "~/Bilder/Icons"
                                        defaultValue: ""
                                    }

                                    StringSetting {
                                        x: Theme.spacingM
                                        width: parent.width - Theme.spacingM * 2
                                        settingKey: "iconFavorite3"
                                        label: I18n.trFor("customMenu", "Favorite folder") + " 3"
                                        description: ""
                                        placeholder: "~/Bilder/Icons"
                                        defaultValue: ""
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
