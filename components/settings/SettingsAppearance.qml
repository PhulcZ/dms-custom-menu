import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets
import "../../Defaults.js" as Defaults

// ── Appearance: the shared look of the elements ──
// Shared look of all elements; each element section shows
// "Default (same as Appearance)" and may deviate
Section {
    id: sectionRoot
    key: "elementLook"
    title: I18n.trFor("customMenu", "Appearance of the four levels")

    body: Component {
        Item {

            StyledText {
                x: Theme.spacingM
                width: parent.width - Theme.spacingM * 2
                wrapMode: Text.WordWrap
                text: I18n.trFor("customMenu", "Applies to all elements (apps, categories, search, tiles) unless an element sets its own value. If not set here, each element uses its own default.")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            // ── Appearance: the four levels, each with background and border
            // (level 4 also text and icon). Unset values follow DMS'
            // surface of the same level.

            // Level 1: the rearmost surface, DMS' popout surface or an own one
            Section {
                key: "menuSurface"
                title: I18n.trFor("customMenu", "Level 1 · Background")

                body: Component {
                    Item {

                        StyledText {
                            x: Theme.spacingM
                            width: parent.width - Theme.spacingM * 2
                            wrapMode: Text.WordWrap
                            text: I18n.trFor("customMenu", "The menu's backmost surface (behind the canvas). Default: DMS' popout surface with its blur; corner radius, border and blur then come from DMS. Any other color replaces it with a custom surface; a docked menu is detached for this, because DMS draws it as part of its frame.")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        Section {
                            key: "menuSurfaceBg"
                            title: I18n.trFor("customMenu", "Background")

                            body: Component {
                                Item {

                                    SurfaceStyleSetting {
                                        id: menuSurfaceStyle
                                        keyPrefix: "menuSurface"
                                        label: I18n.trFor("customMenu", "Color")
                                        defaultLabel: I18n.trFor("customMenu", "Default (DMS level 1 host)")
                                        defaultColor: Theme.readableSurface
                                    }
                                    PluginToggle {
                                        enabled: (sectionRoot.settings.effectiveValue("menuSurfaceColorMode", "default") !== "default" || (sectionRoot.settings.effectiveValue("menuSurfaceTransparent", false) === true && sectionRoot.settings.effectiveValue("menuSurfaceTransparency", 0) > 0)) && sectionRoot.settings.effectiveValue("menuSurfaceColorMode", "default") !== "none"
                                        opacity: enabled ? 1 : 0.5
                                        settingKey: "menuSurfaceTransparentEmptyOnly"
                                        label: I18n.trFor("customMenu", "Transparent only without windows")
                                        description: I18n.trFor("customMenu", "Transparent only while no windows are open on the menu's screen (the wallpaper is visible); otherwise opaque. DMS' settings window does not count.")
                                        defaultValue: false
                                    }
                                    // Opaque because of windows: texts and icons in their
                                    // normal colours (readable on the opaque surface)
                                    PluginToggle {
                                        enabled: sectionRoot.settings.effectiveValue("menuSurfaceTransparentEmptyOnly", false) === true
                                        opacity: enabled ? 1 : 0.5
                                        settingKey: "menuSurfaceNormalTextWithWindows"
                                        label: I18n.trFor("customMenu", "Default text colors with open windows")
                                        description: I18n.trFor("customMenu", "While the surface is opaque because windows are open, texts, icons and headings use their default colors instead of the custom ones (DMS' settings window does not count)")
                                        defaultValue: false
                                    }
                                    PluginSlider {
                                        enabled: (sectionRoot.settings.effectiveValue("menuSurfaceColorMode", "default") !== "default" || (sectionRoot.settings.effectiveValue("menuSurfaceTransparent", false) === true && sectionRoot.settings.effectiveValue("menuSurfaceTransparency", 0) > 0))
                                        opacity: enabled ? 1 : 0.5
                                        settingKey: "menuSurfaceRadius"
                                        label: I18n.trFor("customMenu", "Corner radius")
                                        resettable: true
                                        defaultValue: Math.round(Theme.windowRadius)
                                        minimum: 0
                                        maximum: 48
                                        unit: "px"
                                    }
                                    PluginSelection {
                                        enabled: (sectionRoot.settings.effectiveValue("menuSurfaceColorMode", "default") !== "default" || (sectionRoot.settings.effectiveValue("menuSurfaceTransparent", false) === true && sectionRoot.settings.effectiveValue("menuSurfaceTransparency", 0) > 0)) && sectionRoot.settings.effectiveValue("menuSurfaceColorMode", "default") !== "none"
                                        opacity: enabled ? 1 : 0.5
                                        settingKey: "menuSurfaceBlur"
                                        label: I18n.trFor("customMenu", "Background blur")
                                        options: [
                                            { label: I18n.trFor("customMenu", "Same as DMS"), value: "dms" },
                                            { label: I18n.trFor("customMenu", "Off"), value: "off" }
                                        ]
                                        defaultValue: "dms"
                                    }
                                }
                            }
                        }

                        Section {
                            key: "menuSurfaceBorder"
                            title: I18n.trFor("customMenu", "Border")

                            body: Component {
                                Item {

                                    PluginSlider {
                                        enabled: (sectionRoot.settings.effectiveValue("menuSurfaceColorMode", "default") !== "default" || (sectionRoot.settings.effectiveValue("menuSurfaceTransparent", false) === true && sectionRoot.settings.effectiveValue("menuSurfaceTransparency", 0) > 0))
                                        opacity: enabled ? 1 : 0.5
                                        settingKey: "menuSurfaceBorderWidth"
                                        label: I18n.trFor("customMenu", "Width")
                                        description: I18n.trFor("customMenu", "0 = no border")
                                        defaultValue: 0
                                        minimum: 0
                                        maximum: 6
                                        unit: "px"
                                    }
                                    SurfaceStyleSetting {
                                        enabled: (sectionRoot.settings.effectiveValue("menuSurfaceColorMode", "default") !== "default" || (sectionRoot.settings.effectiveValue("menuSurfaceTransparent", false) === true && sectionRoot.settings.effectiveValue("menuSurfaceTransparency", 0) > 0))
                                        opacity: enabled ? 1 : 0.5
                                        keyPrefix: "menuSurfaceBorder"
                                        label: I18n.trFor("customMenu", "Color")
                                        defaultLabel: I18n.trFor("customMenu", "Default (Outline)")
                                        defaultColor: Theme.outlineVariant
                                        optionSet: "border"
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Level 2: the canvas behind the elements (its corner radius
            // follows the menu surface, see the widget's card)
            Section {
                key: "card"
                title: I18n.trFor("customMenu", "Level 2 · Canvas")

                body: Component {
                    Item {

                        Section {
                            key: "cardBg"
                            title: I18n.trFor("customMenu", "Background")

                            body: Component {
                                Item {

                                    SurfaceStyleSetting {
                                        keyPrefix: "card"
                                        defaultTransparent: Defaults.cardTransparent
                                        defaultTransparency: Defaults.cardTransparency
                                        defaultLabel: I18n.trFor("customMenu", "Default (DMS level 2 cards)")
                                        label: I18n.trFor("customMenu", "Color")
                                        defaultColor: Theme.cardSurface
                                    }
                                    StyledText {
                                        x: Theme.spacingM
                                        width: parent.width - Theme.spacingM * 2
                                        wrapMode: Text.WordWrap
                                        text: I18n.trFor("customMenu", "The corner radius follows the menu surface (its radius minus the gap between them, so both curves run parallel).")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }
                                    PluginToggle {
                                        settingKey: "cardBlur"
                                        label: I18n.trFor("customMenu", "Background blur")
                                        description: I18n.trFor("customMenu", "Blurs whatever is behind the canvas, following its shape. Visible only with a custom, translucent menu surface (Appearance › Level 1).")
                                        defaultValue: false
                                    }
                                }
                            }
                        }

                        Section {
                            key: "cardBorder"
                            title: I18n.trFor("customMenu", "Border")

                            body: Component {
                                Item {

                                    PluginSlider {
                                        settingKey: "cardBorderWidth"
                                        label: I18n.trFor("customMenu", "Width")
                                        description: I18n.trFor("customMenu", "0 = no border")
                                        defaultValue: Defaults.cardBorderWidth
                                        minimum: 0
                                        maximum: 6
                                        unit: "px"
                                    }
                                    SurfaceStyleSetting {
                                        keyPrefix: "cardBorder"
                                        defaultLabel: I18n.trFor("customMenu", "Default (Outline)")
                                        label: I18n.trFor("customMenu", "Color")
                                        defaultColor: Theme.outlineVariant
                                        optionSet: "border"
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Level 3: background and border of all elements
            Section {
                key: "level3"
                title: I18n.trFor("customMenu", "Level 3 · Elements")

                body: Component {
                    Item {

                        PluginToggle {
                            settingKey: "scrollFade"
                            label: I18n.trFor("customMenu", "Fade edges when scrolling")
                            description: I18n.trFor("customMenu", "Scrolling content fades out at the top and bottom of the element")
                            defaultValue: Defaults.scrollFade
                        }

                        AreaSection {
                            key: "allArea"
                            prefix: "allArea"
                            title: I18n.trFor("customMenu", "Background")
                            showPadding: false
                        }

                        AreaBorderSection {
                            key: "allAreaBorder"
                            prefix: "allArea"
                            title: I18n.trFor("customMenu", "Border")
                        }
                    }
                }
            }

            // Level 4: chips, tiles, search field (unset: each element's own default)
            Section {
                key: "allPiece"
                title: I18n.trFor("customMenu", "Level 4 · Chips, tiles, search field")

                body: Component {
                    Item {

                        Section {
                            key: "allPieceBg"
                            title: I18n.trFor("customMenu", "Background")

                            body: Component {
                                Item {

                                    SurfaceStyleSetting {
                                        keyPrefix: "allPiece"
                                        defaultLabel: I18n.trFor("customMenu", "Default (DMS level 4 nested chip)")
                                        label: I18n.trFor("customMenu", "Color")
                                        defaultColor: Theme.chipSurfaceNested
                                    }
                                    PluginToggle {
                                        settingKey: "allPieceBlur"
                                        label: I18n.trFor("customMenu", "Background blur")
                                        description: I18n.trFor("customMenu", "Blurs whatever is behind each chip, tile and the search field, following its shape. Visible only with a custom, translucent menu surface (Appearance › Level 1) and translucent levels in between.")
                                        defaultValue: false
                                    }
                                    PluginSlider {
                                        settingKey: "allPieceRadius"
                                        label: I18n.trFor("customMenu", "Corner radius")
                                        description: I18n.trFor("customMenu", "Limited to half the height of each chip or tile (fully round)")
                                        unsetText: I18n.trFor("customMenu", "not set")
                                        resettable: true
                                        defaultValue: Math.round(Theme.cornerRadius)
                                        minimum: 0
                                        maximum: 100
                                        unit: "px"
                                    }

                                    // Selected chips (e.g. the active category): own sub-point, so it is not
                                    // mistaken for the colour of all chips above
                                    Section {
                                        key: "allPieceSelSec"
                                        title: I18n.trFor("customMenu", "Selected")

                                        body: Component {
                                            Item {

                                                SurfaceStyleSetting {
                                                    keyPrefix: "allPieceSel"
                                                    defaultLabel: I18n.trFor("customMenu", "Not set (element default)")
                                                    label: I18n.trFor("customMenu", "Color")
                                                    defaultColor: Theme.secondaryContainer
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Section {
                            key: "allPieceBorderSec"
                            title: I18n.trFor("customMenu", "Border")

                            body: Component {
                                Item {

                                    PluginSlider {
                                        settingKey: "allPieceBorderWidth"
                                        label: I18n.trFor("customMenu", "Width")
                                        unsetText: I18n.trFor("customMenu", "not set")
                                        resettable: true
                                        defaultValue: 0
                                        minimum: 0
                                        maximum: 6
                                        unit: "px"
                                    }
                                    SurfaceStyleSetting {
                                        keyPrefix: "allPieceBorder"
                                        defaultLabel: I18n.trFor("customMenu", "Not set (element default)")
                                        label: I18n.trFor("customMenu", "Color")
                                        defaultColor: Theme.outlineVariant
                                        optionSet: "border"
                                    }
                                }
                            }
                        }

                        Section {
                            key: "allPieceTextSec"
                            title: I18n.trFor("customMenu", "Text")

                            body: Component {
                                Item {

                                    SurfaceStyleSetting {
                                        keyPrefix: "allPieceText"
                                        defaultLabel: I18n.trFor("customMenu", "Not set (element default)")
                                        label: I18n.trFor("customMenu", "Color")
                                        defaultColor: Theme.surfaceText
                                    }
                                    PluginSlider {
                                        settingKey: "allPieceTextSize"
                                        label: I18n.trFor("customMenu", "Size")
                                        unsetText: I18n.trFor("customMenu", "not set")
                                        resettable: true
                                        defaultValue: 13
                                        minimum: 8
                                        maximum: 28
                                        unit: "px"
                                    }
                                    WeightSetting {
                                        settingKey: "allPieceTextWeight"
                                        inheritLabel: I18n.trFor("customMenu", "Not set (element default)")
                                        defaultValue: "normal"
                                    }
                                }
                            }
                        }

                        Section {
                            key: "allPieceIconSec"
                            title: I18n.trFor("customMenu", "Icon")

                            body: Component {
                                Item {

                                    SurfaceStyleSetting {
                                        keyPrefix: "allPieceIcon"
                                        defaultLabel: I18n.trFor("customMenu", "Not set (element default)")
                                        label: I18n.trFor("customMenu", "Color")
                                        defaultColor: Theme.onSurfaceVariant
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
