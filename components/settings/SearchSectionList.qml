import QtQuick
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets

// Order and visibility of the search result sections (apps, files,
// settings, one per launcher plugin …). sections: [{ id, name, icon }] in
// the default order. Stored: orderKey = [ids] (empty = DMS' order),
// hiddenKey = [ids].
Column {
    id: root

    property var sections: []
    property string orderKey: "searchSectionOrder"
    property string hiddenKey: "searchSectionHidden"
    property color textColor: Theme.surfaceText

    width: parent?.width ?? 0
    spacing: 2

    SettingValue {
        id: orderSetting
        host: root
        settingKey: root.orderKey
        defaultValue: []
    }
    SettingValue {
        id: hiddenSetting
        host: root
        settingKey: root.hiddenKey
        defaultValue: []
    }
    readonly property var order: Array.isArray(orderSetting.value) ? orderSetting.value : []
    readonly property var hidden: Array.isArray(hiddenSetting.value) ? hiddenSetting.value : []

    // Stored order first, then the rest in the default order
    readonly property var ordered: {
        const known = sections.map(s => s.id);
        const first = order.filter(id => known.indexOf(id) >= 0);
        const rest = known.filter(id => first.indexOf(id) < 0);
        return first.concat(rest).map(id => sections.find(s => s.id === id));
    }

    function move(index, delta) {
        const ids = ordered.map(s => s.id);
        const j = index + delta;
        if (j < 0 || j >= ids.length)
            return;
        ids.splice(j, 0, ids.splice(index, 1)[0]);
        orderSetting.save(ids);
    }
    function toggle(id) {
        hiddenSetting.save(hidden.indexOf(id) >= 0 ? hidden.filter(h => h !== id) : hidden.concat([id]));
    }
    function reset() {
        orderSetting.clear();
        hiddenSetting.clear();
    }

    Repeater {
        model: root.ordered

        Item {
            id: sectionRow
            required property var modelData
            required property int index
            readonly property bool isHidden: root.hidden.indexOf(modelData.id) >= 0
            x: Theme.spacingM
            width: root.width - Theme.spacingM * 2
            height: 40

            DIcon {
                id: sectionIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                name: sectionRow.modelData.icon || "label"
                size: Theme.iconSizeSmall
                color: root.textColor
                opacity: sectionRow.isHidden ? 0.4 : 1
            }
            StyledText {
                anchors.left: sectionIcon.right
                anchors.leftMargin: Theme.spacingS
                anchors.right: buttons.left
                anchors.verticalCenter: parent.verticalCenter
                text: sectionRow.modelData.name
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSizeMedium
                color: root.textColor
                opacity: sectionRow.isHidden ? 0.4 : 1
            }
            Row {
                id: buttons
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                DActionButton {
                    enabled: sectionRow.index > 0
                    opacity: enabled ? 1 : 0.3
                    iconName: "arrow_upward"
                    tooltipText: I18n.trFor("customMenu", "Move up")
                    onClicked: root.move(sectionRow.index, -1)
                }
                DActionButton {
                    enabled: sectionRow.index < root.ordered.length - 1
                    opacity: enabled ? 1 : 0.3
                    iconName: "arrow_downward"
                    tooltipText: I18n.trFor("customMenu", "Move down")
                    onClicked: root.move(sectionRow.index, 1)
                }
                DActionButton {
                    iconName: sectionRow.isHidden ? "visibility_off" : "visibility"
                    tooltipText: sectionRow.isHidden ? I18n.trFor("customMenu", "Show section") : I18n.trFor("customMenu", "Hide section")
                    onClicked: root.toggle(sectionRow.modelData.id)
                }
            }
        }
    }

    DButton {
        x: Theme.spacingM
        visible: root.order.length > 0 || root.hidden.length > 0
        iconName: "restart_alt"
        text: I18n.trFor("customMenu", "Reset to DMS order and show all")
        onClicked: root.reset()
    }
}
