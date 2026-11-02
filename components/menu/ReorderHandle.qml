import QtQuick
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets

// Drag handle for reordering rows of a list (a Repeater in a Column):
// drag the handle up or down, a line shows where the row lands, release
// emits moveRequested(from, to) with `to` as the new index. The row itself
// stays in place (the Column positions it) and only fades while dragged.
Item {
    id: root

    required property Item row
    required property int index
    required property Repeater repeater
    property color lineColor: Theme.primary
    property color iconColor: Theme.surfaceText

    signal moveRequested(int from, int to)

    implicitWidth: 32
    implicitHeight: 32

    // Insertion slot under the mouse: 0 … count (before row i / after last)
    property int slot: -1
    readonly property bool dragging: area.pressed && slot >= 0

    function slotFor(y) {
        for (let i = 0; i < repeater.count; i++) {
            const it = repeater.itemAt(i);
            if (it && y < it.y + it.height / 2)
                return i;
        }
        return repeater.count;
    }
    function slotY(s) {
        if (s < repeater.count)
            return repeater.itemAt(s)?.y ?? 0;
        const last = repeater.itemAt(repeater.count - 1);
        return last ? last.y + last.height : 0;
    }

    DIcon {
        anchors.centerIn: parent
        name: "drag_indicator"
        size: Theme.iconSize
        color: root.iconColor
        opacity: area.containsMouse || area.pressed ? 1 : 0.6
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: root.slot = root.index
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const p = mapToItem(root.row.parent, mouse.x, mouse.y);
            root.slot = root.slotFor(p.y);
        }
        onReleased: {
            const s = root.slot;
            root.slot = -1;
            // Slots index and index + 1 are the row's own place
            if (s >= 0 && s !== root.index && s !== root.index + 1)
                root.moveRequested(root.index, s > root.index ? s - 1 : s);
        }
        onCanceled: root.slot = -1
    }

    Binding {
        target: root.row
        property: "opacity"
        value: 0.5
        when: root.dragging
    }

    // Insertion line: on the list's parent (the Column would position it)
    Rectangle {
        parent: root.row.parent?.parent ?? root
        visible: root.dragging && root.slot !== root.index && root.slot !== root.index + 1
        z: 100
        x: root.row.parent?.x ?? 0
        y: (root.row.parent?.y ?? 0) + root.slotY(root.slot) - height / 2
        width: root.row.parent?.width ?? 0
        height: 2
        radius: 1
        color: root.lineColor
    }
}
