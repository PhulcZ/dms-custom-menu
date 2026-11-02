.pragma library
.import "Defaults.js" as Defaults
.import "BuiltInTemplates.js" as BuiltIn

// Templates: named sets of setting values. The chosen template sits
// between the stored settings and the defaults (Defaults.js):
//   value = stored value ?? template value ?? default
// So "reset" (removing a stored value) goes back to the template, and
// every stored setting is a change against the template.
//
// Built-in templates: BuiltInTemplates.js; own profiles are stored in the plugin data
// as userTemplates = { name: { values } } and chosen as "user:<name>".
// "standard" has no values of its own: the defaults apply.
//
// The arrangement on the canvas (layoutKeys) belongs to a template too, but
// is handled apart: elements are content, so applying a template moves the
// elements it knows (by id) and leaves the others where they are; only
// those are compared. The settings never read it from the template.

// Built-in templates: data in BuiltInTemplates.js
var builtIn = BuiltIn.builtIn;
var builtInOrder = BuiltIn.builtInOrder;

// Only the template's elements in the menu (the others leave it; they
// return with the next template that has them)
function isExclusive(id, userTemplates) {
    if (String(id).startsWith("user:"))
        return (userTemplates ?? {})[String(id).slice(5)]?.exclusiveLayout === true;
    return builtIn[id]?.exclusiveLayout === true;
}

// Contents a template brings along (tile elements of its own layout):
// merged into the stored shortcuts where missing, never replacing the
// user's. defaultShortcuts: what the instance shows without stored ones.
function contentsFor(id, storedShortcuts, defaultShortcuts) {
    const own = String(id).startsWith("user:") ? null : builtIn[id]?.contents?.shortcuts;
    if (!own)
        return {};
    const current = storedShortcuts ?? defaultShortcuts;
    const missing = Object.keys(own).filter(k => !current[k]);
    if (missing.length === 0)
        return {};
    const next = JSON.parse(JSON.stringify(current));
    for (const k of missing)
        next[k] = JSON.parse(JSON.stringify(own[k]));
    return { "shortcuts": next };
}

// Contents of the menu, not its look and behaviour: never part of a
// template, never counted as a change, untouched by reset and switching
var contentKeys = [
    "enabled",
    "activeTemplate",
    "userTemplates",
    "shortcuts",
    "customCategories",
    "categoryExtras",
    "categoryRemovals",
    "hiddenCategories",
    "localHiddenApps",
    "appGroups",
    "appIconColors",
    "catIcons",
    "catIconColors",
    "iconFavorite1",
    "iconFavorite2",
    "iconFavorite3",
    "searchPathBadges",
    "categoryOrder",
    "deletedCategories",
    "startCategory",
    "favoritesSeeded",
    "editShowGrid",
    "subcategories",
    "variants",
    // The arrangement put aside while an exclusive template is active
    "layoutAside",
    // Notice "menu shown smaller" switched off (settings page state)
    "hideShrinkNotice"
];

// Arrangement on the canvas: positions/sizes and the locked elements
var layoutKeys = ["layout", "layoutGrid", "lockedElements"];

// Menu size. Part of every template, but handled apart: switching asks
// whether to keep the size; a template with "sizeOverlay" (Fullscreen, a
// mini menu) puts its size over the instance's own while it is active, and
// the own size (stored underneath) returns when switching away.
var sizeKeys = ["menuSizeMode", "menuSizePixels", "menuWidth", "menuHeight", "menuWidthPercent", "menuHeightPercent"];

function isSizeKey(key) {
    return sizeKeys.indexOf(key) >= 0;
}

function isOverlay(id, userTemplates) {
    if (String(id).startsWith("user:"))
        return (userTemplates ?? {})[String(id).slice(5)]?.sizeOverlay === true;
    return builtIn[id]?.sizeOverlay === true;
}

// Only the size keys of values (unset ones left out)
function sizeValues(values) {
    const out = {};
    for (const key of sizeKeys) {
        if (values?.[key] !== undefined && values?.[key] !== null)
            out[key] = values[key];
    }
    return out;
}

// The instance's own size: stored over the template's, or (an overlay
// template active) the stored one alone
function ownSize(stored, templateValues, overlay) {
    return overlay ? sizeValues(stored) : Object.assign(sizeValues(templateValues), sizeValues(stored));
}

// Effective size of size values: { mode, w, h, pw, ph }
function sizeOf(values) {
    return {
        "mode": Defaults.sizeModeOf(values),
        "w": values.menuWidth ?? Defaults.menuWidth,
        "h": values.menuHeight ?? Defaults.menuHeight,
        "pw": values.menuWidthPercent ?? Defaults.menuWidthPercent,
        "ph": values.menuHeightPercent ?? Defaults.menuHeightPercent
    };
}

function sameSize(a, b) {
    const x = sizeOf(a), y = sizeOf(b);
    if (x.mode !== y.mode)
        return false;
    if (x.mode === "pixels")
        return x.w === y.w && x.h === y.h;
    if (x.mode === "percent")
        return x.pw === y.pw && x.ph === y.ph;
    return true;
}

function isTemplateKey(key) {
    return contentKeys.indexOf(key) < 0 && layoutKeys.indexOf(key) < 0;
}

function rawValuesOf(id, userTemplates) {
    if (String(id).startsWith("user:"))
        return (userTemplates ?? {})[String(id).slice(5)]?.values ?? {};
    return builtIn[id]?.values ?? {};
}

// Setting values of a template id ("standard", "user:<name>"), without the
// arrangement
function valuesOf(id, userTemplates) {
    const values = Object.assign({}, rawValuesOf(id, userTemplates));
    for (const key of layoutKeys)
        delete values[key];
    return values;
}

// Arrangement of a template: { layout, layoutGrid, lockedElements }; the
// built-in ones (and profiles saved without one) use the default
function layoutOf(id, userTemplates) {
    const values = rawValuesOf(id, userTemplates);
    if (Array.isArray(values.layout) && values.layout.length > 0)
        return { "layout": values.layout, "layoutGrid": values.layoutGrid ?? Defaults.defaultLayoutGrid, "lockedElements": values.lockedElements ?? [] };
    return { "layout": Defaults.defaultLayout, "layoutGrid": Defaults.defaultLayoutGrid, "lockedElements": [] };
}

// Same rounding as the widget's scaleLayout
function scaleLayout(items, from, to) {
    if (!(from > 0) || !(to > 0) || from === to)
        return items.map(i => ({ "id": i.id, "col": i.col, "row": i.row, "w": i.w, "h": i.h }));
    const f = to / from;
    return items.map(i => {
        const col = Math.round(i.col * f);
        const row = Math.round(i.row * f);
        return { "id": i.id, "col": col, "row": row, "w": Math.max(1, Math.round((i.col + i.w) * f) - col), "h": Math.max(1, Math.round((i.row + i.h) * f) - row) };
    });
}

// The instance's current arrangement (stored, else the default)
function currentLayout(stored) {
    if (Array.isArray(stored.layout) && stored.layout.length > 0)
        return { "layout": stored.layout, "layoutGrid": stored.layoutGrid ?? Defaults.defaultLayoutGrid, "lockedElements": stored.lockedElements ?? [] };
    return { "layout": Defaults.defaultLayout, "layoutGrid": Defaults.defaultLayoutGrid, "lockedElements": stored.lockedElements ?? [] };
}

// Elements whose size is not part of the arrangement (only their
// position). None any more: tile elements once sized themselves by their
// contents; now they fill their place in the grid like the others, so a
// template sets their size too (else they kept an old size and the margins
// to the canvas edge were uneven)
function sizesItself(id) {
    return false;
}

// Whether the elements the template knows sit elsewhere, have another size
// or another lock than in the template
function layoutDiffers(stored, template) {
    const cur = currentLayout(stored);
    const mine = scaleLayout(cur.layout, cur.layoutGrid, template.layoutGrid);
    for (const t of template.layout) {
        const m = mine.find(i => i.id === t.id);
        if (!m)
            continue;
        // Tolerance: snapping to the grid cells of the menu shifts by a little
        const tol = Math.max(0, Math.round(template.layoutGrid / 100));
        const off = (a, b) => Math.abs(a - b) > tol;
        if (off(m.col, t.col) || off(m.row, t.row) || (!sizesItself(t.id) && (off(m.w, t.w) || off(m.h, t.h))))
            return true;
        if ((cur.lockedElements.indexOf(t.id) >= 0) !== (template.lockedElements.indexOf(t.id) >= 0))
            return true;
    }
    return false;
}

// Arrangement after applying a template: its elements take its place and
// size and lock, the others stay
function applyLayout(stored, template, exclusive) {
    const cur = currentLayout(stored);
    const grid = cur.layoutGrid;
    const fromTemplate = scaleLayout(template.layout, template.layoutGrid, grid);
    // Exclusive (to or from such a template): exactly the template's
    // elements, where it has them
    if (exclusive)
        return { "layout": fromTemplate, "layoutGrid": grid, "lockedElements": template.lockedElements.slice() };
    const layout = scaleLayout(cur.layout, grid, grid).map(i => {
        const t = fromTemplate.find(x => x.id === i.id);
        if (!t)
            return i;
        return sizesItself(i.id) ? Object.assign({}, i, { "col": t.col, "row": t.row }) : t;
    });
    const known = id => template.layout.some(t => t.id === id);
    const locked = cur.lockedElements.filter(id => !known(id)).concat(template.lockedElements.filter(id => layout.some(i => i.id === id)));
    return { "layout": layout, "layoutGrid": grid, "lockedElements": locked };
}

// Built-in names go through the translation unless "translate" is false
function translated(id) {
    return !String(id).startsWith("user:") && builtIn[id]?.translate !== false;
}

function nameOf(id) {
    if (String(id).startsWith("user:"))
        return String(id).slice(5);
    return builtIn[id]?.name ?? String(id);
}

// Stored settings that differ from the template (key → value)
function changes(stored, templateValues) {
    const out = {};
    for (const key of Object.keys(stored ?? {})) {
        if (!isTemplateKey(key) || isSizeKey(key))
            continue;
        const v = stored[key];
        if (v === undefined || v === null)
            continue;
        if (JSON.stringify(v) !== JSON.stringify(templateValues[key]))
            out[key] = v;
    }
    return out;
}
