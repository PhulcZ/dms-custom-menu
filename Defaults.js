.pragma library

// CustomMenu defaults: one source for the widget and the settings page.

// Menu size: exact "pixels" (default) or "percent" of the screen (5 %
// steps). The same default on every screen; on smaller screens the menu is
// clamped to the free room (then it fills the screen).
var menuSizeMode = "pixels";
var menuWidth = 1500;
var menuHeight = 750;

// Mode of stored values: before the mode existed, "menuSizePixels" or stored
// percentages chose it
function sizeModeOf(values) {
    if (values.menuSizeMode)
        return values.menuSizeMode;
    if (values.menuSizePixels === true)
        return "pixels";
    if (values.menuWidthPercent !== undefined || values.menuHeightPercent !== undefined)
        return "percent";
    return menuSizeMode;
}

// Starting values of percent mode (set when switching, from the size shown
// at that moment)
var menuWidthPercent = 50;
var menuHeightPercent = 70;

// Transparency: off = fully opaque; on = the slider adds transparency from 0 %.
var cardTransparent = false;
var cardTransparency = 0;
var cardMargin = 15;
// Margin on the side at the bar/frame (docked menus)
var cardMarginDocked = 0;
var cardPadding = 50;

var appIconSize = 40;
var appSpacing = 35;
var appRowSpacing = 35;
var appShowLabels = true;
var textSize = 13;
var layoutMode = "grid";
var showSettingsButton = true;
var showEditButton = true;

// On by default: the app chips show level 4 (see the levels in Appearance)
var chipEnabled = true;
var chipTransparent = false;
var chipTransparency = 0;
var chipWidth = 96;
var chipHeight = 104;

// Edit app: "dms" = DMS only (like the launcher), "system" = start file in ~/.local/share/applications
var editScope = "dms";

// Categories: switcher style (chips, dropdown); position comes from the layout
var categoryStyle = "chips";
var showHiddenCategory = true;

// Category chips (defaults match DMS' DFilterChips)
var catChipHeight = 32;
var catChipWidth = 120;
var catChipSpacing = 8;
var catChipRowSpacing = 8;
var catChipBorderWidth = 1;

// Borders (0 = no border)
var cardBorderWidth = 0;
var chipBorderWidth = 0;

// Text weight: "normal", "medium", "bold"
var appTextWeight = "normal";
var catTextWeight = "normal";
var catTextSize = 12;
// Text alignment in the category chips: "auto" (one column left, else centred), "left", "center"
var catTextAlign = "auto";
// Vertical place of the category chips while all fit: "start", "center", "end"
var catAlignV = "start";

// Category icons (Material Symbols, monochrome)
var catShowIcons = false;
var catIconSize = 16;

// Tile building blocks; layoutMode only remembers the last chosen preset
var appShowIcon = true;
var appShowDescription = false;
var appIconPosition = "top";
var appTextAlign = "center";
var appTextBackground = false;
var appFullWidth = false;

// Icon on the side: extra shift towards the text
var appIconOffset = 0;

// Gaps inside a tile
var appIconTextGap = 8;
var appDescriptionGap = 2;

// Search field height (DMS default field height is about 42 px)
var searchHeight = 42;
// Search field (radius, border width, text size default to DMS' theme values)
var searchShowIcon = true;
var searchHideIconWhileTyping = false;
// Hint text in the empty search field: half transparent
var searchPlaceholderTransparent = true;
var searchPlaceholderTransparency = 50;
var searchIconName = "search";
var searchTextWeight = "normal";

// Icon of the widget in the bar
var barIcon = "circle";

// Menu position: "widget" (DMS default), "left"/"right"/"top"/"bottom"
// (out of that screen edge) or "screen" (free); offsets in px from the
// centre, positive = right/down
var menuAnchor = "widget";
// Shadow around the free menu (only if DMS' popout shadow is on)
var menuShadow = true;
var menuOffsetX = 0;
var menuOffsetY = 0;

// Icon suggestions per use in the icon picker ("Suggestions" chip).
// Material Symbols names only (DMS' DIcon draws them; the DMS icons are
// Material Symbols as well).
var iconSuggestions = {
    "search": ["search", "manage_search", "saved_search", "travel_explore", "find_in_page", "image_search", "zoom_in", "pageview", "youtube_searched_for", "screen_search_desktop", "quick_reference_all", "frame_inspect", "troubleshoot", "filter_list", "plagiarism"],
    // "apps" = DMS' launcher (nine dots), "dashboard" = the DMS dash
    "bar": ["circle", "adjust", "check_box_outline_blank", "background_dot_small", "pending", "apps", "dialpad", "dashboard", "space_dashboard", "grid_view", "dataset", "view_cozy", "view_compact_alt", "widgets", "widget_menu", "view_module", "window", "crop_3_2", "menu", "menu_open", "arrow_menu_open", "arrow_menu_close", "dropdown_menu", "arrow_upward", "arrow_downward", "arrow_back", "arrow_forward", "expand_circle_up", "expand_circle_down", "expand_circle_right", "arrow_drop_down_circle", "home", "rocket_launch", "explore", "star", "hexagon", "pentagon", "token", "blur_on", "motion_photos_on", "deployed_code", "category", "interests", "auto_awesome", "assistant_on_hub"],
    "category": ["apps", "folder", "work", "school", "code", "terminal", "developer_mode", "brush", "palette", "photo_camera", "image", "movie", "music_note", "headphones", "sports_esports", "videogame_asset", "language", "public", "chat", "mail", "settings", "tune", "build", "handyman", "science", "calculate", "edit_note", "description", "inventory_2", "shopping_bag", "desktop_windows", "home_repair_service", "star", "favorite", "visibility_off"]
};

// Inner padding of an element with its own background
var areaPadding = 12;

// Gap between neighbouring elements (px)
var elementGap = 5;

// Search behaviour
var searchEnterLaunches = true;
var searchShowQueryChip = true;

// Shortcuts elements (own look, independent of the apps element)
// Inner grid of the shortcuts elements: cell size and gap
var scUnit = 40;
var scSpacing = 4;
var scShowLabels = false;
var scTextSize = 11;
var scTitleSize = 13;

// Where category assignments and hiding from the menu apply: "both" (CustomMenu + DMS launcher) or "menu"
var categoryScope = "menu";

// Title of a shortcuts element: side, alignment along it, gap around the text
var scTitleSide = "top";
var scTitleAlign = "start";
var scTitleGap = 6;

// Shortcut tiles: distance icon ↔ tile edge (small / large tile)
var scIconPadSmall = 7;
var scIconPadLarge = 14;

// Content alignment inside the apps element (fixed, see appAlignAuto)
var appAlignH = "center";
var appAlignV = "start";
// Automatic (default "both"): the chip grid centred (equal margins; fewer
// apps than a row: by the columns they use), vertically centred while all
// rows fit, from the top when it scrolls; a last row that is not full
// stays left. "v" = only vertically, "off" = the fixed alignment above
var appAlignAuto = "both";
// Where the tiles of a tile element sit when it is bigger than them: the
// grid cells (grid) or the tiles (row) centred both ways, so the margins
// left/right and top/bottom are equal
var tlAlignH = "center";
var tlAlignV = "center";

// Tooltips (name, apps also the description) on hover
var appTooltips = false;
var scTooltips = true;

// Search results: files and folders show where they are
var searchPathShow = true;
var searchPathDepth = 2;
var searchFolderCount = true;

// Search scope switcher in the search element
var searchScopeShow = true;
var searchScopeStyle = "field";
// Chips outside the field: side of the field and alignment along it
// ("fill" = the whole width, top/bottom only)
var searchScopeSide = "bottom";
var searchScopeAlign = "fill";
var searchScopeTextSize = 12;

// Search result sections: space between heading and results
var secTitleGap = 8;

// Search field: focus colour and one pixel thicker border while focused
var searchFocusHighlight = false;

// Arrangement of a fresh menu, in cells of a 48 × 48 grid (scaled to the
// menu size). Shortcuts and buttons elements sizes follow their content.
// Default arrangement in thousandths of the canvas width and height
var defaultLayoutGrid = 1000;
// Menu grid: square cells of exactly this size (px); an even number of
// columns and rows (a true middle), as many as fit best into the canvas;
// the grid is centred on it (reaching up to half a cell into the canvas
// padding, or staying that much inside). Layouts are stored in thousandths
// of the width/height.
var gridCell = 25;
// Scrolling areas fade out softly at the top and bottom
var scrollFade = false;
// Edit mode: grid lines shown
var editShowGrid = true;
var layoutStoreGrid = 1000;
var defaultLayout = [
    { "id": "search", "col": 0, "row": 0, "w": 196, "h": 115 },
    { "id": "categories", "col": 0, "row": 192, "w": 196, "h": 616 },
    { "id": "apps", "col": 232, "row": 0, "w": 536, "h": 808 },
    { "id": "shortcuts:default", "col": 804, "row": 0, "w": 196, "h": 231 },
    { "id": "actions:default", "col": 411, "row": 885, "w": 178, "h": 115 }
];
// Their contents (tile elements): an empty one on the grid (apps are
// dragged in) and the session buttons flowing in a row
var defaultShortcuts = {
    "shortcuts:default": { "title": "", "tiles": [], "columns": 4, "defs": {}, "arrangement": "grid" },
    "actions:default": {
        "title": "",
        "columns": 5,
        "arrangement": "flow",
        "tiles": [
            { "app": "act:lock", "size": "small", "col": 0, "row": 0 },
            { "app": "act:logout", "size": "small", "col": 1, "row": 0 },
            { "app": "act:reboot", "size": "small", "col": 2, "row": 0 },
            { "app": "act:poweroff", "size": "small", "col": 3, "row": 0 },
            { "app": "act:dmsSettings", "size": "small", "col": 4, "row": 0 }
        ],
        "defs": {
            "act:lock": { "kind": "lock" },
            "act:logout": { "kind": "logout" },
            "act:reboot": { "kind": "reboot" },
            "act:poweroff": { "kind": "poweroff" },
            "act:dmsSettings": { "kind": "dmsSettings" }
        }
    }
};

// Size of an element added with "+" in edit mode (cells of the 48 × 48
// grid); the search keeps its own height, a new tile element starts with
// 4 × 4 inner cells
var newElementW = 7;
var newElementH = 7;

// New spacer in a buttons element (px)
var btSpacerPx = 12;

// Category selected when the menu opens (favourites; All if it is gone)
var startCategory = "custom:favorites";

// Opening animation: "dms", "screenCenter", "menuCenter"
var menuAnimation = "dms";

// Icons of DMS' app categories (Material Symbols). DMS keys its own icons
// by the English name, but its category names are translated, so outside
// English it finds none (folder); two categories have none at all. Keyed
// by the English name with DMS' translation context, looked up through the
// translation (tr(name, context) as DMS translates them).
var categoryIcons = {
    "Media": ["play_circle", "launcher app category for audio and video apps"],
    "Development": ["code", "launcher app category"],
    "Education": ["school", "launcher app category"],
    "Games": ["sports_esports", "launcher app category"],
    "Graphics": ["palette", "launcher app category"],
    "Internet": ["language", ""],
    "Office": ["description", "launcher app category"],
    "Science": ["science", "launcher app category"],
    "Settings": ["settings", ""],
    "System": ["computer", ""],
    "Utilities": ["build", ""]
};

// DMS categories are stored by a key independent of the language:
// "dms:" + the first freedesktop category DMS shows under that name (its
// names are translated, so a language switch lost everything stored by
// name: deleted, hidden, order, icons). map: AppSearchService._categoryMap
// (freedesktop category → DMS name). Unknown names stay as they are.
function dmsCategoryKey(map, name) {
    for (const fd of Object.keys(map ?? {}))
        if (map[fd] === name)
            return "dms:" + fd;
    return name;
}
// The DMS name (translated) of a stored key
function dmsCategoryName(map, key) {
    if (!String(key).startsWith("dms:"))
        return key;
    return (map ?? {})[key.slice(4)] ?? key.slice(4);
}

// Icon of a DMS category name as shown (translated); fallback if unknown
// (e.g. a launcher plugin's category). tr: (text, context) → translation.
function categoryIcon(name, tr, fallback) {
    for (const key of Object.keys(categoryIcons)) {
        const entry = categoryIcons[key];
        if (name === key || name === tr(key, entry[1]) || name === tr(key, ""))
            return entry[0];
    }
    return fallback;
}
