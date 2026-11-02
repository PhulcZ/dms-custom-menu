import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets
import "../../FontLogos.js" as FontLogos

// Shows an icon value: a file path as a (coloured) image, "logo:<name>" as
// a logo of the font-logos font, "dms:logo" as DMS' own logo (from the
// running shell, so it survives DMS updates), anything else as a Material
// Symbols icon; logos and symbols in the given colour.
Item {
    id: root

    property string icon: ""
    property real size: Theme.iconSize
    property color color: Theme.surfaceText
    readonly property bool isFile: icon.startsWith("/")
    readonly property bool isLogo: icon.startsWith("logo:")
    readonly property bool isDms: icon === "dms:logo"

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    FontLoader {
        id: logoFont
        source: root.isLogo ? Qt.resolvedUrl("../../assets/font-logos/font-logos.ttf") : ""
    }
    Text {
        anchors.centerIn: parent
        visible: root.isLogo
        text: root.isLogo ? FontLogos.glyph(root.icon.substring(5)) : ""
        font.family: logoFont.name
        font.pixelSize: root.size
        color: root.color
        renderType: Text.NativeRendering
    }

    DIcon {
        anchors.centerIn: parent
        visible: !root.isFile && !root.isLogo && !root.isDms
        name: root.isFile || root.isLogo || root.isDms ? "" : root.icon
        size: root.size
        color: root.color
    }

    // DMS' logo is white: tinted with the icon colour
    Image {
        id: dmsLogo
        anchors.fill: parent
        visible: false
        source: root.isDms ? "file://" + Theme.shellDir + "/assets/danklogo.svg" : ""
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
    MultiEffect {
        anchors.fill: parent
        visible: root.isDms
        source: dmsLogo
        colorization: 1.0
        colorizationColor: root.color
    }

    Image {
        anchors.fill: parent
        visible: root.isFile
        source: root.isFile ? "file://" + root.icon : ""
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
    }
}
