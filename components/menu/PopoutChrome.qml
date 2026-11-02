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
import Quickshell.Io

// Hand-work on DMS' popout internals for CustomMenuWidget (moved out of it):
// the popout host and its chrome, detaching from the frame, shadows, the
// own opening animation, blur regions, the menu's position and the
// settings window beside it. Reads and writes the menu's state (menu.*);
// the menu keeps one-line wrappers with the same names.
Item {
    id: chrome
    visible: false
    required property Item menu

    // The DMS popout of this widget, also before its content first loaded
    function ownPopout() {
        if (menu.activePopout)
            return menu.activePopout;
        for (const child of menu.children) {
            if ("pluginContent" in child)
                return child;
        }
        return null;
    }

    function captureDmsTrigger(p) {
        menu.dmsTrigger = {
            x: p.triggerX,
            y: p.triggerY,
            width: p.triggerWidth,
            section: p.triggerSection,
            position: p.effectiveBarPosition,
            thickness: p.storedBarThickness,
            spacing: p.storedBarSpacing,
            config: p.storedBarConfig
        };
    }

    // positionPopout() just reset the trigger to the widget: before
    // opening detach/attach and place; before closing place again, so the
    // close animation ends at the menu.
    function prepareToggle(p) {
        captureDmsTrigger(p);
        if (!p.shouldBeVisible)
            applyDetach(p);
        applyMenuPosition(p);
    }

    function setTrigger(p, t) {
        p.setTriggerPosition(t.x, t.y, t.width, t.section, p.screen, t.position, t.thickness, t.spacing, t.config, root);
    }

    function applyMenuPosition(p) {
        if (!p || !menu.dmsTrigger || !p.screen)
            return;
        const t = menu.dmsTrigger;
        const screen = p.screen;
        const w = menu.popoutWidth;
        const h = menu.popoutHeight;
        const centreX = screen.width / 2 + menu.menuOffsetX;
        const centreY = screen.height / 2 + menu.menuOffsetY;

        if (menu.menuAnchor === "widget") {
            setTrigger(p, t);
            return;
        }

        if (menu.menuAnchor === "screen") {
            // Keep DMS' bar context; only move the trigger. "Across the bar"
            // never goes past DMS' own spot, so the menu never covers the bar.
            setTrigger(p, t);
            const x = centreX - w / 2;
            const y = centreY - h / 2;
            switch (t.position) {
            case SettingsData.Position.Left:
                p.triggerY = centreY;
                p.triggerX = Math.max(t.x, x);
                break;
            case SettingsData.Position.Right:
                p.triggerY = centreY;
                p.triggerX = Math.min(t.x, x + w);
                break;
            case SettingsData.Position.Bottom:
            case SettingsData.Position.BottomCenter:
                p.triggerX = centreX - t.width / 2;
                p.triggerY = Math.min(t.y, y + h);
                break;
            default:
                p.triggerX = centreX - t.width / 2;
                p.triggerY = Math.max(t.y, y);
            }
            return;
        }

        // Out of a screen edge: pretend the widget sits on that edge, at the
        // frame's inner border (0 without frame; DMS adds its gaps then).
        // The frame joins the menu there like with a bar on that edge.
        const inset = SettingsData.frameEdgeInsetForSide(screen, menu.menuAnchor);
        // No inline/popout expansion: those would re-anchor at the widget
        const config = t.config ? Object.assign({}, t.config, {
            widgetExpansion: ""
        }) : null;
        const edge = {
            width: t.width,
            section: t.section,
            thickness: inset,
            spacing: t.spacing,
            config: config
        };
        switch (menu.menuAnchor) {
        case "left":
            setTrigger(p, Object.assign(edge, { x: inset, y: centreY, position: SettingsData.Position.Left }));
            break;
        case "right":
            setTrigger(p, Object.assign(edge, { x: screen.width - inset, y: centreY, position: SettingsData.Position.Right }));
            break;
        case "top":
            setTrigger(p, Object.assign(edge, { x: centreX - t.width / 2, y: inset, position: SettingsData.Position.Top }));
            break;
        case "bottom":
            setTrigger(p, Object.assign(edge, { x: centreX - t.width / 2, y: screen.height - inset, position: SettingsData.Position.Bottom }));
            break;
        }
    }

    // In the connected frame mode DMS draws the menu as part of the frame.
    // Free placement detaches it: the popout host then runs standalone (own
    // surface and background), as without frame. DMS rebuilds
    // the host when the frame mode changes; the next opening applies it again.
    // The host sits in a Loader directly inside DPopout (not reachable
    // via parent from the content: its window breaks the parent chain).
    // Depth-first search in DMS' item trees (popout chrome, wrapper): the
    // first item / all items for which test(item) holds
    function findItem(item, test) {
        if (!item)
            return null;
        if (test(item))
            return item;
        for (const child of item.children) {
            const found = findItem(child, test);
            if (found)
                return found;
        }
        return null;
    }

    function findItems(item, test, out) {
        out = out ?? [];
        if (!item)
            return out;
        if (test(item))
            out.push(item);
        for (const child of item.children)
            findItems(child, test, out);
        return out;
    }

    function popoutHost(p) {
        for (const child of p?.children ?? []) {
            if (child.item && "popoutHandle" in child.item)
                return child.item;
        }
        return null;
    }

    // Free menu that reaches the bar side (as large as DMS' own spot or
    // larger, e.g. fullscreen): it sits where a docked menu sits, so it
    // stays joined to the frame like a docked one
    function freeTouchesBar(p) {
        const t = menu.dmsTrigger;
        const screen = p?.screen;
        if (!t || !screen)
            return false;
        const w = menu.popoutWidth, h = menu.popoutHeight;
        const x = screen.width / 2 + menu.menuOffsetX - w / 2;
        const y = screen.height / 2 + menu.menuOffsetY - h / 2;
        switch (t.position) {
        case SettingsData.Position.Left:
            return x <= t.x + 0.5;
        case SettingsData.Position.Right:
            return x + w >= t.x - 0.5;
        case SettingsData.Position.Bottom:
        case SettingsData.Position.BottomCenter:
            return y + h >= t.y - 0.5;
        default:
            return y <= t.y + 0.5;
        }
    }

    function applyDetach(p) {
        const host = popoutHost(p);
        if (!host || host.shouldBeVisible)
            return;
        // A free menu without its trigger (reset while closing): whether it
        // reaches the bar is unknown, keep the connection as it is (detaching
        // it mid-close left DMS' frame drawing its surface over the screen)
        if (menu.menuAnchor === "screen" && !menu.dmsTrigger && !menu.menuTransparent) {
            applySurfaceVisibility(host);
            return;
        }
        menu.freeJoined = menu.menuAnchor === "screen" && freeTouchesBar(p);
        if ((menu.menuAnchor === "screen" && !freeTouchesBar(p)) || menu.menuTransparent) {
            if (host.connected)
                host.connected = false;
            adjustDetachedChrome(host);
        } else if (!host.connected && p._resolvedConnected) {
            host.connected = Qt.binding(() => p._resolvedConnected);
        }
        applySurfaceVisibility(host);
    }

    function adjustDetachedChrome(host) {
        const find = findItem;
        const chrome = find(host.contentWindow?.contentItem, item => "blur" in item && "contentWrapper" in item);
        const clip = find(chrome, item => "revealActive" in item && "targetRect" in item);
        // As Binding objects that hold only while the menu is detached: a
        // menu joined to the frame again (e.g. a free one reaching the bar)
        // gets DMS' own bindings back. Assigned for good, they outlived the
        // detaching and the frame drew the closed menu's surface over the
        // whole screen. Made once per host; menuShadow is read live.
        if (menu.detachBound.indexOf(host) >= 0)
            return;
        menu.detachBound = menu.detachBound.concat([host]);
        const hold = (target, property, fn) => {
            const b = Qt.createQmlObject('import QtQuick; Binding { property: "' + property + '" }', target, "detachBinding");
            b.target = target;
            b.value = Qt.binding(fn);
            b.when = Qt.binding(() => !host.connected);
        };
        if (clip)
            hold(clip, "clip", () => clip.active ? (clip.body.width < clip.targetRect.width || clip.body.height < clip.targetRect.height) : clip.revealActive && (clip.revealWidth < clip.targetRect.width - 0.5 || clip.revealHeight < clip.targetRect.height - 0.5));
        // DMS has two shadow layers. Opening and closing, the menu rolls
        // out and up (a detached menu uses the frame's directional reveal),
        // but the shadow layer of that reveal keeps its full size: it
        // showed before the menu when opening and stayed after it when
        // closing. So with DMS' animation the shadows show only while the
        // menu is fully open. The own animations (menuAnimation) animate
        // the shadows with the menu instead (applyAnimation).
        const ownAnimation = () => menu.menuAnimation !== "dms" && !host._fluidMotionActive;
        const findAll = findItems;
        const shadows = findAll(host.contentWindow?.contentItem, item => "shadowEnabled" in item && "targetRadius" in item, []);
        for (const shadow of shadows) {
            // The second layer belongs to the frame's reveal: as tall as the
            // menu plus what reaches into the frame, so detached it showed
            // a shadow past the menu's bottom. Off; the first layer (exactly
            // the menu's size) draws the shadow
            const menuSized = shadow.parent?.baseWidth !== undefined;
            hold(shadow, "shadowEnabled", () => menuSized && menu.menuShadow && Theme.elevationEnabled && SettingsData.popoutElevationEnabled && (ownAnimation() || (!host.isClosing && !(clip && clip.revealActive && (clip.revealWidth < clip.targetRect.width - 0.5 || clip.revealHeight < clip.targetRect.height - 0.5)))));
        }
    }

    function blurGeom(item, open, wx, wy, ws, ix, iy, iw, ih, ir) {
        if (!item || !open || iw <= 0 || ih <= 0)
            return { "x": 0, "y": 0, "w": 0, "h": 0, "r": 0 };
        const p = item.mapToItem(null, 0, 0);
        const q = item.mapToItem(null, iw, ih);
        const f = iw > 0 ? (q.x - p.x) / iw : 1;
        return { "x": p.x, "y": p.y, "w": q.x - p.x, "h": q.y - p.y, "r": Math.max(0, ir * f) };
    }

    function applyOwnBlur() {
        const win = popoutHost(menu.activePopout)?.contentWindow;
        if (!win || !menu.menuTransparent)
            return;
        const parts = Object.keys(menu.blurParts).map(k => menu.blurParts[k]);
        if (parts.length === 0 || !BlurService.enabled) {
            win.BackgroundEffect.blurRegion = null;
            return;
        }
        if (!menu.blurRoot) {
            menu.blurRoot = Qt.createQmlObject('import Quickshell; Region {}', root, "blurRoot");
            menu.blurClip = Qt.createQmlObject('import Quickshell; Region { intersection: Intersection.Intersect }', root, "blurClip");
        }
        menu.blurClip.width = Qt.binding(() => win.width);
        menu.blurClip.height = Qt.binding(() => win.height);
        menu.blurRoot.regions = parts.concat([menu.blurClip]);
        win.BackgroundEffect.blurRegion = menu.blurRoot;
    }

    function applyAnimation(host, chrome, wrapper) {
        if (menu.animBound.indexOf(wrapper) >= 0)
            return;
        const find = findItem;
        // DMS' content container (holds the progress) is outside the chrome
        const cc = find(host.contentWindow?.contentItem, item => "morphProgress" in item && "scaleValue" in item);
        const win = host.contentWindow;
        if (!cc || !win) {
            console.warn("customMenu: animation container not found (DMS changed?)");
            return;
        }
        // Only for a free-standing menu: docked, DMS' frame grows the surface
        // from the bar and the content has to follow it
        const custom = () => menu.menuAnimation !== "dms" && !host._fluidMotionActive && !host.connected;
        const startScale = () => menu.menuAnimation === "screenCenter" ? 0.15 : 0.6;
        // "screenCenter": the menu's window is only as big as the menu, so it
        // cannot start in the middle of the screen. It starts at the point of
        // its own area nearest to the screen's middle (an edge or a corner)
        // and grows from there. Offset of the wrapper's middle to that point:
        const toCenter = axis => {
            if (menu.menuAnimation !== "screenCenter")
                return 0;
            const tl = wrapper.parent.mapToItem(null, 0, 0);
            const c = wrapper.parent.mapToItem(null, wrapper.width / 2, wrapper.height / 2);
            // Middle of the screen in window coordinates
            const sx = menu.screenWidth / 2 - (host._surfaceX ?? 0);
            const sy = menu.screenHeight / 2 - (host._surfaceY ?? 0);
            if (axis === "x")
                return Math.max(tl.x, Math.min(tl.x + wrapper.width, sx)) - c.x;
            return Math.max(tl.y, Math.min(tl.y + wrapper.height, sy)) - c.y;
        };
        const make = (property, fn) => {
            const b = Qt.createQmlObject('import QtQuick; Binding { property: "' + property + '" }', wrapper, "animBinding");
            b.target = wrapper;
            b.value = Qt.binding(fn);
            b.when = Qt.binding(custom);
        };
        make("x", () => (1 - cc.morphProgress) * toCenter("x") + 0 * win.width);
        make("y", () => (1 - cc.morphProgress) * toCenter("y") + 0 * win.height);
        make("scale", () => startScale() + (1 - startScale()) * cc.morphProgress);
        // Fade with the progress (DMS' directional effect does not fade, its
        // mask hides the menu; without the mask a small menu would linger
        // until the spring settles): gone below 10 %, full from 60 %
        make("opacity", () => Math.max(0, Math.min(1, (cc.morphProgress - 0.1) / 0.5)));
        // DMS' shadow layers (one of them keeps its full size while DMS'
        // directional reveal runs): same position, scale and fade as the
        // menu, so the shadow grows and appears with it
        const shadows = findItems(host.contentWindow?.contentItem, item => "shadowEnabled" in item && "targetRadius" in item);
        for (const shadow of shadows) {
            // DMS places the shadow of the reveal above by the overflow
            const dy = shadow.y - wrapper.y;
            for (const [property, fn] of [["x", () => wrapper.x], ["y", () => wrapper.y + dy], ["scale", () => wrapper.scale], ["opacity", () => wrapper.opacity]]) {
                const b = Qt.createQmlObject('import QtQuick; Binding { property: "' + property + '" }', shadow, "shadowAnimBinding");
                b.target = shadow;
                b.value = Qt.binding(fn);
                b.when = Qt.binding(custom);
            }
        }
        // DMS' directional effect (also the frame mode) reveals the menu with
        // a mask from the bar side: off for the own animations
        const reveal = find(chrome, item => "revealActive" in item && "targetRect" in item);
        if (reveal) {
            const b = Qt.createQmlObject('import QtQuick; Binding { property: "revealActive"; value: false }', reveal, "revealBinding");
            b.target = reveal;
            b.when = Qt.binding(custom);
        }
        menu.animState = { "bound": true, "reveal": !!reveal };
        menu.animBound = menu.animBound.concat([wrapper]);
    }

    function applySurfaceVisibility(host) {
        const find = findItem;
        const chrome = find(host.contentWindow?.contentItem, item => "blur" in item && "contentWrapper" in item);
        const wrapper = chrome?.contentWrapper;
        if (!wrapper)
            return;
        const content = host.contentLoader;
        const holds = (item, inner) => {
            for (let p = inner; p; p = p.parent) {
                if (p === item)
                    return true;
            }
            return false;
        };
        const hold = (target, property, when) => {
            if (!target || menu.surfaceBound.indexOf(target) >= 0)
                return;
            const b = Qt.createQmlObject('import QtQuick; Binding { property: "' + property + '"; value: false }', target, "surfaceBinding");
            b.target = target;
            b.when = Qt.binding(when);
            menu.surfaceBound = menu.surfaceBound.concat([target]);
        };
        const targets = [];
        for (const c of wrapper.parent?.children ?? []) {
            if (c !== wrapper && !holds(c, content))
                targets.push(c);
        }
        for (const c of wrapper.children) {
            if (!holds(c, content))
                targets.push(c);
        }
        for (const t of targets)
            hold(t, "visible", () => menu.menuTransparent);
        // DMS' WindowBlur re-publishes its region on every animation step
        // (and would clear ours): detached from the window meanwhile
        if (chrome.blur) {
            hold(chrome.blur, "blurEnabled", () => menu.menuTransparent);
            if (menu.surfaceBound.indexOf(chrome.blur.parent) < 0) {
                const b = Qt.createQmlObject('import QtQuick; Binding { property: "targetWindow"; value: null }', chrome.blur, "blurWindowBinding");
                b.target = chrome.blur;
                b.when = Qt.binding(() => menu.menuTransparent);
                menu.surfaceBound = menu.surfaceBound.concat([chrome.blur.parent]);
            }
        }
        menu.dmsWrapper = wrapper;
        applyAnimation(host, chrome, wrapper);
    }

    function placeSettingsWindow() {
        const popout = menu.activePopout;
        const screen = popout?.screen ?? menu.parentScreen;
        if (!popout || !menu.menuOpen || !screen)
            return false;
        const win = Hyprland.toplevels.values.find(t => menu.settingsWindowClasses.indexOf(t.lastIpcObject?.class) >= 0 && t.lastIpcObject?.floating);
        const size = win?.lastIpcObject?.size;
        if (!win || !size)
            return false;

        const w = size[0], h = size[1];
        const gap = Theme.popupDistance;
        // Menu rectangle relative to the screen, as DMS places it. Not via
        // mapToGlobal: a detached popout has its own surface, not a
        // full-screen one, so that would be relative to the surface.
        const menuLeft = popout.alignedX;
        const menuRight = popout.alignedX + popout.alignedWidth;
        const menuTop = popout.alignedY;
        const menuBottom = popout.alignedY + popout.alignedHeight;

        // Only move it when the menu covers it; a window the user put
        // somewhere free stays there.
        const at = win.lastIpcObject?.at;
        if (at) {
            const winLeft = at[0] - (screen.x || 0), winTop = at[1] - (screen.y || 0);
            const covered = winLeft < menuRight && winLeft + w > menuLeft && winTop < menuBottom && winTop + h > menuTop;
            if (!covered)
                return true;
        }

        const spaceLeft = menuLeft - gap;
        const spaceRight = screen.width - menuRight - gap;

        // No room on either side: the menu gets narrower (the change of
        // its width places the window again). Centred on its bar icon it
        // gains only half per side, so twice the missing room; stops at
        // the minimum width, then the window goes to the edge as before.
        const missing = w - Math.max(spaceLeft, spaceRight);
        const canShrink = menu.popoutWidth > Math.min(menu.fullMenuWidth, menu.minShrunkWidth) + 1;
        if (missing > 0 && canShrink) {
            const atEdge = menuLeft <= gap + 1 || menuRight >= screen.width - gap - 1;
            menu.settingsShrink += Math.ceil(atEdge ? missing : missing * 2);
            // Not done: the timer keeps polling and places the window once
            // the menu has its new width ("done" would stop the timer the
            // width change has just restarted)
            return false;
        }
        let x;
        if (spaceLeft >= spaceRight && spaceLeft >= w)
            x = menuLeft - gap - w;
        else if (spaceRight >= w)
            x = menuRight + gap;
        else
            x = spaceLeft >= spaceRight ? gap : screen.width - w - gap; // fits nowhere completely: put it at the edge
        const y = Math.max(gap, Math.min(menuTop, screen.height - h - gap));

        const absX = Math.round((screen.x || 0) + x), absY = Math.round((screen.y || 0) + y);
        Hyprland.dispatch(`hl.dsp.window.move({ window = "address:${String(win.address).startsWith("0x") ? win.address : "0x" + win.address}", x = ${absX}, y = ${absY} })`);
        return true;
    }
}
