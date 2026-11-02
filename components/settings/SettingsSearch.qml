import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets
import "../../Defaults.js" as Defaults

// ── Search ──
Section {
    id: sectionRoot
    key: "search"
    visible: sectionRoot.settings.hasElement("search")
    title: I18n.trFor("customMenu", "Search")

    body: Component {
        Item {

            LookResetButton {
                keys: sectionRoot.settings.lookKeys(["searchBg", "searchBorder", "searchPlaceholder", "searchIcon", "searchArea", "searchAreaBorder", "scopeChipBg", "scopeChipBorder", "scopeChipText", "scopeChipHoverBg", "scopeChipHoverBorder", "scopeChipHoverText", "scopeChipSel", "scopeChipSelBorder", "scopeChipSelText"], ["searchBorderWidth", "searchRadius", "searchTextSize", "searchTextWeight", "searchAreaRadius", "searchAreaPadding", "searchAreaBorderWidth", "scopeChipHeight", "scopeChipRadius", "scopeChipSpacing", "scopeChipBorderWidth", "scopeTextSize", "scopeTextWeight", "scopeChipHoverTextWeight", "scopeChipSelTextWeight"])
            }

            Section {
                key: "searchBehaviour"
                title: I18n.trFor("customMenu", "Behavior")

                body: Component {
                    Item {

                        PluginToggle {
                            settingKey: "searchEnterLaunches"
                            label: I18n.trFor("customMenu", "Enter launches the first app")
                            description: I18n.trFor("customMenu", "The first search result, with or without a search field")
                            defaultValue: Defaults.searchEnterLaunches
                        }

                        PluginToggle {
                            settingKey: "searchShowQueryChip"
                            label: I18n.trFor("customMenu", "Show typed text")
                            description: I18n.trFor("customMenu", "Without a search field: shows the typed text at the top right above the apps, with a button to clear it")
                            defaultValue: Defaults.searchShowQueryChip
                        }
                    }
                }
            }

            Section {
                key: "searchScope"
                title: I18n.trFor("customMenu", "Search scope")

                body: Component {
                    Item {

                        PluginToggle {
                            id: searchScopeShow
                            settingKey: "searchScopeShow"
                            label: I18n.trFor("customMenu", "Choose what to search")
                            description: I18n.trFor("customMenu", "Everything, Apps, Files or Folders; the menu always opens with Everything. Chips below the field look like the category chips.")
                            defaultValue: Defaults.searchScopeShow
                        }
                        PluginSelection {
                            id: searchScopeStyle
                            visible: searchScopeShow.value
                            settingKey: "searchScopeStyle"
                            label: I18n.trFor("customMenu", "Style")
                            options: [
                                { label: I18n.trFor("customMenu", "Chip in the search field"), value: "field" },
                                { label: I18n.trFor("customMenu", "Chips beside the search field"), value: "chips" }
                            ]
                            defaultValue: Defaults.searchScopeStyle
                        }
                        // Chips outside: side and alignment along it
                        PluginSelection {
                            id: searchScopeSide
                            visible: searchScopeShow.value && searchScopeStyle.value === "chips"
                            settingKey: "searchScopeSide"
                            label: I18n.trFor("customMenu", "Position")
                            options: [
                                { label: I18n.trFor("customMenu", "Below"), value: "bottom" },
                                { label: I18n.trFor("customMenu", "Above"), value: "top" },
                                { label: I18n.trFor("customMenu", "Left"), value: "left" },
                                { label: I18n.trFor("customMenu", "Right"), value: "right" }
                            ]
                            defaultValue: Defaults.searchScopeSide
                        }
                        PluginSelection {
                            readonly property bool across: searchScopeSide.value === "top" || searchScopeSide.value === "bottom"
                            visible: searchScopeShow.value && searchScopeStyle.value === "chips"
                            settingKey: "searchScopeAlign"
                            label: I18n.trFor("customMenu", "Alignment")
                            description: across ? "" : I18n.trFor("customMenu", "Relative to the search field")
                            options: across ? [
                                { label: I18n.trFor("customMenu", "Full width"), value: "fill" },
                                { label: I18n.trFor("customMenu", "Left"), value: "start" },
                                { label: I18n.trFor("customMenu", "Centered"), value: "center" },
                                { label: I18n.trFor("customMenu", "Right"), value: "end" }
                            ] : [
                                { label: I18n.trFor("customMenu", "Top"), value: "start" },
                                { label: I18n.trFor("customMenu", "Centered"), value: "center" },
                                { label: I18n.trFor("customMenu", "Bottom"), value: "end" }
                            ]
                            defaultValue: Defaults.searchScopeAlign
                        }
                        // Chip in the field: a click opens the list
                        PluginSlider {
                            visible: searchScopeShow.value && searchScopeStyle.value !== "chips"
                            settingKey: "searchScopeTextSize"
                            label: I18n.trFor("customMenu", "Text size")
                            defaultValue: Theme.fontSizeSmall
                            minimum: 8
                            maximum: 24
                            unit: "px"
                        }
                        SurfaceStyleSetting {
                            visible: searchScopeShow.value && searchScopeStyle.value !== "chips"
                            keyPrefix: "searchScopeText"
                            label: I18n.trFor("customMenu", "Text color")
                            defaultColor: Theme.onSecondaryContainer
                        }
                        SurfaceStyleSetting {
                            visible: searchScopeShow.value && searchScopeStyle.value !== "chips"
                            keyPrefix: "searchScopeBg"
                            label: I18n.trFor("customMenu", "Chip color")
                            defaultColor: Theme.secondaryContainer
                        }
                        // Scope chips (shown as chips beside or under the field): own look,
                        // each value as the category chips until set here
                        Section {
                            visible: searchScopeShow.value && searchScopeStyle.value === "chips"
                            key: "scopeChips"
                            title: I18n.trFor("customMenu", "Chips")

                            body: Component {
                                Item {

                                    PluginSlider {
                                        id: scopeChipHeight
                                        settingKey: "scopeChipHeight"
                                        label: I18n.trFor("customMenu", "Height")
                                        defaultValue: sectionRoot.settings.effectiveValue("catChipHeight", Defaults.catChipHeight)
                                        minimum: 20
                                        maximum: 80
                                        unit: "px"
                                    }
                                    PluginSlider {
                                        settingKey: "scopeChipRadius"
                                        label: I18n.trFor("customMenu", "Corner radius")
                                        defaultValue: Math.min(sectionRoot.settings.effectiveValue("catChipRadius", Math.round(Theme.cornerRadiusS)), Math.floor(scopeChipHeight.value / 2))
                                        minimum: 0
                                        maximum: Math.floor(scopeChipHeight.value / 2)
                                        unit: "px"
                                    }
                                    PluginSlider {
                                        settingKey: "scopeChipSpacing"
                                        label: I18n.trFor("customMenu", "Spacing between chips")
                                        defaultValue: 4
                                        minimum: 0
                                        maximum: 32
                                        unit: "px"
                                    }

                                    Section {
                                        key: "scopeChipBgSec"
                                        title: I18n.trFor("customMenu", "Background")

                                        body: Component {
                                            Item {
                                                SurfaceStyleSetting {
                                                    keyPrefix: "scopeChipBg"
                                                    defaultLabel: sectionRoot.settings.scopeInherit
                                                    label: I18n.trFor("customMenu", "Color")
                                                    defaultColor: sectionRoot.settings.lookColor("catChipBg", Theme.chipSurfaceNested)
                                                }
                                            }
                                        }
                                    }
                                    Section {
                                        key: "scopeChipBorderSec"
                                        title: I18n.trFor("customMenu", "Border")

                                        body: Component {
                                            Item {
                                                PluginSlider {
                                                    settingKey: "scopeChipBorderWidth"
                                                    label: I18n.trFor("customMenu", "Width")
                                                    defaultValue: sectionRoot.settings.effectiveValue("catChipBorderWidth", sectionRoot.settings.sharedOr("allPieceBorderWidth", Defaults.chipBorderWidth))
                                                    minimum: 0
                                                    maximum: 6
                                                    unit: "px"
                                                }
                                                SurfaceStyleSetting {
                                                    keyPrefix: "scopeChipBorder"
                                                    defaultLabel: sectionRoot.settings.scopeInherit
                                                    label: I18n.trFor("customMenu", "Color")
                                                    defaultColor: sectionRoot.settings.lookColor("catChipBorder", Theme.outlineVariant)
                                                    optionSet: "border"
                                                }
                                            }
                                        }
                                    }
                                    Section {
                                        key: "scopeChipTextSec"
                                        title: I18n.trFor("customMenu", "Text")

                                        body: Component {
                                            Item {
                                                SurfaceStyleSetting {
                                                    keyPrefix: "scopeChipText"
                                                    defaultLabel: sectionRoot.settings.scopeInherit
                                                    label: I18n.trFor("customMenu", "Color")
                                                    defaultColor: sectionRoot.settings.lookColor("catChipText", Theme.onSurfaceVariant)
                                                    textRoles: true
                                                }
                                                PluginSlider {
                                                    settingKey: "scopeTextSize"
                                                    label: I18n.trFor("customMenu", "Size")
                                                    defaultValue: sectionRoot.settings.effectiveValue("catTextSize", Theme.fontSizeSmall)
                                                    minimum: 8
                                                    maximum: 24
                                                    unit: "px"
                                                }
                                                WeightSetting {
                                                    settingKey: "scopeTextWeight"
                                                    label: I18n.trFor("customMenu", "Font weight")
                                                    inheritLabel: sectionRoot.settings.scopeInherit
                                                }
                                            }
                                        }
                                    }
                                    Section {
                                        key: "scopeChipHoverSec"
                                        title: I18n.trFor("customMenu", "On hover")

                                        body: Component {
                                            Item {

                                                SurfaceStyleSetting {
                                                    keyPrefix: "scopeChipHoverBg"
                                                    defaultLabel: sectionRoot.settings.scopeInherit
                                                    label: I18n.trFor("customMenu", "Background color")
                                                    defaultColor: sectionRoot.settings.lookColor("catChipHoverBg", Theme.withAlpha(Theme.onSurface, Theme.stateLayerHover))
                                                }
                                                SurfaceStyleSetting {
                                                    keyPrefix: "scopeChipHoverBorder"
                                                    defaultLabel: sectionRoot.settings.scopeInherit
                                                    label: I18n.trFor("customMenu", "Border color")
                                                    defaultColor: sectionRoot.settings.lookColor("catChipHoverBorder", Theme.outlineVariant)
                                                    optionSet: "border"
                                                }
                                                SurfaceStyleSetting {
                                                    keyPrefix: "scopeChipHoverText"
                                                    defaultLabel: sectionRoot.settings.scopeInherit
                                                    label: I18n.trFor("customMenu", "Text color")
                                                    defaultColor: sectionRoot.settings.lookColor("catChipHoverText", Theme.onSurfaceVariant)
                                                    textRoles: true
                                                }
                                                WeightSetting {
                                                    settingKey: "scopeChipHoverTextWeight"
                                                    label: I18n.trFor("customMenu", "Font weight")
                                                    inheritLabel: sectionRoot.settings.scopeInherit
                                                }
                                            }
                                        }
                                    }
                                    Section {
                                        key: "scopeChipSelSec"
                                        title: I18n.trFor("customMenu", "Selected")

                                        body: Component {
                                            Item {

                                                SurfaceStyleSetting {
                                                    keyPrefix: "scopeChipSel"
                                                    defaultLabel: sectionRoot.settings.scopeInherit
                                                    label: I18n.trFor("customMenu", "Background color")
                                                    defaultColor: sectionRoot.settings.lookColor("catChipSel", Theme.secondaryContainer)
                                                }
                                                SurfaceStyleSetting {
                                                    keyPrefix: "scopeChipSelBorder"
                                                    defaultLabel: sectionRoot.settings.scopeInherit
                                                    label: I18n.trFor("customMenu", "Border color")
                                                    defaultColor: sectionRoot.settings.lookColor("catChipSelBorder", Theme.outlineVariant)
                                                    optionSet: "border"
                                                }
                                                SurfaceStyleSetting {
                                                    keyPrefix: "scopeChipSelText"
                                                    defaultLabel: sectionRoot.settings.scopeInherit
                                                    label: I18n.trFor("customMenu", "Text color")
                                                    defaultColor: sectionRoot.settings.lookColor("catChipSelText", Theme.onSurfaceVariant)
                                                    textRoles: true
                                                }
                                                WeightSetting {
                                                    settingKey: "scopeChipSelTextWeight"
                                                    label: I18n.trFor("customMenu", "Font weight")
                                                    inheritLabel: sectionRoot.settings.scopeInherit
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

            Section {
                key: "searchSections"
                title: I18n.trFor("customMenu", "Result sections")

                body: Component {
                    Item {

                        StyledText {
                            x: Theme.spacingM
                            width: parent.width - Theme.spacingM * 2
                            wrapMode: Text.WordWrap
                            text: I18n.trFor("customMenu", "While searching, the apps element shows the results in sections like DMS' launcher (apps, files, settings, one per launcher plugin).")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        PluginSlider {
                            settingKey: "secTitleSize"
                            label: I18n.trFor("customMenu", "Heading size")
                            resettable: true
                            defaultValue: (sectionRoot.settings.effectiveValue("textSize", undefined) ?? sectionRoot.settings.sharedOr("allPieceTextSize", Theme.fontSizeSmall)) + 2
                            minimum: 8
                            maximum: 28
                            unit: "px"
                        }
                        WeightSetting {
                            settingKey: "secTitleWeight"
                            defaultValue: "medium"
                        }
                        SurfaceStyleSetting {
                            keyPrefix: "secTitle"
                            label: I18n.trFor("customMenu", "Heading color")
                            defaultLabel: I18n.trFor("customMenu", "Default (app text)")
                            defaultColor: Theme.surfaceText
                        }
                        PluginToggle {
                            id: secLineShow
                            settingKey: "secLineShow"
                            label: I18n.trFor("customMenu", "Line after the heading")
                            defaultValue: true
                        }
                        SurfaceStyleSetting {
                            visible: secLineShow.value
                            keyPrefix: "secLine"
                            label: I18n.trFor("customMenu", "Line color")
                            defaultLabel: I18n.trFor("customMenu", "Default (app text, dimmed)")
                            defaultColor: Theme.outlineVariant
                            optionSet: "border"
                        }
                        PluginSlider {
                            settingKey: "secGap"
                            label: I18n.trFor("customMenu", "Space between sections")
                            resettable: true
                            defaultValue: sectionRoot.settings.effectiveValue("appRowSpacing", Defaults.appRowSpacing)
                            minimum: 0
                            maximum: 48
                            unit: "px"
                        }
                        PluginSlider {
                            settingKey: "secTitleGap"
                            label: I18n.trFor("customMenu", "Space below the heading")
                            defaultValue: Defaults.secTitleGap
                            minimum: 0
                            maximum: 32
                            unit: "px"
                        }

                        StyledText {
                            x: Theme.spacingM
                            width: parent.width - Theme.spacingM * 2
                            wrapMode: Text.WordWrap
                            text: I18n.trFor("customMenu", "Order and visibility. Hidden sections are hidden only in CustomMenu. If DMS shows only folders, they appear under \"Files\".")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                        SearchSectionList {
                            sections: {
                                const list = [
                                    { "id": "apps", "name": I18n.trFor("customMenu", "Applications"), "icon": "apps" },
                                    { "id": "files", "name": I18n.trFor("customMenu", "Files"), "icon": "description" },
                                    { "id": "folders", "name": I18n.trFor("customMenu", "Folders"), "icon": "folder" },
                                    { "id": "settings", "name": I18n.tr("Search settings", "launcher plugin name that searches DMS settings"), "icon": "settings" },
                                    { "id": "clipboard", "name": I18n.tr("Clipboard"), "icon": "content_paste" }
                                ];
                                const builtIn = AppSearchService.builtInPlugins ?? {};
                                for (const id of Object.keys(builtIn)) {
                                    if (id === "dms_settings_search" || id === "dms_clipboard_search")
                                        continue;
                                    list.push({ "id": "plugin_" + id, "name": builtIn[id].name, "icon": builtIn[id].cornerIcon || "extension" });
                                }
                                const plugins = PluginService.getLauncherPlugins();
                                for (const id of Object.keys(plugins))
                                    list.push({ "id": "plugin_" + id, "name": plugins[id].name || id, "icon": plugins[id].icon || "extension" });
                                return list;
                            }
                        }
                    }
                }
            }

            Section {
                key: "searchFiles"
                title: I18n.trFor("customMenu", "Files and folders")

                body: Component {
                    Item {

                        StyledText {
                            x: Theme.spacingM
                            width: parent.width - Theme.spacingM * 2
                            wrapMode: Text.WordWrap
                            text: I18n.trFor("customMenu", "Found by DMS' file search (dsearch). Which types appear is set in DMS settings › Launcher.")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        PluginToggle {
                            id: searchPathShow
                            settingKey: "searchPathShow"
                            label: I18n.trFor("customMenu", "Show location")
                            description: I18n.trFor("customMenu", "The folder containing a result, shown as its description (even when app descriptions are off)")
                            defaultValue: Defaults.searchPathShow
                        }
                        PluginSlider {
                            visible: searchPathShow.value
                            settingKey: "searchPathDepth"
                            label: I18n.trFor("customMenu", "Parent folders")
                            description: I18n.trFor("customMenu", "How many folders of the path to show, counting up from the result")
                            defaultValue: Defaults.searchPathDepth
                            minimum: 1
                            maximum: 8
                        }
                        PluginToggle {
                            visible: searchPathShow.value
                            settingKey: "searchFolderCount"
                            label: I18n.trFor("customMenu", "Folder contents")
                            description: I18n.trFor("customMenu", "Number of files and subfolders in a found folder")
                            defaultValue: Defaults.searchFolderCount
                        }
                        PathBadgeList {
                            visible: searchPathShow.value
                            settingKey: "searchPathBadges"
                            label: I18n.trFor("customMenu", "Badges")
                            description: I18n.trFor("customMenu", "Results inside a folder show a badge instead of the path to it, e.g. ~/Nextcloud → \"Nextcloud\". The longest matching folder wins.")
                        }
                    }
                }
            }

            AreaSection {
                key: "searchArea"
                prefix: "searchArea"
                title: I18n.trFor("customMenu", "Background of this search element")
            }

            AreaBorderSection {
                key: "searchAreaBorder"
                prefix: "searchArea"
                title: I18n.trFor("customMenu", "Border of this search element")
            }

            PluginSlider {
                id: searchHeight
                settingKey: "searchHeight"
                label: I18n.trFor("customMenu", "Height")
                description: I18n.trFor("customMenu", "Height of the search field; the element adjusts")
                defaultValue: Defaults.searchHeight
                minimum: 28
                maximum: 96
                unit: "px"
            }

            PluginSlider {
                settingKey: "searchRadius"
                label: I18n.trFor("customMenu", "Corner radius")
                description: I18n.trFor("customMenu", "Maximum = half the height: fully round ends")
                resettable: true
                defaultValue: sectionRoot.settings.sharedOr("allPieceRadius", Math.round(Theme.cornerRadiusS))
                minimum: 0
                maximum: Math.floor(searchHeight.value / 2)
                unit: "px"
            }

            // Same structure as the category chips
            Section {
                key: "searchBackground"
                title: I18n.trFor("customMenu", "Background")

                body: Component {
                    Item {

                        SurfaceStyleSetting {
                            keyPrefix: "searchBg"
                            defaultLabel: sectionRoot.settings.inheritLabel
                            label: I18n.trFor("customMenu", "Color")
                            defaultColor: Theme.chipSurfaceNested
                        }
                    }
                }
            }

            Section {
                key: "searchBorder"
                title: I18n.trFor("customMenu", "Border")

                body: Component {
                    Item {

                        PluginSlider {
                            id: searchBorderWidth
                            settingKey: "searchBorderWidth"
                            label: I18n.trFor("customMenu", "Width")
                            description: searchFocusHighlight.value ? I18n.trFor("customMenu", "0 = no border; 1 px thicker when focused") : I18n.trFor("customMenu", "0 = no border")
                            resettable: true
                            defaultValue: sectionRoot.settings.sharedOr("allPieceBorderWidth", Math.round(Theme.outlineWidth))
                            minimum: 0
                            maximum: 6
                            unit: "px"
                        }

                        SurfaceStyleSetting {
                            visible: searchBorderWidth.value > 0
                            keyPrefix: "searchBorder"
                            defaultLabel: sectionRoot.settings.inheritLabel
                            label: I18n.trFor("customMenu", "Color")
                            defaultColor: Theme.outlineVariant
                            optionSet: "border"
                        }

                        PluginToggle {
                            id: searchFocusHighlight
                            settingKey: "searchFocusHighlight"
                            label: I18n.trFor("customMenu", "Highlight when focused")
                            description: I18n.trFor("customMenu", "The field has focus while the menu is open: border (and icon, if set) in the focus color, border 1 px thicker. Off: always the normal look.")
                            defaultValue: Defaults.searchFocusHighlight
                        }

                        SurfaceStyleSetting {
                            visible: searchBorderWidth.value > 0 && searchFocusHighlight.value
                            keyPrefix: "searchBorderFocus"
                            defaultLabel: I18n.trFor("customMenu", "Default (Primary)")
                            label: I18n.trFor("customMenu", "Focus color")
                            defaultColor: Theme.primary
                            optionSet: "border"
                        }
                    }
                }
            }

            Section {
                key: "searchText"
                title: I18n.trFor("customMenu", "Text")

                body: Component {
                    Item {

                        // Hint text in the empty field; empty = default text
                        // (follows the language)
                        StringSetting {
                            x: Theme.spacingM
                            width: parent.width - Theme.spacingM * 2
                            settingKey: "searchPlaceholderText"
                            label: I18n.trFor("customMenu", "Placeholder text")
                            description: I18n.trFor("customMenu", "Shown while the field is empty. Empty = \"%1\"").arg(I18n.trFor("customMenu", "Search apps"))
                            placeholder: I18n.trFor("customMenu", "Search apps")
                            defaultValue: ""
                        }

                        // Without typing the hint text shows, while typing the typed
                        // text: by default both in the same colour
                        SurfaceStyleSetting {
                            keyPrefix: "searchPlaceholder"
                            defaultLabel: sectionRoot.settings.inheritLabel
                            label: I18n.trFor("customMenu", "Color")
                            description: I18n.trFor("customMenu", "The placeholder text shown while the field is empty")
                            defaultColor: Theme.onSurfaceVariant
                            textRoles: true
                            defaultTransparent: Defaults.searchPlaceholderTransparent
                            defaultTransparency: Defaults.searchPlaceholderTransparency
                        }

                        SurfaceStyleSetting {
                            keyPrefix: "searchText"
                            defaultLabel: I18n.trFor("customMenu", "Default (same as when not typing)")
                            label: I18n.trFor("customMenu", "Color while typing")
                            description: I18n.trFor("customMenu", "The typed text")
                            defaultColor: Theme.onSurfaceVariant
                            textRoles: true
                        }

                        PluginSlider {
                            settingKey: "searchTextSize"
                            label: I18n.trFor("customMenu", "Size")
                            resettable: true
                            defaultValue: sectionRoot.settings.sharedOr("allPieceTextSize", Math.round(Theme.fontSizeMedium))
                            minimum: 8
                            maximum: 28
                            unit: "px"
                        }

                        WeightSetting {
                            settingKey: "searchTextWeight"
                            inheritLabel: sectionRoot.settings.inheritLabel
                            defaultValue: sectionRoot.settings.sharedOr("allPieceTextWeight", Defaults.searchTextWeight)
                        }
                    }
                }
            }

            Section {
                key: "searchIcon"
                title: I18n.trFor("customMenu", "Icon")

                body: Component {
                    Item {

                        PluginToggle {
                            id: searchShowIcon
                            settingKey: "searchShowIcon"
                            label: I18n.trFor("customMenu", "Show icon")
                            defaultValue: Defaults.searchShowIcon
                        }

                        PluginToggle {
                            visible: searchShowIcon.value
                            settingKey: "searchHideIconWhileTyping"
                            label: I18n.trFor("customMenu", "Hide while typing")
                            description: I18n.trFor("customMenu", "The icon disappears as soon as there is text in the field")
                            defaultValue: Defaults.searchHideIconWhileTyping
                        }

                        MaterialIconSetting {
                            visible: searchShowIcon.value
                            settingKey: "searchIconName"
                            suggestions: Defaults.iconSuggestions.search
                            hintFolders: ["actions/scalable", "actions"]
                            description: I18n.trFor("customMenu", "Symbol icons use the colors below; icon files keep their own")
                            defaultValue: Defaults.searchIconName
                        }

                        SurfaceStyleSetting {
                            visible: searchShowIcon.value
                            keyPrefix: "searchIcon"
                            defaultLabel: sectionRoot.settings.inheritLabel
                            label: I18n.trFor("customMenu", "Color")
                            defaultColor: Theme.onSurfaceVariant
                            textRoles: true
                        }

                        SurfaceStyleSetting {
                            visible: searchShowIcon.value && sectionRoot.settings.effectiveValue("searchFocusHighlight", Defaults.searchFocusHighlight) === true
                            keyPrefix: "searchIconFocus"
                            defaultLabel: I18n.trFor("customMenu", "Default (same as unfocused)")
                            label: I18n.trFor("customMenu", "Focus color")
                            defaultColor: Theme.onSurfaceVariant
                            textRoles: true
                        }
                    }
                }
            }
        }
    }
}
