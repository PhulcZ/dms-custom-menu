import QtQuick
import qs.Common
import qs.Widgets

// Content of one app tile, built from three parts: icon, name, description.
// Each part can be switched off (icon or name always stays). Arrangement:
//   iconPosition: "top", "left", "right"
//   textAlign:    "left", "center", "right"
// Optional text background: on top it is a strip along the bottom edge
// (the former "tiles" look), on the side it fills the text area.
// The icon wins: its size only depends on iconSize and only shrinks when
// the tile is too small. The text area has a fixed height, so a wrapping
// name never shifts the icons.
Item {
    id: root

    property var app: null

    property bool showIcon: true
    property bool showName: true
    property bool showDescription: false
    property string iconPosition: "top"
    property string textAlign: "center"

    property int iconSize: 40
    property real padding: Theme.spacingS
    property real textSize: Theme.fontSizeSmall
    property int textWeight: Font.Normal
    property color textColor: Theme.surfaceText
    property bool textBackground: false
    property color textBackgroundColor: Theme.chipSurfaceNested
    // Radius of the surrounding chip; the text background follows it on the
    // edges it shares with the chip.
    property real cornerRadius: Theme.cornerRadius
    // Icon on the side: extra shift towards the text (on top of the edge gap,
    // which equals the gap above/below the icon)
    property real iconOffset: 0
    // Gap between icon and text (side by side or icon on top)
    property real iconTextGap: Theme.spacingS
    // Gap between name and description
    property real descriptionGap: Theme.spacingXXS
    property color fallbackColor: Theme.primaryContainer
    property color fallbackLetterColor: Theme.onPrimaryContainer
    // Own icon colour of this app ("" = none); only for symbol icons
    // ("material:…"), icon files keep their colours
    property string iconColor: ""

    readonly property bool vertical: iconPosition === "top"
    readonly property bool hasIcon: showIcon || !showName
    readonly property bool hasText: showName || showDescription
    readonly property bool hasDescription: showDescription && ((app?.comment || "").length > 0 || !!app?.badge)

    readonly property real lineHeight: Math.ceil(textSize * 1.3)
    // The description uses a smaller font and a tighter line
    readonly property real descriptionSize: Math.max(8, Math.round(textSize * 0.85))
    readonly property real descriptionLineHeight: Math.ceil(descriptionSize * 1.25)
    // On top without description the name may use two lines
    readonly property int nameLines: vertical && !showDescription && spaceForText >= lineHeight * 2 ? 2 : 1
    readonly property real textBlockHeight: (showName ? lineHeight * nameLines : 0) + (showDescription ? (showName ? descriptionGap : 0) + descriptionLineHeight : 0)
    // The icon wins: below it only one text line is guaranteed, the name
    // drops to one line when space is short.
    readonly property real minTextHeight: hasText ? lineHeight + (textBackground ? padding * 2 : 0) : 0
    readonly property int effectiveIconSize: Math.max(8, Math.min(iconSize, width - padding * 2, height - padding * 2 - (vertical ? minTextHeight : 0)))
    readonly property real spaceForText: vertical ? height - padding * 2 - effectiveIconSize - (textBackground ? padding * 2 : 0) : height
    readonly property real iconAreaSize: effectiveIconSize + padding * 2
    // Side layout: gap to the tile edge = gap above/below, plus the offset
    readonly property real sideGap: Math.max(padding, (height - effectiveIconSize) / 2)
    readonly property real sideAreaWidth: sideGap + iconOffset + effectiveIconSize + iconTextGap
    // Icon on top: the icon area already includes padding below the icon
    readonly property real verticalGap: iconTextGap - padding
    readonly property int hAlign: textAlign === "left" ? Text.AlignLeft : (textAlign === "right" ? Text.AlignRight : Text.AlignHCenter)

    // Text area geometry
    readonly property real textAreaX: !hasIcon || vertical ? 0 : (iconPosition === "left" ? sideAreaWidth : 0)
    readonly property real textAreaWidth: !hasIcon || vertical ? width : width - sideAreaWidth
    readonly property real textAreaHeight: vertical ? (textBackground ? textBlockHeight + padding * 2 : textBlockHeight) : height
    readonly property real textAreaY: {
        if (!vertical)
            return 0;
        if (!hasIcon)
            return (height - textAreaHeight) / 2;
        if (textBackground)
            return height - textAreaHeight;
        return (height - iconAreaSize - verticalGap - textAreaHeight) / 2 + iconAreaSize + verticalGap;
    }

    // Settings sections of icon and text (menu with the settings open:
    // hover and click lead there); "" = none
    property string iconJumpSection: ""
    property string textJumpSection: ""

    // Icon area
    Item {
        visible: root.hasIcon
        x: root.vertical ? 0 : (root.iconPosition === "left" || !root.hasText ? 0 : root.width - root.sideAreaWidth)
        y: {
            if (!root.vertical || !root.hasText)
                return root.vertical ? (root.height - root.iconAreaSize) / 2 : 0;
            if (root.textBackground)
                return (root.height - root.textAreaHeight - root.verticalGap - root.iconAreaSize) / 2;
            return (root.height - root.iconAreaSize - root.verticalGap - root.textAreaHeight) / 2;
        }
        width: root.vertical || !root.hasText ? root.width : root.sideAreaWidth
        height: root.vertical ? root.iconAreaSize : root.height

        AppIconRenderer {
            readonly property string jumpSection: root.iconJumpSection
            readonly property bool side: !root.vertical && root.hasText
            anchors.verticalCenter: parent.verticalCenter
            x: !side ? (parent.width - width) / 2 : (root.iconPosition === "left" ? root.sideGap + root.iconOffset : root.iconTextGap)
            width: root.effectiveIconSize
            height: root.effectiveIconSize
            iconSize: root.effectiveIconSize
            iconValue: root.app?.icon || ""
            fallbackText: (root.app?.name || "?").charAt(0).toUpperCase()
            fallbackBackgroundColor: root.fallbackColor
            fallbackTextColor: root.fallbackLetterColor
            colorOverride: root.iconColor && iconValue.startsWith("material:") ? root.iconColor : "transparent"
        }
    }

    // Text area (optional background)
    Rectangle {
        visible: root.hasText
        x: root.textAreaX
        y: root.textAreaY
        width: root.textAreaWidth
        height: root.textAreaHeight
        color: root.textBackground ? root.textBackgroundColor : "transparent"
        clip: true
        readonly property bool atBottom: root.vertical && root.hasIcon
        readonly property bool full: !root.hasIcon
        topLeftRadius: full || (!root.vertical && root.iconPosition === "right") ? root.cornerRadius : 0
        bottomLeftRadius: full || atBottom || (!root.vertical && root.iconPosition === "right") ? root.cornerRadius : 0
        topRightRadius: full || (!root.vertical && root.iconPosition === "left") ? root.cornerRadius : 0
        bottomRightRadius: full || atBottom || (!root.vertical && root.iconPosition === "left") ? root.cornerRadius : 0

        Column {
            readonly property string jumpSection: root.textJumpSection
            anchors.verticalCenter: parent.verticalCenter
            x: root.padding
            width: parent.width - root.padding * 2
            spacing: root.descriptionGap

            StyledText {
                visible: root.showName
                width: parent.width
                height: root.lineHeight * root.nameLines
                text: root.app?.name || ""
                font.pixelSize: root.textSize
                font.weight: root.textWeight
                lineHeightMode: Text.FixedHeight
                lineHeight: root.lineHeight
                color: root.textColor
                horizontalAlignment: root.hAlign
                verticalAlignment: Text.AlignVCenter
                wrapMode: root.nameLines > 1 ? Text.Wrap : Text.NoWrap
                maximumLineCount: root.nameLines
                elide: Text.ElideRight
            }

            // Description, optionally after a badge (search results: e.g.
            // "Nextcloud" instead of the path up to that folder)
            Item {
                id: descriptionLine
                visible: root.showDescription
                width: parent.width
                height: root.descriptionLineHeight
                readonly property string badge: root.app?.badge || ""
                readonly property real badgeWidth: badge ? badgeText.implicitWidth + Theme.spacingXS * 2 : 0
                readonly property real gap: badge && descriptionText.text ? Theme.spacingXS : 0
                readonly property real textWidth: Math.max(0, Math.min(descriptionText.implicitWidth, width - badgeWidth - gap))
                readonly property real contentWidth: badgeWidth + gap + textWidth
                readonly property real startX: root.hAlign === Text.AlignLeft ? 0 : root.hAlign === Text.AlignRight ? width - contentWidth : (width - contentWidth) / 2

                Rectangle {
                    visible: !!descriptionLine.badge
                    x: descriptionLine.startX
                    anchors.verticalCenter: parent.verticalCenter
                    width: descriptionLine.badgeWidth
                    height: badgeText.implicitHeight + 2
                    radius: height / 2
                    color: Theme.withAlpha(root.textColor, 0.15)

                    StyledText {
                        id: badgeText
                        anchors.centerIn: parent
                        text: descriptionLine.badge
                        font.pixelSize: Math.max(8, root.descriptionSize - 1)
                        color: Theme.withAlpha(root.textColor, 0.8)
                    }
                }

                StyledText {
                    id: descriptionText
                    x: descriptionLine.startX + descriptionLine.badgeWidth + descriptionLine.gap
                    width: descriptionLine.textWidth
                    height: parent.height
                    text: root.app?.comment || ""
                    font.pixelSize: root.descriptionSize
                    color: Theme.withAlpha(root.textColor, 0.7)
                    verticalAlignment: Text.AlignVCenter
                    // Paths: cut on the left (the nearest folder and the counts stay)
                    elide: root.app?.isFileResult ? Text.ElideLeft : Text.ElideRight
                    // One line (wrapping would show only the start of the path)
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                }
            }
        }
    }
}
