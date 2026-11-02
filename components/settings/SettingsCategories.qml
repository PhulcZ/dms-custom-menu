import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets
import "../../Defaults.js" as Defaults

// ── Categories ──
Section {
    id: sectionRoot
    key: "categories"
    visible: sectionRoot.settings.hasElement("categories")
    title: I18n.trFor("customMenu", "Categories")

    body: Component {
        Item {

            LookResetButton {
                keys: sectionRoot.settings.lookKeys(["catChipBg", "catChipSel", "catChipBorder", "catChipText", "catIcon", "catArea", "catAreaBorder", "catChipHoverBg", "catChipHoverBorder", "catChipHoverText", "catChipSelBorder", "catChipSelText"], ["catChipBorderWidth", "catChipRadius", "catTextSize", "catTextWeight", "catAreaRadius", "catAreaPadding", "catAreaBorderWidth", "catChipHoverTextWeight", "catChipSelTextWeight"])
            }

            AreaSection {
                key: "catArea"
                prefix: "catArea"
                title: I18n.trFor("customMenu", "Background of this categories element")
            }

            AreaBorderSection {
                key: "catAreaBorder"
                prefix: "catArea"
                title: I18n.trFor("customMenu", "Border of this categories element")
            }

            Section {
                visible: sectionRoot.settings.catChips
                key: "catChip"
                title: I18n.trFor("customMenu", "Chips")

                body: Component {
                    Item {

                        PluginSlider {
                            settingKey: "catChipWidth"
                            label: I18n.trFor("customMenu", "Width")
                            description: I18n.trFor("customMenu", "All chips the same width; longer names are truncated")
                            defaultValue: Defaults.catChipWidth
                            minimum: 60
                            maximum: 300
                            unit: "px"
                        }

                        PluginSlider {
                            id: catChipHeight
                            settingKey: "catChipHeight"
                            label: I18n.trFor("customMenu", "Height")
                            defaultValue: Defaults.catChipHeight
                            minimum: 20
                            maximum: 80
                            unit: "px"
                        }

                        PluginSlider {
                            settingKey: "catChipRadius"
                            label: I18n.trFor("customMenu", "Corner radius")
                            description: I18n.trFor("customMenu", "Maximum = half the height: fully round ends")
                            resettable: true
                            defaultValue: sectionRoot.settings.sharedOr("allPieceRadius", Math.round(Theme.cornerRadiusS))
                            minimum: 0
                            maximum: Math.floor(catChipHeight.value / 2)
                            unit: "px"
                        }

                        PluginSlider {
                            settingKey: "catChipSpacing"
                            label: I18n.trFor("customMenu", "Horizontal spacing")
                            defaultValue: Defaults.catChipSpacing
                            minimum: 0
                            maximum: 48
                            unit: "px"
                        }

                        PluginSlider {
                            settingKey: "catChipRowSpacing"
                            label: I18n.trFor("customMenu", "Vertical spacing")
                            description: I18n.trFor("customMenu", "Between rows when the chips wrap")
                            defaultValue: Defaults.catChipRowSpacing
                            minimum: 0
                            maximum: 48
                            unit: "px"
                        }

                        // Where the chips sit while they all fit (horizontally: centred)
                        PluginSelection {
                            settingKey: "catAlignV"
                            label: I18n.trFor("customMenu", "Vertical alignment")
                            description: I18n.trFor("customMenu", "While all chips fit; a scrolling list starts at the top")
                            options: [
                                { label: I18n.trFor("customMenu", "Top"), value: "start" },
                                { label: I18n.trFor("customMenu", "Centered"), value: "center" },
                                { label: I18n.trFor("customMenu", "Bottom"), value: "end" }
                            ]
                            defaultValue: Defaults.catAlignV
                        }


                        Section {
                            visible: sectionRoot.settings.catChips
                            key: "catBackground"
                            title: I18n.trFor("customMenu", "Background of each chip")

                            body: Component {
                                Item {

                                    SurfaceStyleSetting {
                                        keyPrefix: "catChipBg"
                                        defaultLabel: sectionRoot.settings.inheritLabel
                                        label: I18n.trFor("customMenu", "Color")
                                        defaultColor: sectionRoot.settings.lookColor("catChipBg", Theme.chipSurfaceNested)
                                    }
                                }
                            }
                        }

                        Section {
                            visible: sectionRoot.settings.catChips
                            key: "catBorder"
                            title: I18n.trFor("customMenu", "Border of each chip")

                            body: Component {
                                Item {

                                    PluginSlider {
                                        id: catBorderWidth
                                        settingKey: "catChipBorderWidth"
                                        label: I18n.trFor("customMenu", "Width")
                                        description: I18n.trFor("customMenu", "0 = no border")
                                        resettable: true
                                        defaultValue: sectionRoot.settings.sharedOr("allPieceBorderWidth", Defaults.catChipBorderWidth)
                                        minimum: 0
                                        maximum: 6
                                        unit: "px"
                                    }

                                    SurfaceStyleSetting {
                                        visible: catBorderWidth.value > 0
                                        keyPrefix: "catChipBorder"
                                        defaultLabel: sectionRoot.settings.inheritLabel
                                        label: I18n.trFor("customMenu", "Color")
                                        defaultColor: sectionRoot.settings.lookColor("catChipBorder", Theme.outlineVariant)
                                        optionSet: "border"
                                    }
                                }
                            }
                        }

                        Section {
                            visible: sectionRoot.settings.catChips
                            key: "catText"
                            title: I18n.trFor("customMenu", "Text")

                            body: Component {
                                Item {

                                    PluginSelection {
                                        settingKey: "catTextAlign"
                                        label: I18n.trFor("customMenu", "Alignment")
                                        options: [
                                            { label: I18n.trFor("customMenu", "Automatic (one column left, else centered)"), value: "auto" },
                                            { label: I18n.trFor("customMenu", "Left"), value: "left" },
                                            { label: I18n.trFor("customMenu", "Centered"), value: "center" }
                                        ]
                                        defaultValue: Defaults.catTextAlign
                                    }

                                    SurfaceStyleSetting {
                                        keyPrefix: "catChipText"
                                        defaultLabel: sectionRoot.settings.inheritLabel
                                        label: I18n.trFor("customMenu", "Color")
                                        defaultColor: sectionRoot.settings.lookColor("catChipText", Theme.onSurfaceVariant)
                                        textRoles: true
                                    }

                                    PluginSlider {
                                        settingKey: "catTextSize"
                                        label: I18n.trFor("customMenu", "Size")
                                        resettable: true
                                        defaultValue: sectionRoot.settings.sharedOr("allPieceTextSize", Theme.fontSizeSmall)
                                        minimum: 8
                                        maximum: 28
                                        unit: "px"
                                    }

                                    WeightSetting {
                                        settingKey: "catTextWeight"
                                        inheritLabel: sectionRoot.settings.inheritLabel
                                        defaultValue: sectionRoot.settings.sharedOr("allPieceTextWeight", Defaults.catTextWeight)
                                    }
                                }
                            }
                        }

                        Section {
                            visible: sectionRoot.settings.catChips
                            key: "catIcon"
                            title: I18n.trFor("customMenu", "Icon")

                            body: Component {
                                Item {

                                    PluginToggle {
                                        id: catShowIcons
                                        settingKey: "catShowIcons"
                                        label: I18n.trFor("customMenu", "Show icons")
                                        defaultValue: Defaults.catShowIcons
                                    }

                                    PluginSlider {
                                        visible: catShowIcons.value
                                        settingKey: "catIconSize"
                                        label: I18n.trFor("customMenu", "Size")
                                        defaultValue: Defaults.catIconSize
                                        minimum: 10
                                        maximum: 40
                                        unit: "px"
                                    }

                                    SurfaceStyleSetting {
                                        visible: catShowIcons.value
                                        keyPrefix: "catIcon"
                                        // Colour of all category icons; not tied to the text colour.
                                        // Per category below (icon list).
                                        defaultLabel: sectionRoot.settings.inheritLabel
                                        label: I18n.trFor("customMenu", "Color of all icons")
                                        defaultColor: Theme.onSurfaceVariant
                                        textRoles: true
                                    }

                                    CategoryIconList {
                                        visible: catShowIcons.value
                                        suggestions: Defaults.iconSuggestions.category
                                    }
                                }
                            }
                        }

                            // On mouse hover: differs from the normal chip where set
                            Section {
                                visible: sectionRoot.settings.catChips
                                key: "catHover"
                                title: I18n.trFor("customMenu", "On hover")

                                body: Component {
                                    Item {

                                        SurfaceStyleSetting {
                                            keyPrefix: "catChipHoverBg"
                                            defaultLabel: I18n.trFor("customMenu", "Default (DMS hover)")
                                            label: I18n.trFor("customMenu", "Background color")
                                            defaultColor: sectionRoot.settings.lookColor("catChipHoverBg", Theme.withAlpha(Theme.onSurface, Theme.stateLayerHover))
                                        }
                                        SurfaceStyleSetting {
                                            keyPrefix: "catChipHoverBorder"
                                            defaultLabel: I18n.trFor("customMenu", "Same as normal chips")
                                            label: I18n.trFor("customMenu", "Border color")
                                            defaultColor: sectionRoot.settings.lookColor("catChipHoverBorder", Theme.outlineVariant)
                                            optionSet: "border"
                                        }
                                        SurfaceStyleSetting {
                                            keyPrefix: "catChipHoverText"
                                            defaultLabel: I18n.trFor("customMenu", "Same as normal chips")
                                            label: I18n.trFor("customMenu", "Text color")
                                            defaultColor: sectionRoot.settings.lookColor("catChipHoverText", Theme.onSurfaceVariant)
                                            textRoles: true
                                        }
                                        WeightSetting {
                                            settingKey: "catChipHoverTextWeight"
                                            label: I18n.trFor("customMenu", "Font weight")
                                            inheritLabel: I18n.trFor("customMenu", "Same as normal chips")
                                        }
                                    }
                                }
                            }

                            // Selected category: differs from the normal chip where set
                            Section {
                                visible: sectionRoot.settings.catChips
                                key: "catSelected"
                                title: I18n.trFor("customMenu", "Selected category")

                                body: Component {
                                    Item {

                                        SurfaceStyleSetting {
                                            keyPrefix: "catChipSel"
                                            defaultLabel: sectionRoot.settings.inheritLabel
                                            label: I18n.trFor("customMenu", "Background color")
                                            defaultColor: sectionRoot.settings.lookColor("catChipSel", Theme.secondaryContainer)
                                        }
                                        SurfaceStyleSetting {
                                            keyPrefix: "catChipSelBorder"
                                            defaultLabel: I18n.trFor("customMenu", "Default (no border)")
                                            label: I18n.trFor("customMenu", "Border color")
                                            defaultColor: sectionRoot.settings.lookColor("catChipSelBorder", "transparent")
                                            optionSet: "border"
                                        }
                                        SurfaceStyleSetting {
                                            keyPrefix: "catChipSelText"
                                            defaultLabel: I18n.trFor("customMenu", "Default (DMS)")
                                            label: I18n.trFor("customMenu", "Text color")
                                            defaultColor: sectionRoot.settings.lookColor("catChipSelText", Theme.onSecondaryContainer)
                                            textRoles: true
                                        }
                                        WeightSetting {
                                            settingKey: "catChipSelTextWeight"
                                            label: I18n.trFor("customMenu", "Font weight")
                                            inheritLabel: I18n.trFor("customMenu", "Same as normal chips")
                                        }
                                    }
                                }
                            }
                    }
                }
            }

            // Behaviour of the categories element
            Section {
                key: "catBehaviour"
                title: I18n.trFor("customMenu", "Behavior")

                body: Component {
                    Item {

                        PluginSelection {
                            id: categoryStyle
                            settingKey: "categoryStyle"
                            label: I18n.trFor("customMenu", "Style")
                            options: [
                                { label: I18n.trFor("customMenu", "Chips"), value: "chips" },
                                { label: I18n.trFor("customMenu", "Dropdown"), value: "dropdown" }
                            ]
                            defaultValue: Defaults.categoryStyle
                        }

                        // Category shown when the menu opens; the list as the menu
                        // shows it (reported by the menu of the edited instance)
                        PluginSelection {
                            readonly property var choices: PluginService.globalVars[sectionRoot.settings.pluginId]?.["categoryChoices_" + (sectionRoot.settings.editInstance || "main")] ?? []
                            settingKey: "startCategory"
                            label: I18n.trFor("customMenu", "Initial category")
                            description: I18n.trFor("customMenu", "Shown each time the menu opens. Without a categories element, all apps are shown.")
                            options: choices.length > 0 ? choices.map(c => ({ "label": c.text, "value": c.key })) : [{ "label": I18n.trFor("customMenu", "All"), "value": "__all" }]
                            defaultValue: Defaults.startCategory
                        }

                        PluginSelection {
                            settingKey: "categoryScope"
                            label: I18n.trFor("customMenu", "Assignments apply to")
                            description: I18n.trFor("customMenu", "Apps dragged onto a category or onto \"Hidden\". Both: also in the DMS launcher (custom desktop file in ~/.local/share/applications, hidden via DMS). Custom categories exist only in CustomMenu.")
                            options: [
                                { label: I18n.trFor("customMenu", "CustomMenu and DMS launcher"), value: "both" },
                                { label: I18n.trFor("customMenu", "CustomMenu only"), value: "menu" }
                            ]
                            defaultValue: Defaults.categoryScope
                        }

                        PluginToggle {
                            settingKey: "showHiddenCategory"
                            label: I18n.trFor("customMenu", "Show \"Hidden\"")
                            description: I18n.trFor("customMenu", "Hidden apps; right-click to show them again")
                            defaultValue: Defaults.showHiddenCategory
                        }
                    }
                }
            }

            // Sub-category headings: like the result sections (Search ›
            // Result sections) unless set here
            Section {
                key: "catSub"
                title: I18n.trFor("customMenu", "Subcategories")

                body: Component {
                    Item {

                        StyledText {
                            x: Theme.spacingM
                            width: parent.width - Theme.spacingM * 2
                            wrapMode: Text.WordWrap
                            text: I18n.trFor("customMenu", "Created in the category editor (pencil on the categories element). Their headings look like the search result sections unless set otherwise here.")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                        PluginSlider {
                            settingKey: "subTitleSize"
                            label: I18n.trFor("customMenu", "Heading size")
                            resettable: true
                            unsetText: I18n.trFor("customMenu", "same as result sections")
                            defaultValue: sectionRoot.settings.effectiveValue("secTitleSize", (sectionRoot.settings.effectiveValue("textSize", undefined) ?? sectionRoot.settings.sharedOr("allPieceTextSize", Theme.fontSizeSmall)) + 2)
                            minimum: 8
                            maximum: 28
                            unit: "px"
                        }
                        PluginSelection {
                            settingKey: "subTitleWeight"
                            label: I18n.trFor("customMenu", "Weight")
                            options: [
                                { label: I18n.trFor("customMenu", "Same as result sections"), value: "" },
                                { label: I18n.trFor("customMenu", "Normal"), value: "normal" },
                                { label: I18n.trFor("customMenu", "Medium"), value: "medium" },
                                { label: I18n.trFor("customMenu", "Bold"), value: "bold" }
                            ]
                            defaultValue: ""
                        }
                        SurfaceStyleSetting {
                            keyPrefix: "subTitle"
                            label: I18n.trFor("customMenu", "Heading color")
                            defaultLabel: I18n.trFor("customMenu", "Same as result sections")
                            defaultColor: Theme.surfaceText
                        }
                        PluginToggle {
                            id: subLineShow
                            settingKey: "subLineShow"
                            label: I18n.trFor("customMenu", "Line after the heading")
                            defaultValue: sectionRoot.settings.effectiveValue("secLineShow", true)
                        }
                        SurfaceStyleSetting {
                            visible: subLineShow.value
                            keyPrefix: "subLine"
                            label: I18n.trFor("customMenu", "Line color")
                            defaultLabel: I18n.trFor("customMenu", "Same as result sections")
                            defaultColor: Theme.outlineVariant
                            optionSet: "border"
                        }
                        PluginSlider {
                            settingKey: "subGap"
                            label: I18n.trFor("customMenu", "Space between subcategories")
                            resettable: true
                            unsetText: I18n.trFor("customMenu", "same as result sections")
                            defaultValue: sectionRoot.settings.effectiveValue("secGap", sectionRoot.settings.effectiveValue("appRowSpacing", Defaults.appRowSpacing))
                            minimum: 0
                            maximum: 48
                            unit: "px"
                        }
                        PluginSlider {
                            settingKey: "subTitleGap"
                            label: I18n.trFor("customMenu", "Space below the heading")
                            resettable: true
                            unsetText: I18n.trFor("customMenu", "same as result sections")
                            defaultValue: sectionRoot.settings.effectiveValue("secTitleGap", Defaults.secTitleGap)
                            minimum: 0
                            maximum: 32
                            unit: "px"
                        }
                    }
                }
            }
        }
    }




}
