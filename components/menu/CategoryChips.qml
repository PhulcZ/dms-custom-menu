import QtQuick
import qs.Common
import qs.Widgets
import "../common"

// Category chips that look like DMS' DFilterChips but are stylable.
// DFilterChips hard-codes colours and borders; the defaults here
// match its values exactly (border outlineVariant, selected
// secondaryContainer, height buttonHeightXS, radius cornerRadiusS).
// Grid instead of Flow: Flow has one spacing for both directions. All
// chips have the same width, so the column count follows from the width.
Grid {
    id: root

    property real availableWidth: width
    columns: vertical ? 1 : Math.max(1, Math.floor((availableWidth + columnSpacing) / (chipWidth + columnSpacing)))

    property var categories: []
    property int currentIndex: 0
    property bool vertical: false
    // "left" or "center"; "auto" = as before: one column left, else centred
    property string textAlign: "auto"
    readonly property bool alignLeft: textAlign === "left" || (textAlign === "auto" && vertical)

    property real chipHeight: Theme.buttonHeightXS
    // All chips have the same width; text that is too long is elided with …
    property real chipWidth: 120
    property real chipPadding: Theme.spacingL
    property real chipRadius: Theme.cornerRadiusS
    property real borderWidth: Theme.outlineWidth
    property color borderColor: Theme.outlineVariant
    property color backgroundColor: "transparent"
    property color selectedColor: Theme.secondaryContainer
    property color textColor: Theme.onSurfaceVariant
    property color selectedTextColor: Theme.onSecondaryContainer
    // Selected chip: border colour ("transparent" = no border, as before)
    // and text weight (-1 = as the normal text)
    property color selectedBorderColor: "transparent"
    property int selectedTextWeight: -1
    // Hovered chip (not selected): background (default: DMS' hover state
    // layer), border and text; weight -1 = as the normal text
    property color hoverColor: Theme.withAlpha(Theme.onSurface, Theme.stateLayerHover)
    property color hoverBorderColor: borderColor
    property color hoverTextColor: textColor
    property int hoverTextWeight: -1
    property bool showIcons: false
    property real iconSize: Theme.iconSizeSmall
    // Icon colour: own setting, not tied to text or selection colour;
    // iconColors overrides it per category (glyph icons only, icon files
    // keep their own colours)
    property color iconColor: Theme.onSurfaceVariant
    property var iconColors: ({})
    property var iconOverrides: ({})
    property real textSize: Theme.fontSizeSmall
    property int textWeight: Font.Normal

    signal selected(int index)
    signal appDropped(int index)

    // An app is being dragged: the chips that take it ("All" does not)
    // light up briefly, then stay faintly marked, like the free cells of
    // the tile elements
    property bool dropHint: false
    // Settings section of each chip (menu with the settings open: hover and
    // click lead there); "" = none
    property string chipJumpSection: ""
    // Optional extra layer per chip (e.g. its blur region), filling the chip;
    // gets chipRadius
    property Component chipDecoration: null
    property real hintLevel: 0
    onDropHintChanged: {
        hintPulse.stop();
        if (dropHint)
            hintPulse.start();
        else
            hintLevel = 0;
    }
    SequentialAnimation {
        id: hintPulse
        NumberAnimation {
            target: root
            property: "hintLevel"
            from: 0
            to: 0.35
            duration: 180
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "hintLevel"
            to: 0.1
            duration: 520
            easing.type: Easing.InOutQuad
        }
    }

    // Vertical: as wide as one chip, so one chip per row
    readonly property real widestChip: chipWidth

    Repeater {
        id: repeater
        model: root.categories

        StyledRect {
            id: chip
            required property var modelData
            required property int index
            readonly property string jumpSection: root.chipJumpSection
            readonly property bool isSelected: index === root.currentIndex
            readonly property bool isHovered: !isSelected && area.containsMouse
            width: root.chipWidth
            height: root.chipHeight
            radius: root.chipRadius
            color: isSelected ? root.selectedColor : isHovered ? root.hoverColor : root.backgroundColor
            border.width: isSelected && root.selectedBorderColor.a === 0 ? 0 : root.borderWidth
            border.color: isSelected ? root.selectedBorderColor : isHovered ? root.hoverBorderColor : root.borderColor

            // No check mark: selection is shown by colour only. Icon optional
            // (setting). Text aligned per textAlign.
            Row {
                id: row
                anchors.verticalCenter: parent.verticalCenter
                readonly property real available: parent.width - root.chipPadding * 2
                x: root.alignLeft ? root.chipPadding : (parent.width - width) / 2
                width: Math.min(implicitWidth, available)
                spacing: Theme.spacingS

                FlexIcon {
                    id: chipIcon
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showIcons && icon !== ""
                    icon: root.iconOverrides[chip.modelData.key] || chip.modelData.icon || ""
                    size: root.iconSize
                    color: root.iconColors[chip.modelData.key] || root.iconColor
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, row.available - (chipIcon.visible ? chipIcon.width + row.spacing : 0))
                    text: chip.modelData.text
                    font.pixelSize: root.textSize
                    font.weight: chip.isSelected && root.selectedTextWeight >= 0 ? root.selectedTextWeight : chip.isHovered && root.hoverTextWeight >= 0 ? root.hoverTextWeight : root.textWeight
                    color: chip.isSelected ? root.selectedTextColor : chip.isHovered ? root.hoverTextColor : root.textColor
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                }
            }

            Loader {
                anchors.fill: parent
                active: root.chipDecoration !== null
                sourceComponent: root.chipDecoration
                readonly property real chipRadius: chip.radius
            }

            // Drop target for dragged apps; highlighted while hovered
            DropArea {
                id: chipDrop
                anchors.fill: parent
                keys: ["custommenu-app"]
                onDropped: root.appDropped(chip.index)
            }
            // Drag hint: contrasting with the chip (light chip → black,
            // dark → white)
            Rectangle {
                anchors.fill: parent
                visible: root.hintLevel > 0 && chip.modelData.key !== "__all"
                radius: parent.radius
                readonly property color base: chip.color.a > 0 ? chip.color : Theme.surface
                readonly property color contrast: 0.2126 * base.r + 0.7152 * base.g + 0.0722 * base.b > 0.5 ? "black" : "white"
                color: Theme.withAlpha(contrast, root.hintLevel)
            }
            Rectangle {
                anchors.fill: parent
                visible: chipDrop.containsDrag
                radius: parent.radius
                color: Theme.withAlpha(Theme.primary, 0.15)
                border.width: 2
                border.color: Theme.primary
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selected(chip.index)
            }
        }
    }
}
