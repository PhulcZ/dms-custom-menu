import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets
import "../../Defaults.js" as Defaults
import "../../Templates.js" as Templates
import "../../FontLogos.js" as FontLogos

// ── General ──
Section {
    id: sectionRoot
    key: "general"
    title: I18n.trFor("customMenu", "Size, spacing and icon")

    body: Component {
        Item {

            // The menu's own buttons, in their order in the menu:
            // pencil left, gear right
            Row {
                x: Theme.spacingM
                width: parent.width - Theme.spacingM * 2
                spacing: Theme.spacingM

                PluginToggle {
                    width: (parent.width - parent.spacing) / 2
                    settingKey: "showEditButton"
                    label: I18n.trFor("customMenu", "Edit button")
                    description: I18n.trFor("customMenu", "Pencil in the menu: rearrange the elements")
                    defaultValue: Defaults.showEditButton
                }
                PluginToggle {
                    width: (parent.width - parent.spacing) / 2
                    settingKey: "showSettingsButton"
                    label: I18n.trFor("customMenu", "Settings button")
                    description: I18n.trFor("customMenu", "Gear in the menu: opens this page")
                    defaultValue: Defaults.showSettingsButton
                }
            }

            // ── Size ──
            Section {
                key: "size"
                title: I18n.trFor("customMenu", "Size and position")

                body: Component {
                    Item {

                        // Size: exact pixels (default) or percent of the screen (5 %
                        // steps). Switching starts at the size shown, so nothing
                        // jumps.
                        StyledText {
                            visible: sectionRoot.settings.sizeFromProfile
                            x: Theme.spacingM
                            width: parent.width - Theme.spacingM * 2
                            wrapMode: Text.WordWrap
                            text: I18n.trFor("customMenu", "The size belongs to the profile \"%1\"; changing it here changes the profile. Your own size returns when you select another profile.").arg(Templates.translated(sectionRoot.settings.activeTemplateId) ? I18n.trFor("customMenu", Templates.nameOf(sectionRoot.settings.activeTemplateId)) : Templates.nameOf(sectionRoot.settings.activeTemplateId))
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                        }

                        PluginSelection {
                            id: menuSizeMode
                            settingKey: "menuSizeMode"
                            label: I18n.trFor("customMenu", "Size")
                            // Before the mode existed, "menuSizePixels" or stored
                            // percentages chose it
                            defaultValue: Defaults.sizeModeOf({
                                "menuSizePixels": sectionRoot.settings.effectiveValue("menuSizePixels", undefined),
                                "menuWidthPercent": sectionRoot.settings.effectiveValue("menuWidthPercent", undefined),
                                "menuHeightPercent": sectionRoot.settings.effectiveValue("menuHeightPercent", undefined)
                            })
                            options: [
                                { label: I18n.trFor("customMenu", "Pixels"), value: "pixels" },
                                { label: I18n.trFor("customMenu", "Percentage of screen"), value: "percent" },
                                { label: I18n.trFor("customMenu", "Fullscreen"), value: "full" }
                            ]
                            onUserSelected: mode => {
                                const size = sectionRoot.settings.shownMenuSize;
                                const changes = { "menuSizePixels": undefined };
                                if (size && mode === "pixels") {
                                    changes.menuWidth = size.w;
                                    changes.menuHeight = size.h;
                                } else if (size && mode === "percent") {
                                    const pct = (v, total) => Math.max(10, Math.min(100, Math.round(v / total * 20) * 5));
                                    changes.menuWidthPercent = pct(size.w, size.screenW);
                                    changes.menuHeightPercent = pct(size.h, size.screenH);
                                }
                                sectionRoot.settings.saveValues(changes);
                            }
                        }

                        PluginSlider {
                            visible: menuSizeMode.value === "percent"
                            settingKey: "menuWidthPercent"
                            label: I18n.trFor("customMenu", "Width")
                            description: I18n.trFor("customMenu", "Width of the menu, as a percentage of the screen width")
                            defaultValue: Defaults.menuWidthPercent
                            minimum: 10
                            maximum: 100
                            step: 5
                            unit: "%"
                        }
                        PluginSlider {
                            visible: menuSizeMode.value === "percent"
                            settingKey: "menuHeightPercent"
                            label: I18n.trFor("customMenu", "Height")
                            description: I18n.trFor("customMenu", "Height of the menu, as a percentage of the screen height")
                            defaultValue: Defaults.menuHeightPercent
                            minimum: 10
                            maximum: 100
                            step: 5
                            unit: "%"
                        }

                        PluginSlider {
                            visible: menuSizeMode.value === "pixels"
                            settingKey: "menuWidth"
                            label: I18n.trFor("customMenu", "Width")
                            description: I18n.trFor("customMenu", "Width of the menu")
                            defaultValue: Defaults.menuWidth
                            minimum: 2 * Defaults.gridCell
                            maximum: Math.max(minimum, sectionRoot.settings.maxScreenWidth - 2 * Theme.popupDistance)
                            unit: "px"
                        }

                        PluginSlider {
                            visible: menuSizeMode.value === "pixels"
                            settingKey: "menuHeight"
                            label: I18n.trFor("customMenu", "Height")
                            description: I18n.trFor("customMenu", "Height of the menu")
                            defaultValue: Defaults.menuHeight
                            minimum: 2 * Defaults.gridCell
                            maximum: Math.max(minimum, sectionRoot.settings.maxScreenHeight - 2 * Theme.popupDistance)
                            unit: "px"
                        }

                        PluginSelection {
                            settingKey: "menuAnimation"
                            label: I18n.trFor("customMenu", "Opening animation")
                            description: I18n.trFor("customMenu", "Where the menu comes from when it opens (and where it goes when it closes). Timing follows DMS. Only for a free-standing menu (position \"Free\" or custom menu surface); when docked, DMS' frame decides.")
                            options: [
                                { label: I18n.trFor("customMenu", "Same as DMS"), value: "dms" },
                                { label: I18n.trFor("customMenu", "Screen center"), value: "screenCenter" },
                                { label: I18n.trFor("customMenu", "Menu center"), value: "menuCenter" }
                            ]
                            defaultValue: Defaults.menuAnimation
                        }

                        PluginSelection {
                            id: menuAnchor
                            settingKey: "menuAnchor"
                            label: I18n.trFor("customMenu", "Position")
                            description: I18n.trFor("customMenu", "From a screen edge: with DMS' connected frame, the menu stays attached to the frame there. Free: detached from the frame.")
                            options: [
                                { label: I18n.trFor("customMenu", "At the widget (DMS default)"), value: "widget" },
                                { label: I18n.trFor("customMenu", "From the left"), value: "left" },
                                { label: I18n.trFor("customMenu", "From the right"), value: "right" },
                                { label: I18n.trFor("customMenu", "From the top"), value: "top" },
                                { label: I18n.trFor("customMenu", "From the bottom"), value: "bottom" },
                                { label: I18n.trFor("customMenu", "Free"), value: "screen" }
                            ]
                            defaultValue: Defaults.menuAnchor
                        }

                        PluginToggle {
                            visible: menuAnchor.value === "screen"
                            settingKey: "menuShadow"
                            label: I18n.trFor("customMenu", "Shadow")
                            description: I18n.trFor("customMenu", "Shadow around the free-standing menu; only if the popout shadow is enabled in DMS")
                            defaultValue: Defaults.menuShadow
                        }

                        OffsetSetting {
                            visible: ["top", "bottom", "screen"].includes(menuAnchor.value)
                            settingKey: "menuOffsetX"
                            label: I18n.trFor("customMenu", "Horizontal offset")
                            description: I18n.trFor("customMenu", "From the center. Positive: to the right, negative: to the left")
                            range: Math.round(sectionRoot.settings.maxScreenWidth / 2)
                        }

                        OffsetSetting {
                            visible: ["left", "right", "screen"].includes(menuAnchor.value)
                            settingKey: "menuOffsetY"
                            label: I18n.trFor("customMenu", "Vertical offset")
                            description: I18n.trFor("customMenu", "From the center. Positive: down, negative: up")
                            range: Math.round(sectionRoot.settings.maxScreenHeight / 2)
                        }
                    }
                }
            }

            // ── Spacing, by level ──
            Section {
                key: "spacing"
                title: I18n.trFor("customMenu", "Spacing")

                body: Component {
                    Item {

                        // All spacings 0, the menu shrinks to its elements
                        // (the widget does it: it knows their size)
                        Item {
                            width: parent.width
                            height: Math.max(compactButton.height, compactHint.implicitHeight)
                            StyledText {
                                id: compactHint
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.right: compactButton.left
                                anchors.rightMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                wrapMode: Text.WordWrap
                                text: I18n.trFor("customMenu", "Sets all spacing to 0 and shrinks the menu to fit its elements, e.g. for a small extra menu. You can add spacing again afterwards.")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                            DButton {
                                id: compactButton
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter
                                iconName: "compress"
                                text: I18n.trFor("customMenu", "Compact")
                                onClicked: PluginService.setGlobalVar(sectionRoot.settings.pluginId, "compactRequest", { "instance": sectionRoot.settings.editInstance, "stamp": Date.now() })
                            }
                        }

                        Section {
                            key: "spacingL1"
                            title: I18n.trFor("customMenu", "Level 1 · Background")

                            body: Component {
                                Item {

                                    // Free: one margin for all sides. Docked: the side at the bar,
                                    // frame or island separately.
                                    PluginSlider {
                                        visible: sectionRoot.settings.effectiveValue("menuAnchor", Defaults.menuAnchor) !== "screen"
                                        settingKey: "cardMarginDocked"
                                        label: I18n.trFor("customMenu", "Canvas margin, bar side")
                                        defaultValue: Defaults.cardMarginDocked
                                        minimum: 0
                                        maximum: 64
                                        unit: "px"
                                    }

                                    PluginSlider {
                                        settingKey: "cardMargin"
                                        label: sectionRoot.settings.effectiveValue("menuAnchor", Defaults.menuAnchor) === "screen" ? I18n.trFor("customMenu", "Canvas margin") : I18n.trFor("customMenu", "Canvas margin, other sides")
                                        defaultValue: Defaults.cardMargin
                                        minimum: 0
                                        maximum: 64
                                        unit: "px"
                                    }
                                }
                            }
                        }

                        Section {
                            key: "cardSpacing"
                            title: I18n.trFor("customMenu", "Level 2 · Canvas")

                            body: Component {
                                Item {

                                    // Inside the card: distance to the elements. Docked: the
                                    // side at the bar separately (as Level 1)
                                    PluginSlider {
                                        visible: sectionRoot.settings.effectiveValue("menuAnchor", Defaults.menuAnchor) !== "screen"
                                        settingKey: "cardPaddingDocked"
                                        label: I18n.trFor("customMenu", "Canvas padding, bar side")
                                        defaultValue: sectionRoot.settings.effectiveValue("cardPadding", Defaults.cardPadding)
                                        minimum: 0
                                        maximum: 192
                                        unit: "px"
                                    }

                                    PluginSlider {
                                        settingKey: "cardPadding"
                                        label: sectionRoot.settings.effectiveValue("menuAnchor", Defaults.menuAnchor) === "screen" ? I18n.trFor("customMenu", "Canvas padding") : I18n.trFor("customMenu", "Canvas padding, other sides")
                                        description: I18n.trFor("customMenu", "Space between the canvas edge and the elements. Without a canvas surface, it adds to the canvas margin.")
                                        defaultValue: Defaults.cardPadding
                                        minimum: 0
                                        maximum: 192
                                        unit: "px"
                                    }

                                    PluginSlider {
                                        settingKey: "elementGap"
                                        label: I18n.trFor("customMenu", "Gap between elements")
                                        description: I18n.trFor("customMenu", "Between adjacent elements")
                                        defaultValue: Defaults.elementGap
                                        minimum: 0
                                        maximum: 64
                                        unit: "px"
                                    }
                                }
                            }
                        }

                        Section {
                            key: "spacingL3"
                            title: I18n.trFor("customMenu", "Level 3 · Elements")

                            body: Component {
                                Item {

                                    PluginSlider {
                                        settingKey: "allAreaPadding"
                                        label: I18n.trFor("customMenu", "Padding")
                                        description: I18n.trFor("customMenu", "Space between an element's background edge and its content, for all elements (each element can set its own in its background settings)")
                                        defaultValue: Defaults.areaPadding
                                        minimum: 0
                                        maximum: 48
                                        unit: "px"
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── General › Bar icon ──
            Section {
                key: "barIcon"
                title: I18n.trFor("customMenu", "Icon in the bar")

                body: Component {
                    Item {

                        // Icon and colour in one row (colour only for symbol icons)
                        MaterialIconSetting {
                            settingKey: "barIcon"
                            colorKey: "barIconColor"
                        // First the logo of the running distribution and DMS' logo
                        suggestions: ["logo:" + FontLogos.distroLogo(sectionRoot.settings.osReleaseText()), "dms:logo"].concat(Defaults.iconSuggestions.bar)
                            // App icons of the theme, incl. distribution logos
                            hintFolders: ["apps/scalable", "apps"]
                            description: I18n.trFor("customMenu", "The icon CustomMenu shows in the bar")
                            defaultValue: Defaults.barIcon
                        }
                    }
                }
            }
        }
    }

}
