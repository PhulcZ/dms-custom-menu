import QtQuick
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets

// List of path badges for file and folder results: a result below `path`
// shows the badge `label` instead of the path up to that folder (e.g.
// "~/Nextcloud" → "Nextcloud"). Stored as [{ path, label }] under
// settingKey; the longest matching path wins.
Column {
    id: root

    property string settingKey: "searchPathBadges"
    property string label: ""
    property string description: ""

    width: parent?.width ?? 0
    spacing: Theme.spacingS

    SettingValue {
        id: setting
        host: root
        settingKey: root.settingKey
        defaultValue: []
    }
    readonly property var badges: Array.isArray(setting.value) ? setting.value : []

    function update(index, changes) {
        const next = badges.map(b => Object.assign({}, b));
        next[index] = Object.assign(next[index] ?? {}, changes);
        setting.save(next);
    }
    function remove(index) {
        setting.save(badges.filter((b, i) => i !== index));
    }
    function add() {
        setting.save(badges.concat([{ "path": "", "label": "" }]));
    }

    StyledText {
        x: Theme.spacingM
        width: parent.width - Theme.spacingM * 2
        text: root.label
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceText
    }
    StyledText {
        visible: root.description !== ""
        x: Theme.spacingM
        width: parent.width - Theme.spacingM * 2
        wrapMode: Text.WordWrap
        text: root.description
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }

    Repeater {
        model: root.badges

        Row {
            id: badgeRow
            required property var modelData
            required property int index
            x: Theme.spacingM
            width: root.width - Theme.spacingM * 2
            spacing: Theme.spacingS

            DTextField {
                width: (badgeRow.width - 44 - badgeRow.spacing * 2) * 0.6
                height: 40
                text: badgeRow.modelData.path ?? ""
                placeholderText: "~/Nextcloud"
                onEditingFinished: if (text.trim() !== (badgeRow.modelData.path ?? "")) root.update(badgeRow.index, { "path": text.trim() })
            }
            DTextField {
                width: (badgeRow.width - 44 - badgeRow.spacing * 2) * 0.4
                height: 40
                text: badgeRow.modelData.label ?? ""
                placeholderText: I18n.trFor("customMenu", "Badge")
                onEditingFinished: if (text.trim() !== (badgeRow.modelData.label ?? "")) root.update(badgeRow.index, { "label": text.trim() })
            }
            DActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconName: "delete"
                tooltipText: I18n.trFor("customMenu", "Remove badge")
                onClicked: root.remove(badgeRow.index)
            }
        }
    }

    DButton {
        x: Theme.spacingM
        iconName: "add"
        text: I18n.trFor("customMenu", "Add badge")
        onClicked: root.add()
    }
}
