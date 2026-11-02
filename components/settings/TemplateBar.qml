import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import "../../Templates.js" as Templates
import "../../Defaults.js" as Defaults

// Template chooser (General › Template): built-in templates and own
// profiles. Changed against a built-in template it shows "Custom", against
// an own profile "Name (changed)"; the save button then turns red. Choosing
// another entry with changes first offers to save them (as a new profile,
// or over the active own profile; built-in ones cannot be overwritten);
// then, if the sizes differ, whether to keep the current size or take the
// template's. Templates with their own size over the instance's
// (Fullscreen, a mini menu: Templates.isOverlay) never ask: they cover the
// own size, which returns when switching away.
// "Reset" removes the changes (back to the template). A template also
// holds the arrangement of the elements (Templates.layoutOf); menu
// contents (shortcuts, buttons, categories …) are never touched
// (Templates.contentKeys).
Column {
    id: root

    width: parent?.width ?? 0
    spacing: Theme.spacingS

    property int revision: 0
    // Template chosen while there are changes: asked before they are dropped
    property string pendingId: ""

    function findSettings() {
        let item = parent;
        while (item) {
            if (item.saveValue !== undefined && item.loadValue !== undefined)
                return item;
            item = item.parent;
        }
        return null;
    }
    readonly property var settings: findSettings()

    Connections {
        target: PluginService
        function onPluginDataChanged(pluginId) {
            if (pluginId === root.settings?.pluginId)
                root.revision++;
        }
    }

    readonly property var stored: {
        revision;
        // The instance being edited (settings.instanceStored)
        return root.settings ? (root.settings.instanceStored() ?? {}) : {};
    }
    readonly property string active: stored.activeTemplate ?? "standard"
    // Own profiles: shared by all instances
    readonly property var userTemplates: {
        revision;
        return root.settings ? (root.settings.loadValue("userTemplates", {}) ?? {}) : {};
    }
    readonly property var templateValues: Templates.valuesOf(active, userTemplates)
    readonly property var changes: Templates.changes(stored, templateValues)
    readonly property bool activeOverlay: Templates.isOverlay(active, userTemplates)
    // The instance's own size (with an overlay template: the one underneath)
    readonly property var ownSize: Templates.ownSize(stored, templateValues, activeOverlay)
    // The own size differs from the template's (an overlay covers it: no change)
    readonly property bool sizeChanged: !activeOverlay && !Templates.sameSize(ownSize, Templates.sizeValues(templateValues))
    readonly property var templateLayout: Templates.layoutOf(active, userTemplates)
    readonly property bool layoutChanged: Templates.layoutDiffers(stored, templateLayout)
    // Changed settings, the arrangement counting as one
    readonly property int changeCount: Object.keys(changes).length + (layoutChanged ? 1 : 0) + (sizeChanged ? 1 : 0)
    readonly property bool modified: changeCount > 0
    readonly property bool activeIsOwn: active.startsWith("user:")

    // [{ id, name }]: built-in first, then own profiles
    readonly property var entries: Templates.builtInOrder.map(id => ({ "id": id, "name": displayName(id) })).concat(Object.keys(userTemplates).sort().map(n => ({ "id": "user:" + n, "name": n })))
    readonly property string activeName: displayName(active)
    // Built-in names translated, own ones as typed
    function displayName(id) {
        return Templates.translated(id) ? I18n.trFor("customMenu", Templates.nameOf(id)) : Templates.nameOf(id);
    }
    // Names of the built-in templates (as shown): not usable for own ones
    readonly property var builtInNames: Templates.builtInOrder.map(id => displayName(id)).concat(Templates.builtInOrder.map(id => Templates.nameOf(id)))
    // Size as text: "1500 × 750 px", "50 % × 70 %", "Fullscreen"
    function sizeText(values) {
        const size = Templates.sizeOf(values);
        if (size.mode === "full")
            return I18n.trFor("customMenu", "Fullscreen");
        if (size.mode === "percent")
            return size.pw + " % × " + size.ph + " %";
        return size.w + " × " + size.h + " px";
    }
    readonly property string shownName: !modified ? activeName : activeIsOwn ? I18n.trFor("customMenu", "%1 (changed)").arg(activeName) : I18n.trFor("customMenu", "Custom")
    // DDropdown assigns its value on every pick (breaking the binding):
    // shown again whenever it changes or a choice is cancelled
    onShownNameChanged: choice.currentValue = shownName

    // Removes every stored setting of the template and puts the elements
    // where template `id` has them (contents stay); extra: further keys to
    // write in the same save. The size is left alone (the callers decide).
    function clearSettings(extra, id) {
        const changes = Object.assign({}, extra ?? {});
        for (const key of Object.keys(stored)) {
            if (Templates.isTemplateKey(key) && !Templates.isSizeKey(key) && !(key in changes))
                changes[key] = undefined;
        }
        Object.assign(changes, layoutFor(id ?? active, changes.userTemplates ?? userTemplates));
        settings.saveValues(changes, true);
    }
    // Arrangement for template `id`. Into an exclusive template (only its
    // own elements, e.g. the mini bar) the current arrangement is put
    // aside; out of one it comes back, then the template's elements take
    // their places as usual. A template's own elements bring their buttons.
    function layoutFor(id, templates) {
        const target = Templates.layoutOf(id, templates);
        const intoExclusive = Templates.isExclusive(id, templates);
        const fromExclusive = Templates.isExclusive(active, templates);
        let out;
        if (intoExclusive) {
            out = Templates.applyLayout(stored, target, true);
            if (!fromExclusive)
                out.layoutAside = Templates.currentLayout(stored);
        } else if (fromExclusive) {
            const aside = stored.layoutAside ?? {};
            out = Templates.applyLayout(Object.assign({}, stored, { "layout": aside.layout, "layoutGrid": aside.layoutGrid, "lockedElements": aside.lockedElements }), target, false);
            out.layoutAside = undefined;
        } else {
            out = Templates.applyLayout(stored, target, false);
        }
        return Object.assign(out, Templates.contentsFor(id, stored.shortcuts, Defaults.defaultShortcuts));
    }
    // Size keys for a save: the given size values, all others removed
    function sizeChanges(values) {
        const out = {};
        for (const key of Templates.sizeKeys)
            out[key] = values[key];
        return out;
    }
    // "Reset to template": also the size (an overlay covers the own size:
    // that stays)
    function resetToTemplate() {
        clearSettings(activeOverlay ? {} : sizeChanges({}));
    }

    // Switching: 1. unsaved changes → offer to save them, 2. sizes differ →
    // keep the size or take the template's, 3. switch
    function choose(id) {
        if (id === active && !modified)
            return;
        pendingId = id;
        if (modified)
            openDialog(switchDialogComp);
        else
            askSize();
    }
    // Step 2 (after saving, one tick later: the stored values are new then)
    function askSize() {
        const id = pendingId;
        if (!id)
            return;
        const target = Templates.sizeValues(Templates.valuesOf(id, userTemplates));
        if (Templates.isOverlay(id, userTemplates) || Templates.sameSize(ownSize, target))
            finishSwitch(false);
        else
            openDialog(sizeDialogComp);
    }
    // keepSize: the current own size stays (stored, over the template's)
    function finishSwitch(keepSize) {
        const id = pendingId;
        pendingId = "";
        // An overlay keeps the own size underneath, so it returns later
        const keep = keepSize || Templates.isOverlay(id, userTemplates);
        clearSettings(Object.assign({ "activeTemplate": id }, sizeChanges(keep ? ownSize : {})), id);
    }
    function cancelSwitch() {
        pendingId = "";
        choice.currentValue = shownName;
    }
    // Save button: a changed own profile asks overwrite / new, otherwise
    // straight to the name
    function startSave() {
        if (activeIsOwn && modified)
            openDialog(saveDialogComp);
        else
            askName();
    }
    function askName() {
        openDialog(nameDialogComp);
    }
    // Dialogs are created in the layer DMS uses for its own dialogs on
    // this page (parentModal.modalFocusScope, see DMS' PluginSettingsPage)
    function openDialog(comp) {
        let page = root.parent;
        while (page && page.parentModal === undefined)
            page = page.parent;
        const host = page?.parentModal?.modalFocusScope ?? null;
        return comp.createObject(host ?? root, { "open": true });
    }
    // Settings, size and the current arrangement. Saved from an overlay
    // template (Fullscreen, a mini menu): the new profile is one too, with
    // that size; the own size stays underneath.
    function saveProfile(name) {
        name = name.trim();
        if (!name || builtInNames.indexOf(name) >= 0)
            return;
        const next = Object.assign({}, userTemplates);
        // An overlay's size with the changes made to it
        const size = activeOverlay ? Object.assign(Templates.sizeValues(templateValues), stored.profileSize ?? {}) : ownSize;
        const profile = { "values": Object.assign({}, templateValues, changes, sizeChanges(size), Templates.currentLayout(stored)) };
        delete profile.values.profileSize;
        for (const key of Templates.sizeKeys) {
            if (profile.values[key] === undefined)
                delete profile.values[key];
        }
        if (activeOverlay)
            profile.sizeOverlay = true;
        // Saved from an exclusive template (only its own elements): the same
        if (Templates.isExclusive(active, userTemplates))
            profile.exclusiveLayout = true;
        next[name] = profile;
        // The size is in the profile now (an overlay: the own one stays)
        clearSettings(Object.assign({ "userTemplates": next, "activeTemplate": "user:" + name }, activeOverlay ? {} : sizeChanges({})), "user:" + name);
    }
    function deleteProfile() {
        if (!activeIsOwn)
            return;
        const next = Object.assign({}, userTemplates);
        delete next[active.slice(5)];
        // Its values stay as changes against "Default" (nothing jumps; an
        // overlay's size goes, the own size underneath returns)
        const values = Object.assign({}, templateValues, changes, sizeChanges(ownSize), { "profileSize": undefined });
        settings.saveValues(Object.assign(values, { "userTemplates": next, "activeTemplate": "standard" }), true);
    }

    DDropdown {
        id: choice
        x: Theme.spacingM
        width: Math.min(parent.width - Theme.spacingM * 2, 360)
        options: root.entries.map(e => e.name)
        currentValue: root.shownName
        onValueChanged: value => {
            const e = root.entries.find(x => x.name === value);
            if (e)
                root.choose(e.id);
        }
    }

    Flow {
        x: Theme.spacingM
        width: parent.width - Theme.spacingM * 2
        spacing: Theme.spacingS

        // Red while the current settings are not saved in a profile
        DButton {
            iconName: "bookmark_add"
            text: I18n.trFor("customMenu", "Save profile")
            backgroundColor: root.modified ? Theme.error : Theme.buttonBg
            textColor: root.modified ? Theme.onError : Theme.buttonText
            onClicked: root.startSave()
        }
        DButton {
            enabled: root.modified
            iconName: "restart_alt"
            text: I18n.trFor("customMenu", "Reset to template")
            onClicked: root.resetToTemplate()
        }
        DButton {
            visible: root.activeIsOwn
            iconName: "delete"
            text: I18n.trFor("customMenu", "Delete profile")
            onClicked: root.deleteProfile()
        }
    }

    // Another entry chosen while there are changes: save them first?
    Component {
        id: switchDialogComp
        SmallDialog {
            id: switchDialog
            title: I18n.trFor("customMenu", "Switch to \"%1\"?").arg(root.displayName(root.pendingId))
            message: I18n.trFor("customMenu", "The current settings (%1 changes) are not saved in a profile. Save them first?").arg(root.changeCount)
            onCancelled: root.cancelSwitch()
            buttons: [
                DButton {
                    iconName: "bookmark_add"
                    text: I18n.trFor("customMenu", "Save as new profile")
                    onClicked: {
                        switchDialog.done();
                        root.askName();
                    }
                },
                DButton {
                    visible: root.activeIsOwn
                    iconName: "save"
                    text: I18n.trFor("customMenu", "Overwrite \"%1\"").arg(root.activeName)
                    onClicked: {
                        root.saveProfile(root.activeName);
                        switchDialog.done();
                        Qt.callLater(root.askSize);
                    }
                },
                DButton {
                    iconName: "delete_sweep"
                    text: I18n.trFor("customMenu", "Discard")
                    onClicked: {
                        switchDialog.done();
                        root.askSize();
                    }
                },
                DActionButton {
                    iconName: "close"
                    tooltipText: I18n.trFor("customMenu", "Cancel")
                    onClicked: switchDialog.close()
                }
            ]
        }
    }

    // Sizes differ: keep the current one or take the template's
    Component {
        id: sizeDialogComp
        SmallDialog {
            id: sizeDialog
            title: I18n.trFor("customMenu", "Size for \"%1\"").arg(root.displayName(root.pendingId))
            message: I18n.trFor("customMenu", "Keep the current size of the menu or use the size saved in the profile?")
            onCancelled: root.cancelSwitch()
            buttons: [
                DButton {
                    iconName: "check"
                    text: I18n.trFor("customMenu", "Keep (%1)").arg(root.sizeText(root.ownSize))
                    onClicked: {
                        root.finishSwitch(true);
                        sizeDialog.done();
                    }
                },
                DButton {
                    iconName: "aspect_ratio"
                    text: I18n.trFor("customMenu", "From the profile (%1)").arg(root.sizeText(Templates.sizeValues(Templates.valuesOf(root.pendingId, root.userTemplates))))
                    onClicked: {
                        root.finishSwitch(false);
                        sizeDialog.done();
                    }
                },
                DActionButton {
                    iconName: "close"
                    tooltipText: I18n.trFor("customMenu", "Cancel")
                    onClicked: sizeDialog.close()
                }
            ]
        }
    }

    // Saving a changed own profile
    Component {
        id: saveDialogComp
        SmallDialog {
            id: saveDialog
            title: I18n.trFor("customMenu", "Save profile")
            buttons: [
                DButton {
                    iconName: "save"
                    text: I18n.trFor("customMenu", "Overwrite \"%1\"").arg(root.activeName)
                    onClicked: {
                        root.saveProfile(root.activeName);
                        saveDialog.done();
                    }
                },
                DButton {
                    iconName: "bookmark_add"
                    text: I18n.trFor("customMenu", "Save as new profile")
                    onClicked: {
                        saveDialog.done();
                        root.askName();
                    }
                },
                DActionButton {
                    iconName: "close"
                    tooltipText: I18n.trFor("customMenu", "Cancel")
                    onClicked: saveDialog.close()
                }
            ]
        }
    }

    // Name of a new profile
    Component {
        id: nameDialogComp
        SmallDialog {
            id: nameDialog
            title: I18n.trFor("customMenu", "Save as new profile")
            Component.onCompleted: Qt.callLater(() => nameField.forceActiveFocus())
            readonly property string name: nameField.text.trim()
            readonly property bool nameOk: name !== "" && root.builtInNames.indexOf(name) < 0
            function save() {
                if (!nameOk)
                    return;
                root.saveProfile(name);
                nameDialog.done();
                // Part of a switch: on to the size
                Qt.callLater(root.askSize);
            }
            onCancelled: if (root.pendingId) root.cancelSwitch()

            content: [
                DTextField {
                    id: nameField
                    width: parent?.width ?? 0
                    height: 40
                    placeholderText: I18n.trFor("customMenu", "Profile name")
                    onAccepted: nameDialog.save()
                },
                StyledText {
                    visible: root.builtInNames.indexOf(nameDialog.name) >= 0
                    width: parent?.width ?? 0
                    wrapMode: Text.WordWrap
                    text: I18n.trFor("customMenu", "Built-in profiles cannot be overwritten. Please choose another name.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.error
                },
                StyledText {
                    visible: !!root.userTemplates[nameDialog.name]
                    width: parent?.width ?? 0
                    wrapMode: Text.WordWrap
                    text: I18n.trFor("customMenu", "A profile with this name already exists and will be replaced.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.error
                }
            ]

            buttons: [
                DActionButton {
                    enabled: nameDialog.nameOk
                    iconName: "check"
                    tooltipText: I18n.trFor("customMenu", "Save")
                    onClicked: nameDialog.save()
                },
                DActionButton {
                    iconName: "close"
                    tooltipText: I18n.trFor("customMenu", "Cancel")
                    onClicked: nameDialog.close()
                }
            ]
        }
    }
}
