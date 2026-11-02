.pragma library

// Built-in templates (Templates.js has the logic): name, the setting values
// and the arrangement, optional flags
//   translate: false   name shown as is in every language
//   sizeOverlay: true  its size goes over the instance's own while active
//   exclusiveLayout    only its own elements in the menu
//   contents           tile elements it brings along (added if missing)
// builtInOrder: their order in the template chooser.

var builtIn = {
    // "Default" in every language: not translated (the word "Default" is
    // translated elsewhere, e.g. German "Standard" for reset buttons)
    "standard": {
        "name": "Default",
        "translate": false,
        "values": {}
    },
    // Categories, apps and tiles side by side, no search field (typing
    // searches anyway), app icons without labels; only its own elements
    "minimal": {
        "name": "Minimal",
        "exclusiveLayout": true,
        "values": {
            "allAreaColorMode": "none",
            "allPieceColorMode": "none",
            "categoryStyle": "chips",
            "catChipBgColorMode": "none",
            "catChipTextColorMode": "default",
            "catChipBorderWidth": 0,
            "catChipWidth": 165,
            "catChipSelColorMode": "none",
            "catShowIcons": true,
            "catAlignV": "center",
            "cardPadding": 120,
            "appShowLabels": false,
            "appTooltips": true,
            "layoutMode": "custom",
            "appSpacing": 5,
            "appRowSpacing": 5,
            "appIconSize": 30,
            "catAreaPadding": 10,
            "appsAreaBorderWidth": 1,
            "tlAlignH": "center",
            "tlAlignV": "center",
            "appsAreaColorMode": "chip",
            "appsAreaBorderColorMode": "chipNested",
            "catChipSelTextColorMode": "surfaceText",
            "catChipSelTextWeight": "bold",
            "chipHeight": 75,
            "chipWidth": 100,
            "tlTileColorMode": "chip",
            "layout": [
                {
                    "id": "categories",
                    "col": 0,
                    "row": 0,
                    "w": 160,
                    "h": 1000
                },
                {
                    "id": "apps",
                    "col": 260,
                    "row": 0,
                    "w": 560,
                    "h": 1000
                },
                {
                    "id": "shortcuts:default",
                    "col": 880,
                    "row": 0,
                    "w": 120,
                    "h": 1000
                }
            ],
            "layoutGrid": 1000,
            "lockedElements": [],
            "scrollFade": true
        }
    },
    // Detached from the bar and the screen edges, in the middle of the
    // screen; categories, apps, tiles and buttons, see-through levels;
    // only its own elements
    "floating": {
        "name": "Floating",
        "exclusiveLayout": true,
        "values": {
            "menuAnchor": "screen",
            "menuOffsetX": 0,
            "menuOffsetY": 0,
            "cardColorMode": "none",
            "allAreaColorMode": "none",
            "allPieceColorMode": "default",
            "menuSurfaceTransparent": false,
            "menuSurfaceTransparency": 100,
            "menuSurfaceColorMode": "default",
            "menuAnimation": "screenCenter",
            "menuSurfaceTransparentEmptyOnly": false,
            "allPieceTransparent": true,
            "allPieceTransparency": 100,
            "allPieceTextColorMode": "surfaceText",
            "catChipBgColorMode": "none",
            "catChipBorderColorMode": "none",
            "catShowIcons": true,
            "catChipWidth": 180,
            "layoutMode": "custom",
            "appShowIcon": true,
            "appShowLabels": true,
            "appShowDescription": false,
            "appIconPosition": "top",
            "appTextAlign": "center",
            "appTextBackground": false,
            "appFullWidth": false,
            "appIconSize": 30,
            "appSpacing": 10,
            "appRowSpacing": 10,
            "appTooltips": false,
            "textSize": "theme.fontSizeSmall",
            "appTextColorMode": "default",
            "layout": [
                {
                    "id": "categories",
                    "col": 0,
                    "row": 0,
                    "w": 196,
                    "h": 1000
                },
                {
                    "id": "apps",
                    "col": 232,
                    "row": 0,
                    "w": 536,
                    "h": 808
                },
                {
                    "id": "shortcuts:default",
                    "col": 804,
                    "row": 0,
                    "w": 196,
                    "h": 231
                },
                {
                    "id": "actions:default",
                    "col": 232,
                    "row": 885,
                    "w": 536,
                    "h": 115
                }
            ],
            "layoutGrid": 1000,
            "lockedElements": []
        }
    },
    // As large as the screen allows: search on top, apps, categories as a
    // narrow column on the right, buttons below; only its own elements
    "fullscreen": {
        "name": "Fullscreen",
        "sizeOverlay": true,
        "exclusiveLayout": true,
        "values": {
            "menuSizeMode": "full",
            "cardPadding": 150,
            "scrollFade": true,
            "allAreaColorMode": "none",
            "allPieceColorMode": "none",
            "cardMargin": 9,
            "cardPaddingDocked": 60,
            "catChipWidth": 170,
            "catChipBgColorMode": "none",
            "catChipBorderColorMode": "none",
            "catChipSelColorMode": "none",
            "catChipSelTextColorMode": "primaryContainer",
            "catShowIcons": true,
            "catChipRowSpacing": 12,
            "catAreaBorderWidth": 0,
            "catAlignV": "center",
            // Opens on all apps; the instance's own choice still wins
            "startCategory": "__all",
            "layout": [
                {
                    "id": "search",
                    "col": 453,
                    "row": 0,
                    "w": 94,
                    "h": 63
                },
                {
                    "id": "categories",
                    "col": 943,
                    "row": 0,
                    "w": 57,
                    "h": 854
                },
                {
                    "id": "apps",
                    "col": 83,
                    "row": 146,
                    "w": 834,
                    "h": 708
                },
                {
                    "id": "actions:default",
                    "col": 411,
                    "row": 938,
                    "w": 178,
                    "h": 62
                }
            ],
            "layoutGrid": 1000,
            "lockedElements": []
        }
    },
    // Floating with see-through surfaces and soft nested-chip colours for
    // text and icons; only its own elements
    "glossy": {
        "name": "Glossy",
        "exclusiveLayout": true,
        "values": {
            "menuAnchor": "screen",
            "menuOffsetX": 0,
            "menuOffsetY": 0,
            "cardColorMode": "none",
            "allAreaColorMode": "none",
            "allPieceColorMode": "default",
            "menuSurfaceTransparent": true,
            "menuSurfaceTransparency": 100,
            "menuSurfaceColorMode": "default",
            "menuAnimation": "screenCenter",
            "menuSurfaceTransparentEmptyOnly": true,
            "allPieceTransparent": true,
            "allPieceTransparency": 100,
            "allPieceTextColorMode": "chipNested",
            "catChipBgColorMode": "none",
            "catChipBorderColorMode": "none",
            "catShowIcons": true,
            "catChipWidth": 180,
            "layoutMode": "custom",
            "appShowIcon": true,
            "appShowLabels": true,
            "appShowDescription": false,
            "appIconPosition": "top",
            "appTextAlign": "center",
            "appTextBackground": false,
            "appFullWidth": false,
            "appIconSize": 30,
            "appSpacing": 10,
            "appRowSpacing": 10,
            "appTooltips": false,
            "textSize": "theme.fontSizeSmall",
            "appTextColorMode": "default",
            "layout": [
                {
                    "id": "categories",
                    "col": 0,
                    "row": 0,
                    "w": 196,
                    "h": 1000
                },
                {
                    "id": "apps",
                    "col": 232,
                    "row": 0,
                    "w": 536,
                    "h": 808
                },
                {
                    "id": "shortcuts:default",
                    "col": 804,
                    "row": 0,
                    "w": 196,
                    "h": 231
                },
                {
                    "id": "actions:default",
                    "col": 232,
                    "row": 885,
                    "w": 536,
                    "h": 115
                }
            ],
            "layoutGrid": 1000,
            "lockedElements": [],
            "allPieceIconColorMode": "chipNested",
            "catIconColorMode": "chipNested",
            "catChipSelColorMode": "none",
            "tlAreaBorderWidth": 0,
            "tlAreaBorderColorMode": "default",
            "subTitleSize": "theme.fontSizeSmall",
            "subTitleColorMode": "chipNested",
            "subLineColorMode": "chipNested",
            "menuSurfaceNormalTextWithWindows": true
        }
    },
    // Docked at the left screen edge, full height: the apps as a list
    // of wide chips with their icons; its own size, only its own elements
    "leftMenu": {
        "name": "Left menu",
        "sizeOverlay": true,
        "exclusiveLayout": true,
        "values": {
            "cardPadding": 30,
            "scrollFade": true,
            "allAreaColorMode": "none",
            "allPieceColorMode": "none",
            "cardMargin": 9,
            "cardPaddingDocked": 30,
            "catChipWidth": 170,
            "catChipBgColorMode": "none",
            "catChipBorderColorMode": "none",
            "catChipSelColorMode": "none",
            "catChipSelTextColorMode": "primaryContainer",
            "catShowIcons": true,
            "catChipRowSpacing": 12,
            "catAreaBorderWidth": 0,
            "catAlignV": "center",
            "layout": [
                {
                    "id": "apps",
                    "col": 0,
                    "row": 0,
                    "w": 1000,
                    "h": 1000
                }
            ],
            "layoutGrid": 1000,
            "lockedElements": [],
            "menuAnchor": "left",
            "allPieceBorderWidth": 0,
            "allPieceBorderColorMode": "surfaceText",
            "cardColorMode": "none",
            "allPieceTextSize": "theme.fontSizeSmall",
            "allPieceIconColorMode": "default",
            "appsAreaTransparent": true,
            "appsAreaTransparency": 0,
            "appsAreaColorMode": "default",
            "appIconPosition": "left",
            "layoutMode": "custom",
            "appIconSize": 30,
            "appTooltips": true,
            "appShowDescription": false,
            "chipWidth": 275,
            "chipHeight": 40,
            "chipColorMode": "default",
            "chipTransparent": false,
            "chipTransparency": 0,
            "appIconOffset": 10,
            "appIconTextGap": 10,
            "appRowSpacing": 10,
            "appSpacing": 64,
            "appTextAlign": "left",
            "appFullWidth": false,
            "chipWidthMulti": 275,
            "appAlignAuto": "v",
            "chipRadius": 5,
            "appTextBackground": false,
            "menuSizeMode": "percent",
            "menuWidthPercent": 30,
            "menuHeightPercent": 100,
            "chipBorderWidth": 1,
            "chipBorderColorMode": "default",
            "chipBorderTransparent": true,
            "chipBorderTransparency": 81
        }
    },
    // Look of DMS' launcher: centred, its
    // size (550 × 640, as measured on the DMS launcher), search field over
    // the whole width, the apps as a single column list with descriptions;
    // only these two elements
    "launcher": {
        "name": "Dux Launcher",
        "sizeOverlay": true,
        "exclusiveLayout": true,
        "values": {
            "menuSizeMode": "pixels",
            "menuWidth": 550,
            "menuHeight": 640,
            "menuAnchor": "widget",
            "menuOffsetX": 0,
            "menuOffsetY": 0,
            "cardColorMode": "none",
            "cardMargin": 0,
            "cardMarginDocked": 0,
            "cardPadding": 12,
            "elementGap": 8,
            "allAreaColorMode": "none",
            "allAreaPadding": 0,
            "showEditButton": false,
            "showSettingsButton": false,
            "layoutMode": "custom",
            "appShowIcon": true,
            "appShowLabels": true,
            "appShowDescription": true,
            "appIconPosition": "left",
            "appTextAlign": "left",
            "appTextBackground": false,
            "appFullWidth": true,
            "appIconSize": 36,
            "appSpacing": 8,
            "appRowSpacing": 4,
            "searchHeight": 56,
            "searchRadius": 28,
            "searchBorderWidth": 2,
            "searchTextSize": "theme.fontSizeLarge",
            "searchFocusHighlight": true,
            "layout": [
                {
                    "id": "search",
                    "col": 0,
                    "row": 0,
                    "w": 1000,
                    "h": 100
                },
                {
                    "id": "apps",
                    "col": 0,
                    "row": 120,
                    "w": 1000,
                    "h": 880
                }
            ],
            "layoutGrid": 1000,
            "lockedElements": [],
            "appIconTextGap": 10,
            "appDescriptionGap": 3,
            "chipHeight": 50,
            "allPieceTransparent": false,
            "allPieceTransparency": 0,
            "allPieceSelTransparent": true,
            "allPieceSelTransparency": 100,
            "appsAreaBlur": false,
            "appIconOffset": 2,
            "allPieceColorMode": "card",
            "searchScopeStyle": "chips",
            "secTitleWeight": "normal",
            "secLineColorMode": "default",
            "secLineTransparent": false,
            "searchScopeShow": true,
            "appTooltips": true,
            "searchScopeSide": "bottom",
            "searchScopeAlign": "start",
            "scopeChipHeight": 25,
            "scopeChipSelColorMode": "none",
            "scopeChipSelTextColorMode": "primary",
            "scopeChipBgColorMode": "none",
            "scopeChipBorderColorMode": "none",
            "scopeChipHoverBgColorMode": "default",
            "scopeChipHoverBorderColorMode": "none",
            "scopeChipHoverTextColorMode": "default",
            "appAlignAuto": "off",
            "appAlignV": "start",
            "appAlignH": "center"
        }
    },
    // A small extra menu: only its own buttons element (the template's
    // elements alone: exclusiveLayout), no spacings, no surfaces; brings
    // the element's buttons along (contents, added if missing)
    "mini": {
        "name": "Mini bar",
        "sizeOverlay": true,
        "exclusiveLayout": true,
        "values": {
            "menuSizeMode": "pixels",
            "menuWidth": 165,
            "menuHeight": 50,
            "cardMargin": 0,
            "cardMarginDocked": 0,
            "cardPadding": 0,
            "elementGap": 0,
            "allAreaPadding": 0,
            "showEditButton": false,
            "showSettingsButton": false,
            "cardColorMode": "none",
            "allAreaColorMode": "none",
            "allPieceColorMode": "none",
            "layout": [{ "id": "actions:mini", "col": 0, "row": 0, "w": 1000, "h": 1000 }],
            "layoutGrid": 1000,
            "lockedElements": []
        },
        "contents": {
            "shortcuts": {
                "actions:mini": {
                    "title": "",
                    "columns": 3,
                    "arrangement": "flow",
                    "tiles": [
                        { "app": "act:poweroff", "size": "small", "col": 0, "row": 0 },
                        { "app": "act:reboot", "size": "small", "col": 1, "row": 0 },
                        { "app": "act:dmsSettings", "size": "small", "col": 2, "row": 0 }
                    ],
                    "defs": {
                        "act:poweroff": { "kind": "poweroff" },
                        "act:reboot": { "kind": "reboot" },
                        "act:dmsSettings": { "kind": "dmsSettings" }
                    }
                }
            }
        }
    }
};

var builtInOrder = ["standard", "minimal", "floating", "glossy", "fullscreen", "leftMenu", "launcher", "mini"];
