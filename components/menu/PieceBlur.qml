import QtQuick
import QtQuick.Controls as QQC
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.DCommon.Common as DC
import qs.Modules.Plugins

// Level 4 blur: the blur region of one chip, tile or the search field
// (piece, default the parent), exactly in its shape; inside a scrolling
// element cut to its visible part (viewport), so nothing blurs outside
// the element. Registered as a blur part while wanted.
Item {
    id: pb
    // The menu widget (CustomMenuWidget): its settings and functions
    required property Item menu
    property Item piece: parent
    property real radius: 0
    property Item viewport: null
    property bool active: true
    readonly property string partKey: "piece:" + Math.random().toString(36).slice(2)
    readonly property bool wanted: active && menu.menuTransparent && menu.pieceBlur && piece !== null && piece.visible
    property var region: Region {
        readonly property var g: pb.wanted ? pb.geom(menu.menuOpen, menu.dmsWrapper?.x ?? 0, menu.dmsWrapper?.y ?? 0, menu.dmsWrapper?.scale ?? 1, pb.viewport?.contentX ?? 0, pb.viewport?.contentY ?? 0, pb.piece?.width ?? 0, pb.piece?.height ?? 0, menu.layoutItems) : ({ "x": 0, "y": 0, "w": 0, "h": 0, "r": 0 })
        x: g.x
        y: g.y
        width: g.w
        height: g.h
        radius: g.r
    }
    function geom(open, wx, wy, ws, cx, cy, w, h) {
        const g = menu.blurGeom(piece, open, wx, wy, ws, 0, 0, w, h, radius);
        if (!viewport || g.w <= 0)
            return g;
        const a = viewport.mapToItem(null, 0, 0), b = viewport.mapToItem(null, viewport.width, viewport.height);
        const x0 = Math.max(g.x, a.x), y0 = Math.max(g.y, a.y), x1 = Math.min(g.x + g.w, b.x), y1 = Math.min(g.y + g.h, b.y);
        if (x1 <= x0 || y1 <= y0)
            return { "x": 0, "y": 0, "w": 0, "h": 0, "r": 0 };
        // Cut at the element edge: straight corners there
        const cut = x0 > g.x || y0 > g.y || x1 < g.x + g.w || y1 < g.y + g.h;
        return { "x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0, "r": cut ? 0 : g.r };
    }
    onWantedChanged: menu.setBlurPart(partKey, wanted ? region : null)
    Component.onCompleted: if (wanted) menu.setBlurPart(partKey, region)
    Component.onDestruction: menu.setBlurPart(partKey, null)
}
