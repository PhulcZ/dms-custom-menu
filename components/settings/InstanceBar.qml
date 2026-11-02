import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets

// Instance chooser at the top of the settings: the main menu and its
// variants (DMS plugin variants: each can be added to the bar on its own,
// with its own name and its own settings and contents). DMS opens this page
// without saying which bar entry it came from, so the choice stays (the
// gear in a menu selects its instance). New = a copy of the instance being
// edited; delete for the others.
Column {
    id: root

    width: parent?.width ?? 0
    spacing: Theme.spacingL

    property int revision: 0
    property bool renaming: false

    function findSettings() {
        let item = parent;
        while (item) {
            if (item.saveValue !== undefined && item.loadValue !== undefined && item.selectInstance !== undefined)
                return item;
            item = item.parent;
        }
        return null;
    }
    readonly property var settings: findSettings()
    readonly property string pluginId: settings?.pluginId ?? "customMenu"

    Connections {
        target: PluginService
        function onPluginDataChanged(changedId) {
            if (changedId === root.pluginId)
                root.revision++;
        }
    }

    // A copy: DMS changes its list in place (a new variant is pushed onto
    // it), so the same list would not count as a change
    readonly property var variants: {
        revision;
        return (PluginService.getPluginVariants(pluginId) ?? []).slice();
    }
    readonly property string current: settings?.editInstance ?? ""
    // The main instance is the variant "variant_main" (data in the plugin
    // data); its name can be changed like the others'
    readonly property string mainName: variants.find(v => v.id === "variant_main")?.name || I18n.trFor("customMenu", "Main menu")
    readonly property var entries: [{ "id": "", "name": mainName }].concat(variants.filter(v => v.id !== "variant_main").map(v => ({ "id": v.id, "name": v.name || v.id })))
    readonly property string currentName: entries.find(e => e.id === current)?.name ?? mainName
    // DDropdown assigns currentValue on every pick, which breaks the
    // binding; set it again when the name or the instance changes
    onCurrentNameChanged: instanceChoice.currentValue = currentName

    function createCopy() {
        // Everything of the edited instance except what all share
        const data = settings.instanceStored();
        for (const k of ["variants", "userTemplates", "enabled"])
            delete data[k];
        let n = variants.length + 1;
        // DMS shows "CustomMenu - <name>": the name without the plugin name
        const base = I18n.trFor("customMenu", "Menu");
        while (variants.some(v => v.name === base + " " + n))
            n++;
        const id = PluginService.createPluginVariant(pluginId, base + " " + n, { "data": data });
        settings.selectInstance(id);
    }
    function rename(name) {
        name = name.trim();
        if (name)
            PluginService.updatePluginVariant(pluginId, current || "variant_main", { "name": name });
        renaming = false;
    }
    function remove() {
        if (!current)
            return;
        const id = current;
        settings.selectInstance("");
        PluginService.removePluginVariant(pluginId, id);
    }

    // Title like DMS' section titles (top level: primary)
    StyledText {
        width: parent.width
        text: I18n.trFor("customMenu", "Instance")
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Theme.fontWeightMedium
        color: Theme.primary
    }
    // The warning in red, an empty line, then the hint in the normal colour
    Column {
        x: Theme.spacingM
        width: parent.width - Theme.spacingM * 2
        spacing: hint.font.pixelSize

        StyledText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: I18n.trFor("customMenu", "Make sure the right instance is selected!")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.error
        }
        StyledText {
            id: hint
            width: parent.width
            wrapMode: Text.WordWrap
            text: I18n.trFor("customMenu", "Create new instances here, then add them to the bar like any other widget.")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
        }
    }

    // Choice, rename; new (a copy of this one) and delete as icons
    Row {
        x: Theme.spacingM
        spacing: Theme.spacingS
        visible: !root.renaming

        DDropdown {
            id: instanceChoice
            width: Math.min(root.width - Theme.spacingM * 2 - renameButton.width - newButton.width - deleteButton.width - parent.spacing * 3, 360)
            anchors.verticalCenter: parent.verticalCenter
            options: root.entries.map(e => e.name)
            currentValue: root.currentName
            onValueChanged: value => {
                const e = root.entries.find(x => x.name === value);
                if (e && e.id !== root.current)
                    root.settings.selectInstance(e.id);
            }
        }
        DButton {
            id: renameButton
            anchors.verticalCenter: parent.verticalCenter
            iconName: "edit"
            text: I18n.trFor("customMenu", "Rename")
            onClicked: {
                nameField.text = root.currentName;
                root.renaming = true;
                nameField.forceActiveFocus();
            }
        }
        DActionButton {
            id: newButton
            anchors.verticalCenter: parent.verticalCenter
            iconName: "library_add"
            tooltipText: I18n.trFor("customMenu", "New instance (copy)")
            onClicked: root.createCopy()
        }
        DActionButton {
            id: deleteButton
            anchors.verticalCenter: parent.verticalCenter
            visible: root.current !== ""
            iconName: "delete"
            tooltipText: I18n.trFor("customMenu", "Delete instance")
            onClicked: root.remove()
        }
    }

    Row {
        x: Theme.spacingM
        spacing: Theme.spacingS
        visible: root.renaming

        DTextField {
            id: nameField
            width: Math.min(root.width - Theme.spacingM * 2 - 2 * 110, 260)
            height: 40
            placeholderText: I18n.trFor("customMenu", "Name")
            onAccepted: root.rename(text)
        }
        DButton {
            enabled: nameField.text.trim() !== ""
            iconName: "check"
            text: I18n.trFor("customMenu", "Save")
            onClicked: root.rename(nameField.text)
        }
        DButton {
            iconName: "close"
            text: I18n.trFor("customMenu", "Cancel")
            onClicked: root.renaming = false
        }
    }
}
