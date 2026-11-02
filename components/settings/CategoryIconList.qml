import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import "../../ColorRoles.js" as ColorRoles
import "../../Defaults.js" as Defaults
import "../common"

// Icon per category via IconPickerDialog: an icon file (coloured, stored as a
// path), a Material Symbols or DMS icon (monochrome, stored as its name).
// Empty = icon of the DMS launcher.
// Stored as one object { category: iconName } under "catIcons".
// Colour per category (symbol icons only; icon files keep their colours):
// { category: "#rrggbb" } under "catIconColors"; empty = colour of all icons.
Column {
    id: root

    DmsAppLists {
        id: dmsLists
    }

    // Same indent as DMS' toggles (label and switch inset by spacingM)
    x: Theme.spacingM
    width: parent ? parent.width - Theme.spacingM * 2 : 0
    spacing: Theme.spacingS

    property var icons: ({})
    // Symbol names for the picker's "Suggestions" chip
    property var suggestions: []
    property var colors: ({})
    // Bumped when the plugin data changes (colour of all icons may change)
    property int revision: 0
    Connections {
        target: PluginService
        function onPluginDataChanged(pluginId) {
            root.revision++;
        }
    }
    // Colour of all category icons, as the menu uses it
    readonly property color allIconsColor: {
        revision;
        const settings = findSettings();
        if (!settings)
            return Theme.onSurfaceVariant;
        // Own colour of all category icons, else General › Element look
        // Stored value, else the chosen template's (settings.effectiveValue)
        const get = (key, def) => settings.effectiveValue ? settings.effectiveValue(key, def) : settings.loadValue(key, def);
        const own = get("catIconColorMode", "default");
        const prefix = own !== "default" ? "catIcon" : (get("allPieceIconColorMode", "default") !== "default" ? "allPieceIcon" : "catIcon");
        return ColorRoles.resolve(Theme, get(prefix + "ColorMode", "default"), get(prefix + "CustomColor", ""), Theme.onSurfaceVariant);
    }

    // Same list as in the menu (without depending on the widget), incl. the
    // own categories (key "custom:<id>") and hidden DMS ones (still editable)
    readonly property var categories: {
        revision;
        const settings = findSettings();
        const all = I18n.tr("All");
        const list = [{ key: "__all", text: I18n.trFor("customMenu", "All"), icon: "apps" }];
        // Without the DMS categories deleted in the category editor
        const deleted = settings ? (settings.loadValue("deletedCategories", []) || []) : [];
        const map = AppSearchService._categoryMap;
        for (const c of dmsLists.categories) {
            const key = Defaults.dmsCategoryKey(map, c);
            if (c !== all && deleted.indexOf(key) < 0)
                list.push({ key: key, text: I18n.tr(c), icon: Defaults.categoryIcon(c, (t, ctx) => ctx ? I18n.tr(t, ctx) : I18n.tr(t), AppSearchService.getCategoryIcon(c)) });
        }
        // Own categories: icon of most categories, as in the menu
        const counts = {};
        for (const c of list.slice(1)) {
            const icon = root.icons[c.key] || c.icon;
            counts[icon] = (counts[icon] ?? 0) + 1;
        }
        const common = Object.keys(counts).sort((a, b) => counts[b] - counts[a])[0] || "folder";
        const own = settings ? (settings.loadValue("customCategories", []) || []) : [];
        for (const cc of own)
            list.push({ key: "custom:" + cc.id, text: cc.name || (cc.id === "favorites" ? I18n.trFor("customMenu", "Favorites") : ""), icon: cc.id === "favorites" ? "star" : common });
        list.push({ key: "__hidden", text: I18n.trFor("customMenu", "Hidden"), icon: "visibility_off" });
        // Order of the category editor
        const order = settings ? (settings.loadValue("categoryOrder", []) || []) : [];
        if (order.length === 0)
            return list;
        const pos = list.map(e => e.key);
        const rank = k => order.indexOf(k) >= 0 ? order.indexOf(k) : 1000 + pos.indexOf(k);
        return list.slice().sort((a, b) => rank(a.key) - rank(b.key));
    }

    function findSettings() {
        let item = root.parent;
        while (item) {
            if (item.saveValue !== undefined && item.loadValue !== undefined)
                return item;
            item = item.parent;
        }
        return null;
    }

    function loadValue() {
        const settings = findSettings();
        if (!settings)
            return;
        icons = settings.loadValue("catIcons", {}) || {};
        colors = settings.loadValue("catIconColors", {}) || {};
    }

    // Key of the row whose file picker is open
    property string pickingKey: ""

    function favorites() {
        const settings = findSettings();
        return settings ? [settings.loadValue("iconFavorite1", ""), settings.loadValue("iconFavorite2", ""), settings.loadValue("iconFavorite3", "")] : [];
    }

    function setIcon(key, name) {
        const next = Object.assign({}, icons);
        if (name)
            next[key] = name;
        else
            delete next[key];
        icons = next;
        findSettings()?.saveValue("catIcons", next);
    }

    function setColor(key, color) {
        const next = Object.assign({}, colors);
        if (color)
            next[key] = color;
        else
            delete next[key];
        colors = next;
        findSettings()?.saveValue("catIconColors", next);
    }

    function pickColor(key, label) {
        const picker = PopoutService.colorPickerModal;
        if (!picker)
            return;
        picker.selectedColor = colors[key] || allIconsColor;
        picker.pickerTitle = label;
        picker.onColorSelectedCallback = selected => root.setColor(key, selected.toString());
        picker.show();
    }

    // The settings page is found only once attached: re-read then
    Component.onCompleted: Qt.callLater(() => {
        loadValue();
        revision++;
    })

    // One dialog for all rows; pickingKey says which row it is for
    IconPickerDialog {
        id: fileDialog
        hintFolders: ["categories/scalable", "categories"]
        suggestions: root.suggestions
        onPicked: path => root.setIcon(root.pickingKey, path)
    }

    StyledText {
        text: I18n.trFor("customMenu", "Icon per category")
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Theme.fontWeightMedium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: I18n.trFor("customMenu", "Icon file, Material Symbol or DMS icon. Symbol icons can have their own color; icon files keep theirs.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    Repeater {
        model: root.categories

        Column {
            id: row
            required property var modelData
            readonly property string current: root.icons[modelData.key] || ""
            readonly property string ownColor: root.colors[modelData.key] || ""
            readonly property bool colorable: !(current || modelData.icon).startsWith("/")
            width: root.width
            spacing: Theme.spacingS

            Row {
                id: line
                width: parent.width
                spacing: Theme.spacingM

                FlexIcon {
                    id: previewIcon
                    anchors.verticalCenter: parent.verticalCenter
                    icon: row.current || row.modelData.icon
                    size: Theme.iconSize
                    color: row.ownColor || root.allIconsColor
                }

                StyledText {
                    id: nameLabel
                    anchors.verticalCenter: parent.verticalCenter
                    width: 110
                    text: row.modelData.text
                    elide: Text.ElideRight
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    // Name of the symbol or file name, display only
                    width: Math.max(40, line.width - previewIcon.width - nameLabel.width - colorSwatch.width - resetColor.width - fileButton.width - line.spacing * 5)
                    text: {
                        const v = row.current || row.modelData.icon;
                        return v.startsWith("/") ? v.substring(v.lastIndexOf("/") + 1) : v;
                    }
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    elide: Text.ElideMiddle
                }

                // Own colour of this category (symbol icons only). Ring like the
                // other swatches, so it stays visible on any background.
                Rectangle {
                    id: colorSwatch
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: Theme.cornerRadiusS
                    opacity: row.colorable ? 1 : 0.3
                    color: "transparent"
                    border.width: 2
                    border.color: swatchArea.containsMouse && row.colorable ? Theme.primary : Theme.surfaceText

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: Math.max(0, parent.radius - 4)
                        color: row.ownColor || root.allIconsColor
                    }

                    MouseArea {
                        id: swatchArea
                        anchors.fill: parent
                        enabled: row.colorable
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pickColor(row.modelData.key, row.modelData.text)
                    }
                }

                // Back to the colour of all icons; keeps its place when hidden
                Item {
                    id: resetColor
                    anchors.verticalCenter: parent.verticalCenter
                    width: resetButton.width
                    height: resetButton.height

                    DActionButton {
                        id: resetButton
                        visible: row.ownColor !== ""
                        iconName: "restart_alt"
                        tooltipText: I18n.trFor("customMenu", "Color of all icons")
                        onClicked: root.setColor(row.modelData.key, "")
                    }
                }

                DActionButton {
                    id: fileButton
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "folder_open"
                    tooltipText: I18n.trFor("customMenu", "Choose icon")
                    onClicked: {
                        root.pickingKey = row.modelData.key;
                        fileDialog.currentIcon = row.current || row.modelData.icon;
                        fileDialog.favorites = root.favorites();
                        fileDialog.open();
                    }
                }
            }
        }
    }
}
