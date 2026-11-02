import QtQuick
import Qt.labs.folderlistmodel
import "../../FontLogos.js" as FontLogos
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets

// Icon picker inside the menu. DMS' FileBrowserModal is a regular window
// and would sit below the popout, hence a view inside the card,
// built from DMS building blocks (DButton, DActionButton,
// DTextField, DGridView, StyledRect).
//
// Places: folder of the current icon, icon theme (as set in DMS),
// common icon folders, up to three favourites from the plugin settings.
FocusScope {
    id: root

    property string currentIcon: ""
    // Theme subfolders to open when there is no current icon file, searched
    // in the active theme and the themes it inherits from,
    // e.g. ["categories/scalable", "categories"]
    property var hintFolders: []
    property var favorites: []
    property color textColor: Theme.surfaceText

    signal picked(string path)
    signal cancelled

    readonly property string home: Quickshell.env("HOME") || ""
    // Active theme according to DMS' icon index (setting or detected from the system)
    readonly property string themeName: IconThemeService.managedTheme || ""

    // Folder of the active theme (found by reading index.theme files below)
    property string themeDir: ""

    // File of the current icon: a path directly, an icon name via DMS' icon
    // index (the same resolution DMS uses to show the icon).
    function resolveFile(name) {
        if (!name)
            return "";
        if (name.startsWith("/"))
            return name;
        const url = IconThemeService.resolve(name);
        return url ? decodeURIComponent(url.replace(/^file:\/\//, "")) : "";
    }
    readonly property string currentIconFile: resolveFile(currentIcon)
    readonly property string currentIconDir: currentIconFile ? currentIconFile.substring(0, currentIconFile.lastIndexOf("/")) : ""

    readonly property var places: {
        const list = [];
        if (currentIconDir)
            list.push({ label: I18n.trFor("customMenu", "Current"), icon: "image", path: currentIconDir });
        if (themeDir)
            list.push({ label: themeName, icon: "palette", path: themeDir });
        list.push({ label: I18n.trFor("customMenu", "My icons"), icon: "person", path: home + "/.local/share/icons" });
        list.push({ label: "hicolor", icon: "apps", path: "/usr/share/icons/hicolor" });
        list.push({ label: "pixmaps", icon: "image", path: "/usr/share/pixmaps" });
        for (let i = 0; i < favorites.length; i++) {
            const p = (favorites[i] || "").trim().replace(/^~/, home);
            if (p)
                list.push({ label: p.substring(p.lastIndexOf("/") + 1) || p, icon: "star", path: p });
        }
        return list;
    }

    property string folder: ""
    // Selected file: preview on top, highlighted tile in the grid. Applied only
    // with "Use icon" or a double click.
    property string selectedFile: ""

    // ── Material Symbols mode ────────────────────────────────────────────
    // Second source next to the folders: every Material Symbols icon (name
    // list from Google's material-design-icons, assets/material-symbols.json).
    // The result is the symbol name, with symbolPrefix in front (e.g.
    // "material:" for app icons, where DMS' AppIconRenderer expects it).
    property bool allowSymbols: true
    property string symbolPrefix: ""
    property bool symbolMode: false
    // "Suggestions" chip: a fixed list of symbol names fitting the use
    // (search field, bar icon, …); hidden when empty
    property var suggestions: []
    property bool suggestMode: false
    // Distro and project logos (font-logos), values "logo:<name>"; only
    // where the icon is drawn by FlexIcon (allowLogos)
    property bool allowLogos: false
    property bool logoMode: false
    // Any symbol view (suggestions, Material Symbols, DMS icons, logos)
    readonly property bool glyphMode: symbolMode || dmsMode || suggestMode || logoMode
    // Value for a chosen glyph name
    function glyphValue(name) {
        return logoMode ? "logo:" + name : symbolPrefix + name;
    }
    property string selectedSymbol: ""
    readonly property string currentSymbol: {
        if (!currentIcon || currentIcon.startsWith("/"))
            return "";
        if (currentIcon.startsWith("logo:"))
            return currentIcon.substring(5);
        return currentIcon.startsWith("material:") ? currentIcon.substring(9) : currentIcon;
    }
    FileView {
        id: symbolFile
        path: Qt.resolvedUrl("../../assets/material-symbols.json").toString().replace(/^file:\/\//, "")
        printErrors: false
    }
    readonly property var allSymbols: {
        try {
            return JSON.parse(symbolFile.text() || "[]");
        } catch (e) {
            return [];
        }
    }
    // DMS icons: the hand-picked groups of DMS' own DIconPicker, read from
    // a hidden instance so names and translations follow DMS
    property bool dmsMode: false
    DIconPicker {
        id: dmsIconSource
        visible: false
        width: 0
        height: 0
    }
    readonly property var dmsGroups: dmsIconSource.iconCategories || []

    readonly property var symbols: {
        const q = search.text.trim().toLowerCase().replace(/[\s-]+/g, "_");
        const source = logoMode ? FontLogos.names : suggestMode ? suggestions : allSymbols;
        return q ? source.filter(n => n.indexOf(q) >= 0) : source;
    }

    function open() {
        search.text = "";
        selectedFile = currentIconFile;
        selectedSymbol = currentSymbol;
        // A symbol as current icon (and no file for it) → open in symbol mode
        symbolMode = allowSymbols && currentSymbol !== "" && !currentIconFile;
        // A symbol from the DMS groups → open those instead
        // Order: suggestions, DMS groups, all Material Symbols
        suggestMode = symbolMode && suggestions.indexOf(currentSymbol) >= 0;
        dmsMode = symbolMode && !suggestMode && dmsGroups.some(g => g.icons.indexOf(currentSymbol) >= 0);
        if (dmsMode || suggestMode)
            symbolMode = false;
        // A logo → the logos
        logoMode = allowLogos && currentIcon.startsWith("logo:");
        if (logoMode) {
            symbolMode = false;
            dmsMode = false;
            suggestMode = false;
        }
        _scrollPending = true;
        folder = currentIconDir || hintDir || themeDir || (home + "/.local/share/icons");
        // The hint folder may still be searched for; switch once it is found
        _waitingForHint = !currentIconDir && !hintDir && hintFolders.length > 0;
        Qt.callLater(() => search.forceActiveFocus());
    }

    function goUp() {
        const i = folder.lastIndexOf("/");
        if (i > 0)
            folder = folder.substring(0, i);
    }

    // ── Theme lookup via index.theme (the XDG icon theme spec) ───────────
    // Walks the active theme and the themes it inherits from. Each theme's
    // index.theme names its parents (Inherits=) and its folders
    // (Directories=), so no folder needs to be probed on disk.
    readonly property var baseDirs: [home + "/.local/share/icons/", home + "/.icons/", "/usr/share/icons/"]
    property var _queue: []
    property var _seen: ({})
    property int _base: 0
    property string hintDir: ""
    property bool _waitingForHint: false
    property var _hintCandidates: []
    property int _hintIndex: 0
    property bool _lookupDone: false

    // Check the collected folders in order, skip empty ones (a theme can list
    // a folder in index.theme without shipping icons there)
    FolderListModel {
        showDirs: false
        nameFilters: ["*.svg", "*.png"]
        folder: root._lookupDone && !root.hintDir && root._hintIndex < root._hintCandidates.length ? "file://" + root._hintCandidates[root._hintIndex] : ""
        onStatusChanged: {
            if (status !== FolderListModel.Ready || root.hintDir)
                return;
            if (count > 0)
                root.hintDir = root._hintCandidates[root._hintIndex];
            else
                root._hintIndex++;
        }
    }

    function startLookup() {
        themeDir = "";
        hintDir = "";
        _hintCandidates = [];
        _hintIndex = 0;
        _lookupDone = false;
        _queue = themeName ? [themeName, "hicolor"] : ["hicolor"];
        _seen = {};
        _base = 0;
        nextLookup();
    }

    function nextLookup() {
        while (_queue.length > 0 && _seen[_queue[0]] && _base === 0)
            _queue = _queue.slice(1);
        if (_queue.length === 0) {
            themeFile.path = "";
            _hintIndex = 0;
            _lookupDone = true;
            return;
        }
        const path = baseDirs[_base] + _queue[0] + "/index.theme";
        Qt.callLater(() => themeFile.path = path);
    }

    FileView {
        id: themeFile
        printErrors: false
        onLoaded: {
            const theme = root._queue[0];
            const dir = root.baseDirs[root._base] + theme;
            const text = themeFile.text();
            if (theme === root.themeName && !root.themeDir)
                root.themeDir = dir;
            const dirs = ((text.match(/^Directories\s*=\s*(.+)$/m) || [])[1] || "").split(",").map(d => d.trim());
            // Collect every matching folder; the first non-empty one wins
            const hits = root.hintFolders.filter(rel => dirs.indexOf(rel) >= 0).map(rel => dir + "/" + rel);
            if (hits.length > 0)
                root._hintCandidates = root._hintCandidates.concat(hits);
            const parents = ((text.match(/^Inherits\s*=\s*(.+)$/m) || [])[1] || "").split(",").map(t => t.trim()).filter(t => t);
            const seen = Object.assign({}, root._seen);
            seen[theme] = true;
            root._seen = seen;
            // Parents before hicolor, keeping the order
            const rest = root._queue.slice(1).filter(t => parents.indexOf(t) < 0);
            root._queue = parents.filter(t => !seen[t]).concat(rest);
            root._base = 0;
            root.nextLookup();
        }
        onLoadFailed: {
            if (++root._base >= root.baseDirs.length) {
                root._base = 0;
                const seen = Object.assign({}, root._seen);
                seen[root._queue[0]] = true;
                root._seen = seen;
                root._queue = root._queue.slice(1);
            }
            root.nextLookup();
        }
    }

    onThemeNameChanged: startLookup()
    onHintFoldersChanged: startLookup()
    Component.onCompleted: startLookup()

    onHintDirChanged: {
        if (_waitingForHint && hintDir) {
            folder = hintDir;
            _waitingForHint = false;
        }
    }

    FolderListModel {
        id: entries
        folder: root.folder ? "file://" + root.folder : ""
        showDirsFirst: true
        showDotAndDotDot: false
        nameFilters: search.text.trim() ? ["*" + search.text.trim() + "*"] : ["*.svg", "*.png", "*.xpm"]
        caseSensitive: false
        // Also show folders while searching (folder filters do not apply to dirs)
        showOnlyReadable: true
        // Scroll to the selected icon after loading (large theme folders)
        onStatusChanged: if (status === FolderListModel.Ready) scrollTimer.restart()
    }

    // Scroll to the selected icon only once the grid has its final
    // height (the header builds up too); otherwise the icon ends up too low.
    // Position computed directly: row × cell height, centred in the view.
    property bool _scrollPending: false
    function scrollToSelected() {
        const view = symbolMode || suggestMode ? symbolGrid : grid;
        if (!_scrollPending || view.height <= 0)
            return;
        if (symbolMode || suggestMode) {
            const k = symbols.indexOf(selectedSymbol);
            if (k >= 0) {
                const c = Math.max(1, Math.floor(symbolGrid.width / symbolGrid.cellWidth));
                const top = Math.floor(k / c) * symbolGrid.cellHeight;
                symbolGrid.contentY = Math.max(0, Math.min(top - (symbolGrid.height - symbolGrid.cellHeight) / 2, symbolGrid.contentHeight - symbolGrid.height));
            }
            _scrollPending = false;
            return;
        }
        if (!selectedFile)
            return;
        const i = entries.indexOf("file://" + selectedFile);
        if (i < 0)
            return;
        const cols = Math.max(1, Math.floor(grid.width / grid.cellWidth));
        const rowTop = Math.floor(i / cols) * grid.cellHeight;
        const target = rowTop - (grid.height - grid.cellHeight) / 2;
        grid.contentY = Math.max(0, Math.min(target, grid.contentHeight - grid.height));
        _scrollPending = false;
    }
    Timer {
        id: scrollTimer
        interval: 60
        onTriggered: root.scrollToSelected()
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.cancelled();
            event.accepted = true;
        }
    }

    // Header in two boxes: places + path on the left, search + preview on the right.
    // Side by side if both can be at least boxMinWidth wide,
    // stacked otherwise.
    readonly property real boxMinWidth: 420
    readonly property bool sideBySide: width >= boxMinWidth * 2 + Theme.spacingM
    readonly property real boxWidth: sideBySide ? (width - Theme.spacingM) / 2 : width

    component Box: StyledRect {
        default property alias content: boxColumn.data
        readonly property real naturalHeight: boxColumn.implicitHeight + Theme.spacingM * 2
        width: root.boxWidth
        // Side by side both have the same height (the taller one wins)
        height: root.sideBySide ? Math.max(placesBox.naturalHeight, searchBox.naturalHeight) : naturalHeight
        radius: Theme.cornerRadius
        color: Theme.foregroundColor(Theme.chipSurface)

        Column {
            id: boxColumn
            x: Theme.spacingM
            // vertically centred when the box is taller than its content
            y: Math.max(Theme.spacingM, (parent.height - implicitHeight) / 2)
            width: parent.width - Theme.spacingM * 2
            spacing: Theme.spacingS
        }
    }

    Column {
        id: header
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: I18n.trFor("customMenu", "Choose icon")
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            color: Theme.primary
        }

        Flow {
            width: parent.width
            spacing: Theme.spacingM

            // Box 1: places and current path
            Box {
                id: placesBox
                Flow {
                    width: parent.width
                    spacing: Theme.spacingXS

                    // Fitting symbols for this use; own colour (primary)
                    DButton {
                        visible: root.allowSymbols && root.suggestions.length > 0
                        iconName: "lightbulb"
                        text: I18n.trFor("customMenu", "Suggestions")
                        backgroundColor: root.suggestMode ? Theme.primary : Theme.primaryContainer
                        textColor: root.suggestMode ? Theme.onPrimary : Theme.onPrimaryContainer
                        onClicked: {
                            root.symbolMode = false;
                            root.dmsMode = false;
                            root.logoMode = false;
                            root.suggestMode = true;
                            root._scrollPending = true;
                            scrollTimer.restart();
                        }
                    }

                    Repeater {
                        model: root.places
                        DButton {
                            required property var modelData
                            iconName: modelData.icon
                            text: modelData.label
                            onClicked: {
                                root.symbolMode = false;
                                root.dmsMode = false;
                                root.suggestMode = false;
                                root.logoMode = false;
                                root.folder = modelData.path;
                            }
                        }
                    }

                    // Different colour: not a folder but the symbol font
                    DButton {
                        visible: root.allowSymbols
                        iconName: "interests"
                        text: "Material Symbols"
                        backgroundColor: root.symbolMode ? Theme.tertiary : Theme.tertiaryContainer
                        textColor: root.symbolMode ? Theme.onTertiary : Theme.onTertiaryContainer
                        onClicked: {
                            root.dmsMode = false;
                            root.suggestMode = false;
                            root.logoMode = false;
                            root.symbolMode = true;
                            root._scrollPending = true;
                            scrollTimer.restart();
                        }
                    }

                    DButton {
                        visible: root.allowSymbols
                        iconName: "auto_awesome"
                        text: I18n.trFor("customMenu", "DMS icons")
                        backgroundColor: root.dmsMode ? Theme.secondary : Theme.secondaryContainer
                        textColor: root.dmsMode ? Theme.onSecondary : Theme.onSecondaryContainer
                        onClicked: {
                            root.symbolMode = false;
                            root.suggestMode = false;
                            root.logoMode = false;
                            root.dmsMode = true;
                        }
                    }

                    // Own colour: the logo font
                    DButton {
                        visible: root.allowLogos
                        iconName: "deployed_code"
                        text: I18n.trFor("customMenu", "Distro logos")
                        backgroundColor: root.logoMode ? Theme.primary : Theme.primaryContainer
                        textColor: root.logoMode ? Theme.onPrimary : Theme.onPrimaryContainer
                        onClicked: {
                            root.symbolMode = false;
                            root.suggestMode = false;
                            root.dmsMode = false;
                            root.logoMode = true;
                            root._scrollPending = true;
                            scrollTimer.restart();
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    DActionButton {
                        id: upButton
                        visible: !root.glyphMode
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "arrow_upward"
                        iconColor: root.textColor
                        tooltipText: I18n.trFor("customMenu", "Up")
                        onClicked: root.goUp()
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - (upButton.visible ? upButton.width + Theme.spacingS : 0)
                        text: root.suggestMode ? I18n.trFor("customMenu", "Suggestions") + " · " + root.symbols.length : root.symbolMode ? "Material Symbols · " + root.symbols.length : (root.dmsMode ? I18n.trFor("customMenu", "DMS icons") : root.folder)
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        elide: Text.ElideLeft
                    }
                }
            }

            // Box 2: search field, icon, name/path, all the same height.
            // Side by side if there is room (search field fixed, text takes the rest),
            // stacked at full width otherwise.
            Box {
                id: searchBox

                readonly property real rowHeight: search.height
                readonly property real searchWidth: 280
                readonly property real textMinWidth: 220
                readonly property bool inline: width - Theme.spacingM * 2 >= searchWidth + rowHeight + textMinWidth + Theme.spacingM * 2

                Flow {
                    width: parent.width
                    spacing: Theme.spacingM

                    DTextField {
                        id: search
                        width: searchBox.inline ? searchBox.searchWidth : parent.width
                        placeholderText: I18n.trFor("customMenu", "Filter")
                        leftIconName: "search"
                    }

                    FlexIcon {
                        visible: root.glyphMode
                        icon: root.selectedSymbol ? (root.logoMode ? "logo:" + root.selectedSymbol : root.selectedSymbol) : ""
                        size: searchBox.rowHeight
                        color: root.textColor
                    }

                    Image {
                        visible: !root.glyphMode
                        width: searchBox.rowHeight
                        height: searchBox.rowHeight
                        source: root.selectedFile ? "file://" + root.selectedFile : ""
                        sourceSize.width: 128
                        sourceSize.height: 128
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Column {
                        width: searchBox.inline ? parent.width - searchBox.searchWidth - searchBox.rowHeight - Theme.spacingM * 2 : parent.width - searchBox.rowHeight - Theme.spacingM
                        height: searchBox.rowHeight
                        spacing: Theme.spacingXXS

                        Item {
                            width: 1
                            height: Math.max(0, (parent.height - nameLabel.height - pathLabel.height - parent.spacing) / 2)
                        }
                        StyledText {
                            id: nameLabel
                            width: parent.width
                            text: root.glyphMode ? (root.selectedSymbol || I18n.trFor("customMenu", "No icon selected")) : (root.selectedFile ? root.selectedFile.substring(root.selectedFile.lastIndexOf("/") + 1) : I18n.trFor("customMenu", "No icon selected"))
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Theme.fontWeightMedium
                            color: root.textColor
                            elide: Text.ElideMiddle
                        }
                        StyledText {
                            id: pathLabel
                            width: parent.width
                            text: root.suggestMode ? I18n.trFor("customMenu", "Suggestions") : root.symbolMode ? "Material Symbols" : root.dmsMode ? I18n.trFor("customMenu", "DMS icons") : (root.selectedFile ? root.selectedFile.substring(0, root.selectedFile.lastIndexOf("/")) : "")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            elide: Text.ElideLeft
                        }
                    }
                }
            }
        }
    }

    // Symbol grid (symbol mode)
    DGridView {
        id: symbolGrid
        visible: root.symbolMode || root.suggestMode || root.logoMode
        anchors.top: header.bottom
        anchors.topMargin: Theme.spacingL
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.spacingS
        clip: true
        onHeightChanged: if (root._scrollPending) scrollTimer.restart()

        readonly property int tile: 88
        cellWidth: Math.floor(width / Math.max(1, Math.floor(width / tile)))
        cellHeight: tile
        model: root.symbolMode || root.suggestMode || root.logoMode ? root.symbols : []

        delegate: Item {
            id: symbolCell
            required property string modelData
            readonly property bool selected: modelData === root.selectedSymbol
            width: symbolGrid.cellWidth
            height: symbolGrid.cellHeight

            StyledRect {
                anchors.fill: parent
                anchors.margins: Theme.spacingXS
                radius: Theme.cornerRadius
                color: symbolCell.selected ? Theme.primaryContainer : (symbolArea.containsMouse ? Theme.withAlpha(Theme.onSurface, Theme.stateLayerHover) : "transparent")
                border.width: symbolCell.selected ? 2 : 0
                border.color: Theme.primary
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - Theme.spacingS * 2
                spacing: Theme.spacingXS

                FlexIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: root.logoMode ? "logo:" + symbolCell.modelData : symbolCell.modelData
                    size: 32
                    color: root.textColor
                }

                StyledText {
                    width: parent.width
                    text: symbolCell.modelData
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.textColor
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    elide: Text.ElideMiddle
                }
            }

            MouseArea {
                id: symbolArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectedSymbol = symbolCell.modelData
                onDoubleClicked: root.picked(root.glyphValue(symbolCell.modelData))
            }
        }
    }

    // DMS icons view: DIconPicker's groups, filtered by the search field
    DFlickable {
        id: dmsView
        visible: root.dmsMode
        anchors.top: header.bottom
        anchors.topMargin: Theme.spacingL
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.spacingS
        clip: true
        contentHeight: dmsColumn.implicitHeight

        Column {
            id: dmsColumn
            width: dmsView.width
            spacing: Theme.spacingM

            Repeater {
                model: root.dmsMode ? root.dmsGroups : []

                Column {
                    id: group
                    required property var modelData
                    readonly property var icons: {
                        const q = search.text.trim().toLowerCase().replace(/[\s-]+/g, "_");
                        return q ? modelData.icons.filter(n => n.indexOf(q) >= 0) : modelData.icons;
                    }
                    visible: icons.length > 0
                    width: dmsColumn.width
                    spacing: Theme.spacingXS

                    StyledText {
                        text: group.modelData.name
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeightMedium
                        color: Theme.primary
                    }

                    Flow {
                        width: parent.width
                        Repeater {
                            model: group.icons
                            Item {
                                id: dmsCell
                                required property string modelData
                                readonly property bool selected: modelData === root.selectedSymbol
                                width: 88
                                height: 72

                                StyledRect {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingXS
                                    radius: Theme.cornerRadius
                                    color: dmsCell.selected ? Theme.primaryContainer : (dmsArea.containsMouse ? Theme.withAlpha(Theme.onSurface, Theme.stateLayerHover) : "transparent")
                                    border.width: dmsCell.selected ? 2 : 0
                                    border.color: Theme.primary
                                }

                                Column {
                                    anchors.centerIn: parent
                                    width: parent.width - Theme.spacingS * 2
                                    spacing: Theme.spacingXXS
                                    DIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        name: dmsCell.modelData
                                        size: 28
                                        color: root.textColor
                                    }
                                    StyledText {
                                        width: parent.width
                                        text: dmsCell.modelData
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: root.textColor
                                        horizontalAlignment: Text.AlignHCenter
                                        maximumLineCount: 1
                                        elide: Text.ElideMiddle
                                    }
                                }

                                MouseArea {
                                    id: dmsArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedSymbol = dmsCell.modelData
                                    onDoubleClicked: root.picked(root.symbolPrefix + dmsCell.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    DGridView {
        id: grid
        visible: !root.glyphMode
        onHeightChanged: if (root._scrollPending) scrollTimer.restart()
        onWidthChanged: if (root._scrollPending) scrollTimer.restart()
        anchors.top: header.bottom
        anchors.topMargin: Theme.spacingL
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.spacingS
        clip: true

        readonly property int tile: 88
        cellWidth: Math.floor(width / Math.max(1, Math.floor(width / tile)))
        cellHeight: tile
        model: entries

        delegate: Item {
            id: cell
            required property string fileName
            required property string filePath
            required property bool fileIsDir
            width: grid.cellWidth
            height: grid.cellHeight

            readonly property bool selected: !fileIsDir && filePath === root.selectedFile

            // Tile: selected in DMS' accent container colour, otherwise only on hover
            StyledRect {
                anchors.fill: parent
                anchors.margins: Theme.spacingXS
                radius: Theme.cornerRadius
                color: cell.selected ? Theme.primaryContainer : (area.containsMouse ? Theme.withAlpha(Theme.onSurface, Theme.stateLayerHover) : "transparent")
                border.width: cell.selected ? 2 : 0
                border.color: Theme.primary
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - Theme.spacingS * 2
                spacing: Theme.spacingXS

                Item {
                    id: iconBox
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 40
                    height: 40
                    DIcon {
                        anchors.centerIn: parent
                        visible: cell.fileIsDir
                        name: "folder"
                        size: 36
                        color: Theme.primary
                    }
                    Image {
                        anchors.fill: parent
                        visible: !cell.fileIsDir
                        source: cell.fileIsDir ? "" : "file://" + cell.filePath
                        sourceSize.width: 80
                        sourceSize.height: 80
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                    }
                }

                // Single line, middle elided: start and extension stay visible
                StyledText {
                    width: parent.width
                    text: cell.fileName
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.textColor
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    elide: Text.ElideMiddle
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (cell.fileIsDir) {
                        search.text = "";
                        root.folder = cell.filePath;
                    } else {
                        root.selectedFile = cell.filePath;
                    }
                }
                onDoubleClicked: if (!cell.fileIsDir) root.picked(cell.filePath)
            }
        }
    }

    Row {
        id: footer
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: Theme.spacingS

        DButton {
            text: I18n.trFor("customMenu", "Cancel")
            onClicked: root.cancelled()
        }
        DButton {
            iconName: "check"
            text: I18n.trFor("customMenu", "Use icon")
            enabled: root.glyphMode ? root.selectedSymbol !== "" : root.selectedFile !== ""
            onClicked: root.picked(root.glyphMode ? root.glyphValue(root.selectedSymbol) : root.selectedFile)
        }
    }
}
