import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import "../common"

// "Edit App" as in the DMS launcher: stores an override in DMS' session
// data (SessionData.setAppOverride). It applies everywhere: CustomMenu,
// launcher, dock. Own rebuild from public building blocks instead of the
// launcher-internal AppEditView, so DMS updates do not break the plugin.
// Fields and keys match AppEditView (name, icon, comment, envVars,
// extraFlags); identifier = app.id as in the launcher.
FocusScope {
    id: root

    property var app: null
    property color textColor: Theme.surfaceText
    property var iconFavorites: []
    // "dms" = override inside DMS only (like the launcher),
    // "system" = own start file in ~/.local/share/applications
    property string editScope: "dms"
    readonly property bool systemScope: editScope === "system"
    property bool pickingIcon: false
    // Own icon colours per app ({ appId: "#rrggbb" }), stored by the menu
    property var iconColors: ({})
    // Colour being edited ("" = none); only for symbol icons
    property string iconColor: ""
    readonly property bool iconColorable: (iconField?.text || "").trim().startsWith("material:")

    // Command as DMS runs it on click: Exec of the .desktop file plus
    // "Extra Arguments". Display only; changing it goes through an own
    // start file, not through DMS.
    readonly property string effectiveCommand: {
        const base = (original?.command?.length ? original.command.join(" ") : (original?.execString || original?.exec || ""));
        const extra = (flagsField?.text || "").trim();
        return extra ? base + " " + extra : base;
    }

    signal closeRequested
    signal iconColorSaved(string appId, string color)

    readonly property string appId: app?.id || app?.execString || app?.exec || ""
    // The app from the list already includes overrides; saving needs the
    // original entry to compare against.
    readonly property var original: {
        AppSearchService.cacheVersion;
        return AppSearchService.applications.find(a => (a.id || a.execString || a.exec || "") === appId) ?? app;
    }
    readonly property bool hasOverride: !!iconColors[appId] || (systemScope ? desktopFile.isOurOverride : (!!appId && SessionData.getAppOverride(appId) !== null))

    DesktopFileOverride {
        id: desktopFile
        onSaved: root.closeRequested()
    }

    // Load one tick later: in the onAppChanged handler appId/original are
    // not updated yet (empty), the fields would stay empty otherwise.
    onAppChanged: Qt.callLater(load)
    Component.onCompleted: Qt.callLater(load)

    function load() {
        if (!nameField)
            return;
        const existing = appId ? SessionData.getAppOverride(appId) : null;
        // Prefilled with the currently effective value (override or original)
        nameField.text = existing?.name || original?.name || "";
        iconField.text = existing?.icon || original?.icon || "";
        commentField.text = existing?.comment || original?.comment || "";
        envField.text = existing?.envVars || "";
        flagsField.text = existing?.extraFlags || "";
        iconColor = iconColors[appId] || "";
        hexField.text = iconColor;
        pickingIcon = false;
        commandField.text = original?.execString || "";
        if (systemScope)
            desktopFile.load(appId);
        Qt.callLater(() => nameField.forceActiveFocus());
    }

    function save() {
        if (!appId)
            return;
        // Plugin data, separate from DMS' override (no colour field there)
        iconColorSaved(appId, iconColorable ? iconColor : "");
        if (systemScope) {
            // Remove the DMS override, otherwise it would hide the file in DMS
            SessionData.clearAppOverride(appId);
            desktopFile.save({
                name: nameField.text,
                icon: iconField.text,
                comment: commentField.text,
                exec: commandField.text
            });
            return; // closes on onSaved
        }
        const override = {};
        const fields = { name: nameField, icon: iconField, comment: commentField, envVars: envField, extraFlags: flagsField };
        for (const key of Object.keys(fields)) {
            const value = fields[key].text.trim();
            // Only save what differs from the original; otherwise an unchanged
            // name would count as an override and no longer follow updates.
            if (value && value !== (original?.[key] ?? ""))
                override[key] = value;
        }
        if (Object.keys(override).length > 0)
            SessionData.setAppOverride(appId, override);
        else
            SessionData.clearAppOverride(appId);
        closeRequested();
    }

    function reset() {
        iconColorSaved(appId, "");
        if (systemScope)
            desktopFile.reset();
        else if (appId)
            SessionData.clearAppOverride(appId);
        closeRequested();
    }

    Keys.onPressed: event => {
        if (pickingIcon)
            return;
        if (event.key === Qt.Key_Escape) {
            closeRequested();
            event.accepted = true;
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_S) && (event.modifiers & Qt.ControlModifier)) {
            save();
            event.accepted = true;
        }
    }

    // One field: label + text field
    component EditField: Column {
        property alias label: fieldLabel.text
        property alias field: input
        width: parent.width
        spacing: Theme.spacingXS

        StyledText {
            id: fieldLabel
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightMedium
            color: root.textColor
        }

        DTextField {
            id: input
            width: parent.width
        }
    }

    DFlickable {
        visible: !root.pickingIcon
        anchors.fill: parent
        anchors.bottomMargin: buttonRow.height + Theme.spacingM
        contentHeight: fieldColumn.implicitHeight
        clip: true

        // Rows at most as wide as the widest row of the buttons editor
        // (4 buttons, 280 px name, 360 px target, gaps), centered
        Column {
            id: fieldColumn
            readonly property real maxWidth: 4 * 40 + 280 + 360 + 5 * Theme.spacingS
            x: Math.max(0, (parent.width - width) / 2)
            width: Math.min(parent.width, maxWidth)
            spacing: Theme.spacingM

            // Header: small heading, below it a live preview of how the app looks
            // after saving (icon + name from the fields).
            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: I18n.trFor("customMenu", "Edit App")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: Theme.primary
                }

                Row {
                    spacing: Theme.spacingM

                    AppIconRenderer {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.iconSizeLarge
                        height: Theme.iconSizeLarge
                        iconSize: Theme.iconSizeLarge
                        iconValue: (root.iconField?.text || "").trim() || root.original?.icon || ""
                        fallbackText: ((root.nameField?.text || "").trim() || root.original?.name || "?").charAt(0).toUpperCase()
                        colorOverride: root.iconColorable && root.iconColor ? root.iconColor : "transparent"
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.nameField?.text || "").trim() || root.original?.name || ""
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Theme.fontWeightMedium
                        color: root.textColor
                    }
                }
            }

            EditField {
                id: nameRow
                label: I18n.trFor("customMenu", "Name")
                field.placeholderText: root.original?.name || ""
            }
            // Icon: text field + button for the icon picker
            Item {
                width: parent.width
                height: iconRow.height

                EditField {
                    id: iconRow
                    width: parent.width - pickButton.width - Theme.spacingS
                    label: I18n.trFor("customMenu", "Icon")
                    field.placeholderText: root.original?.icon || ""
                }

                DActionButton {
                    id: pickButton
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: (iconRow.field.height - height) / 2
                    iconName: "folder_open"
                    iconColor: root.textColor
                    tooltipText: I18n.trFor("customMenu", "Choose icon")
                    onClicked: {
                        root.pickingIcon = true;
                        picker.open();
                    }
                }
            }
            // Icon colour, only for symbol icons. Inline palette instead of
            // DMS' colour picker window: a separate window would take the
            // focus from the menu. Theme colours + free hex value.
            Column {
                visible: root.iconColorable
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: I18n.trFor("customMenu", "Icon color")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: root.textColor
                }

                Row {
                    spacing: Theme.spacingS

                    Repeater {
                        // "" = no own colour (the menu's text colour)
                        model: ["", Theme.primary.toString(), Theme.secondary.toString(), Theme.tertiary.toString(), Theme.error.toString(), Theme.surfaceText.toString()]

                        Rectangle {
                            id: swatch
                            required property string modelData
                            readonly property bool selected: root.iconColor.toLowerCase() === modelData.toLowerCase()
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28
                            radius: Theme.cornerRadiusS
                            color: "transparent"
                            border.width: 2
                            border.color: selected || swatchArea.containsMouse ? Theme.primary : Theme.outlineVariant

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 4
                                radius: Math.max(0, parent.radius - 4)
                                color: swatch.modelData || "transparent"
                            }

                            DIcon {
                                visible: swatch.modelData === ""
                                anchors.centerIn: parent
                                name: "format_color_reset"
                                size: Theme.iconSizeSmall
                                color: root.textColor
                            }

                            MouseArea {
                                id: swatchArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.iconColor = swatch.modelData;
                                    hexField.text = swatch.modelData;
                                }
                            }
                        }
                    }

                    DTextField {
                        id: hexField
                        anchors.verticalCenter: parent.verticalCenter
                        width: 120
                        placeholderText: "#rrggbb"
                        onTextEdited: {
                            const v = text.trim();
                            if (v === "" || /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(v))
                                root.iconColor = v;
                        }
                    }
                }
            }

            EditField {
                id: commentRow
                label: I18n.trFor("customMenu", "Description")
                field.placeholderText: root.original?.comment || ""
            }
            EditField {
                id: envRow
                visible: !root.systemScope
                label: I18n.trFor("customMenu", "Environment Variables")
                field.placeholderText: "VAR=value"
            }
            // Command: display only in DMS (Exec + extra arguments), editable on
            // Linux level, where it ends up as Exec= in the start file.
            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: root.systemScope ? I18n.trFor("customMenu", "Command") : I18n.trFor("customMenu", "Command (read-only)")
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    color: root.textColor
                }

                DTextField {
                    visible: !root.systemScope
                    width: parent.width
                    readOnly: true
                    text: root.effectiveCommand
                    textColor: Theme.surfaceVariantText
                }

                DTextField {
                    id: commandEdit
                    visible: root.systemScope
                    width: parent.width
                    placeholderText: root.original?.execString || ""
                }
            }

            StyledText {
                visible: root.systemScope
                width: parent.width
                wrapMode: Text.WordWrap
                text: I18n.trFor("customMenu", "Saved as ~/.local/share/applications/%1 — applies system-wide.").arg(desktopFile.fileName)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            EditField {
                id: flagsRow
                visible: !root.systemScope
                label: I18n.trFor("customMenu", "Extra Arguments")
                field.placeholderText: "--flag --option=value"
            }
        }
    }

    // Shortcuts to the text fields
    readonly property var nameField: nameRow.field
    readonly property var iconField: iconRow.field
    readonly property var commentField: commentRow.field
    readonly property var envField: envRow.field
    readonly property var flagsField: flagsRow.field
    readonly property var commandField: commandEdit

    IconPicker {
        id: picker
        // App icons: DMS' AppIconRenderer shows "material:<name>" as a symbol
        symbolPrefix: "material:"
        visible: root.pickingIcon
        anchors.fill: parent
        currentIcon: (root.iconField?.text || "").trim()
        favorites: root.iconFavorites
        textColor: root.textColor
        focus: visible
        onPicked: path => {
            root.iconField.text = path;
            root.pickingIcon = false;
        }
        onCancelled: root.pickingIcon = false
    }

    Row {
        id: buttonRow
        visible: !root.pickingIcon
        anchors.right: parent.right
        // Flush with the right edge of the (centered) fields
        anchors.rightMargin: Math.max(0, (parent.width - fieldColumn.maxWidth) / 2)
        anchors.bottom: parent.bottom
        spacing: Theme.spacingS

        DButton {
            visible: root.hasOverride
            iconName: "restart_alt"
            text: I18n.trFor("customMenu", "Reset")
            onClicked: root.reset()
        }
        DButton {
            text: I18n.trFor("customMenu", "Cancel")
            onClicked: root.closeRequested()
        }
        DButton {
            iconName: "check"
            text: I18n.trFor("customMenu", "Save")
            onClicked: root.save()
        }
    }
}
