import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets
import "../../Defaults.js" as Defaults

// ── Tiles ──
// Look of the tile elements (apps and buttons); the tiles themselves
// are managed in the menu (edit mode, element pen)
Section {
    id: sectionRoot
    key: "tiles"
    visible: sectionRoot.settings.hasElement("tiles")
    title: I18n.trFor("customMenu", "Tiles")

    body: Component {
        Item {
            StyledText {
                x: Theme.spacingM
                width: parent.width - Theme.spacingM * 2
                wrapMode: Text.WordWrap
                text: I18n.trFor("customMenu", "Apps and buttons as tiles, independent of category and search. Add an element with \"+\" in edit mode; its pencil edits the tiles and the arrangement (grid or row).")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            // Shared look or one element's own values
            Row {
                x: Theme.spacingM
                spacing: Theme.spacingS
                visible: sectionRoot.settings.tileElements.length > 0

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.trFor("customMenu", "Style for")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                }
                DDropdown {
                    id: tileScopeChoice
                    anchors.verticalCenter: parent.verticalCenter
                    width: 280
                    readonly property string allLabel: I18n.trFor("customMenu", "All tile elements")
                    readonly property string shown: sectionRoot.settings.tileScope ? (sectionRoot.settings.tileElements.find(e => e.id === sectionRoot.settings.tileScope)?.name ?? allLabel) : allLabel
                    options: [allLabel].concat(sectionRoot.settings.tileElements.map(e => e.name))
                    currentValue: shown
                    // DDropdown assigns its value on picks (breaks the binding)
                    onShownChanged: currentValue = shown
                    onValueChanged: value => {
                        const e = sectionRoot.settings.tileElements.find(x => x.name === value);
                        sectionRoot.settings.selectTileScope(e ? e.id : "");
                    }
                }
                DButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: sectionRoot.settings.tileScopeHasOwn
                    iconName: "restart_alt"
                    text: I18n.trFor("customMenu", "Same as all")
                    onClicked: sectionRoot.settings.resetTileScope()
                }
            }
            StyledText {
                x: Theme.spacingM
                width: parent.width - Theme.spacingM * 2
                visible: sectionRoot.settings.tileScope !== ""
                wrapMode: Text.WordWrap
                text: I18n.trFor("customMenu", "Changes below apply only to this element; anything it does not set itself follows the style for all.")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.tertiary
            }

            // Where the tiles of a row sit in a bigger element
            PluginSelection {
                settingKey: "tlAlignH"
                label: I18n.trFor("customMenu", "Horizontal alignment")
                description: I18n.trFor("customMenu", "Arrangement \"Row\" only")
                options: [
                    { label: I18n.trFor("customMenu", "Left"), value: "start" },
                    { label: I18n.trFor("customMenu", "Centered"), value: "center" },
                    { label: I18n.trFor("customMenu", "Right"), value: "end" }
                ]
                defaultValue: Defaults.tlAlignH
            }
            PluginSelection {
                settingKey: "tlAlignV"
                label: I18n.trFor("customMenu", "Vertical alignment")
                description: I18n.trFor("customMenu", "Arrangement \"Row\" only: where the tiles sit when the element is bigger than them")
                options: [
                    { label: I18n.trFor("customMenu", "Top"), value: "start" },
                    { label: I18n.trFor("customMenu", "Centered"), value: "center" },
                    { label: I18n.trFor("customMenu", "Bottom"), value: "end" }
                ]
                defaultValue: Defaults.tlAlignV
            }

            // Center the content: sets the alignment to centred and
            // moves the occupied tiles of grid elements to the middle
            // of their cells (the menu does that, it knows the cells)
            Flow {
                x: Theme.spacingM
                width: parent.width - Theme.spacingM * 2
                spacing: Theme.spacingS
                DButton {
                    iconName: "align_horizontal_center"
                    text: I18n.trFor("customMenu", "Center content horizontally")
                    onClicked: sectionRoot.settings.centerTileContent("h")
                }
                DButton {
                    iconName: "align_vertical_center"
                    text: I18n.trFor("customMenu", "Center content vertically")
                    onClicked: sectionRoot.settings.centerTileContent("v")
                }
            }

            LookResetButton {
                keys: sectionRoot.settings.lookKeys(["tlTile", "tlTileBorder", "tlText", "tlIcon", "tlArea", "tlAreaBorder"], ["tlTileRadius", "tlTileBorderWidth", "tlTextSize", "tlTextWeight", "tlAreaRadius", "tlAreaPadding", "tlAreaBorderWidth"])
            }

            AreaSection {
                key: "tlArea"
                prefix: "tlArea"
                title: sectionRoot.settings.tileScope ? I18n.trFor("customMenu", "Background of this tile element") : I18n.trFor("customMenu", "Background of the tile elements")
                scopeNote: sectionRoot.settings.tileScope ? I18n.trFor("customMenu", "Applies only to the tile element selected above under \"Style for\".") : I18n.trFor("customMenu", "Applies to all tile elements (select one above under \"Style for\").")
            }

            AreaBorderSection {
                key: "tlAreaBorder"
                prefix: "tlArea"
                title: sectionRoot.settings.tileScope ? I18n.trFor("customMenu", "Border of this tile element") : I18n.trFor("customMenu", "Border of the tile elements")
                scopeNote: sectionRoot.settings.tileScope ? I18n.trFor("customMenu", "Applies only to the tile element selected above under \"Style for\".") : I18n.trFor("customMenu", "Applies to all tile elements (select one above under \"Style for\").")
            }

            Section {
                key: "tlTiles"
                title: I18n.trFor("customMenu", "Tile")

                body: Component {
                    Item {

                        PluginSlider {
                            settingKey: "tlUnit"
                            label: I18n.trFor("customMenu", "Inner grid cell")
                            description: I18n.trFor("customMenu", "Size of one cell; tiles: small 1 × 1, large 2 × 2 cells. The element sizes itself to its tiles; in edit mode its width sets the cells per row.")
                            defaultValue: Defaults.scUnit
                            minimum: 16
                            maximum: 96
                            unit: "px"
                        }

                        PluginSlider {
                            settingKey: "tlIconPadSmall"
                            label: I18n.trFor("customMenu", "Icon margin, small tiles")
                            description: I18n.trFor("customMenu", "Space between icon and tile edge; less = larger icon")
                            defaultValue: Defaults.scIconPadSmall
                            minimum: 0
                            maximum: 24
                            unit: "px"
                        }

                        PluginSlider {
                            settingKey: "tlIconPadLarge"
                            label: I18n.trFor("customMenu", "Icon margin, large tiles")
                            defaultValue: Defaults.scIconPadLarge
                            minimum: 0
                            maximum: 48
                            unit: "px"
                        }

                        PluginSlider {
                            settingKey: "tlSpacing"
                            label: I18n.trFor("customMenu", "Spacing between tiles")
                            defaultValue: Defaults.scSpacing
                            minimum: 0
                            maximum: 64
                            unit: "px"
                        }
                        SurfaceStyleSetting {
                            keyPrefix: "tlTile"
                            defaultLabel: sectionRoot.settings.inheritLabel
                            label: I18n.trFor("customMenu", "Tile background")
                            defaultColor: Theme.chipSurfaceNested
                        }

                        PluginSlider {
                            settingKey: "tlTileRadius"
                            label: I18n.trFor("customMenu", "Corner radius")
                            resettable: true
                            defaultValue: sectionRoot.settings.sharedOr("allPieceRadius", Math.round(Theme.cornerRadius))
                            minimum: 0
                            maximum: 100
                            unit: "px"
                        }

                        PluginSlider {
                            id: tlTileBorderWidth
                            settingKey: "tlTileBorderWidth"
                            label: I18n.trFor("customMenu", "Border width")
                            description: I18n.trFor("customMenu", "0 = no border")
                            resettable: true
                            defaultValue: sectionRoot.settings.sharedOr("allPieceBorderWidth", 0)
                            minimum: 0
                            maximum: 6
                            unit: "px"
                        }

                        SurfaceStyleSetting {
                            visible: tlTileBorderWidth.value > 0
                            keyPrefix: "tlTileBorder"
                            defaultLabel: sectionRoot.settings.inheritLabel
                            label: I18n.trFor("customMenu", "Border color")
                            defaultColor: Theme.outlineVariant
                            optionSet: "border"
                        }
                    }
                }
            }

            Section {
                key: "tlText"
                title: I18n.trFor("customMenu", "Text")

                body: Component {
                    Item {

                        PluginToggle {
                            settingKey: "tlShowLabels"
                            label: I18n.trFor("customMenu", "Show names")
                            description: I18n.trFor("customMenu", "On large tiles")
                            defaultValue: Defaults.scShowLabels
                        }
                        PluginToggle {
                            settingKey: "tlTooltips"
                            label: I18n.trFor("customMenu", "Tooltips")
                            description: I18n.trFor("customMenu", "Name (for apps also the description) when hovering over a tile")
                            defaultValue: Defaults.scTooltips
                        }
                        PluginSlider {
                            settingKey: "tlTextSize"
                            label: I18n.trFor("customMenu", "Size")
                            resettable: true
                            defaultValue: sectionRoot.settings.sharedOr("allPieceTextSize", Defaults.scTextSize)
                            minimum: 8
                            maximum: 28
                            unit: "px"
                        }

                        WeightSetting {
                            settingKey: "tlTextWeight"
                            inheritLabel: sectionRoot.settings.inheritLabel
                            defaultValue: sectionRoot.settings.sharedOr("allPieceTextWeight", "normal")
                        }
                        SurfaceStyleSetting {
                            keyPrefix: "tlText"
                            defaultLabel: sectionRoot.settings.inheritLabel
                            label: I18n.trFor("customMenu", "Color")
                            defaultColor: Theme.surfaceText
                        }
                        PluginSelection {
                            id: tlTitleSide
                            settingKey: "tlTitleSide"
                            label: I18n.trFor("customMenu", "Title position")
                            options: [
                                { label: I18n.trFor("customMenu", "Top"), value: "top" },
                                { label: I18n.trFor("customMenu", "Bottom"), value: "bottom" },
                                { label: I18n.trFor("customMenu", "Left"), value: "left" },
                                { label: I18n.trFor("customMenu", "Right"), value: "right" }
                            ]
                            defaultValue: Defaults.scTitleSide
                        }

                        PluginSelection {
                            readonly property bool across: tlTitleSide.value === "left" || tlTitleSide.value === "right"
                            settingKey: "tlTitleAlign"
                            label: I18n.trFor("customMenu", "Title alignment")
                            options: [
                                { label: across ? I18n.trFor("customMenu", "Top") : I18n.trFor("customMenu", "Left"), value: "start" },
                                { label: I18n.trFor("customMenu", "Centered"), value: "center" },
                                { label: across ? I18n.trFor("customMenu", "Bottom") : I18n.trFor("customMenu", "Right"), value: "end" }
                            ]
                            defaultValue: Defaults.scTitleAlign
                        }

                        PluginSlider {
                            settingKey: "tlTitleGap"
                            label: I18n.trFor("customMenu", "Title spacing")
                            description: I18n.trFor("customMenu", "On both sides of the title: to the frame and to the tiles; the title sits in the middle")
                            defaultValue: Defaults.scTitleGap
                            minimum: 0
                            maximum: 32
                            unit: "px"
                        }

                        PluginSlider {
                            settingKey: "tlTitleSize"
                            label: I18n.trFor("customMenu", "Group title size")
                            defaultValue: Defaults.scTitleSize
                            minimum: 8
                            maximum: 32
                            unit: "px"
                        }
                        SurfaceStyleSetting {
                            keyPrefix: "tlTitle"
                            defaultLabel: I18n.trFor("customMenu", "Default (Text)")
                            label: I18n.trFor("customMenu", "Group title color")
                            defaultColor: Theme.surfaceText
                        }
                    }
                }
            }

            // Colour of all symbol icons in the tiles (as Categories › Chips › Icon)
            Section {
                key: "tlIcon"
                title: I18n.trFor("customMenu", "Icon")

                body: Component {
                    Item {
                        SurfaceStyleSetting {
                            keyPrefix: "tlIcon"
                            defaultLabel: sectionRoot.settings.inheritLabel
                            label: I18n.trFor("customMenu", "Color of all icons")
                            description: I18n.trFor("customMenu", "Symbol icons only (e.g. buttons); app icons keep their colors. An app's own color (right-click) takes precedence.")
                            defaultColor: Theme.surfaceText
                            textRoles: true
                        }
                    }
                }
            }
        }
    }
}
