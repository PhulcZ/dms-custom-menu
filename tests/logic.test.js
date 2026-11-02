// Tests of the pure logic (no QML): node tests/logic.test.js
// Loads the .pragma libraries into a sandbox (the pragma line removed).
const fs = require("fs");
const path = require("path");
const vm = require("vm");
const assert = require("assert");

function load(file) {
    const ctx = {};
    vm.createContext(ctx);
    const src = fs.readFileSync(path.join(__dirname, "..", file), "utf8").replace(/^\.(pragma|import).*$/gm, "");
    vm.runInContext(src, ctx);
    return ctx;
}
const Tile = load("TileLayout.js");
const Fit = load("LayoutFit.js");
const Defaults = load("Defaults.js");
let passed = 0;
function test(name, fn) {
    fn();
    passed++;
    console.log("ok  " + name);
}
// Values from the sandbox are of another realm: compare as plain data
const plain = v => JSON.parse(JSON.stringify(v));
const pos = list => plain(list.map(p => [p.tile.app, p.col, p.row, p.w, p.h]));

test("grid: stored cells stay, a large tile takes 2 x 2", () => {
    const placed = Tile.packTiles([{ "app": "a", "size": "small", "col": 3, "row": 0 }, { "app": "b", "size": "large", "col": 0, "row": 0 }], 4);
    assert.deepStrictEqual(pos(placed), [["a", 3, 0, 1, 1], ["b", 0, 0, 2, 2]]);
});
test("grid: a taken cell sends the tile to the nearest free one", () => {
    const placed = Tile.packTiles([{ "app": "a", "size": "small", "col": 0, "row": 0 }, { "app": "b", "size": "small", "col": 0, "row": 0 }], 2);
    assert.deepStrictEqual(pos(placed), [["a", 0, 0, 1, 1], ["b", 1, 0, 1, 1]]);
});
test("grid: tiles without position are packed first-fit", () => {
    const placed = Tile.packTiles([{ "app": "a", "size": "small" }, { "app": "b", "size": "small" }, { "app": "c", "size": "small" }], 2);
    assert.deepStrictEqual(pos(placed), [["a", 0, 0, 1, 1], ["b", 1, 0, 1, 1], ["c", 0, 1, 1, 1]]);
});
test("grid: a large tile is cut to the columns", () => {
    const placed = Tile.packTiles([{ "app": "a", "size": "large" }], 1);
    assert.deepStrictEqual(pos(placed), [["a", 0, 0, 1, 1]]);
});
test("row: tiles flow in their order, wrapping after the columns", () => {
    const placed = Tile.flowTiles(["a", "b", "c"].map(app => ({ "app": app, "size": "small" })), 2);
    assert.deepStrictEqual(plain(placed.map(p => [p.tile.app, p.col, p.row])), [["a", 0, 0], ["b", 1, 0], ["c", 0, 1]]);
});
test("categories: stored by a key the language does not change", () => {
    const de = { "AudioVideo": "Medien", "Audio": "Medien", "Game": "Spiele" };
    const en = { "AudioVideo": "Media", "Audio": "Media", "Game": "Games" };
    assert.strictEqual(Defaults.dmsCategoryKey(de, "Medien"), "dms:AudioVideo");
    assert.strictEqual(Defaults.dmsCategoryKey(en, "Media"), "dms:AudioVideo");
    assert.strictEqual(Defaults.dmsCategoryName(en, "dms:Game"), "Games");
    assert.strictEqual(Defaults.dmsCategoryKey(en, "Spiele"), "Spiele");
    assert.strictEqual(Defaults.dmsCategoryName(en, "custom:favorites"), "custom:favorites");
});
test("fit: elements that fit keep their place", () => {
    const r = Fit.fit([{ "id": "a", "col": 0, "row": 0, "w": 2, "h": 2 }, { "id": "b", "col": 2, "row": 0, "w": 2, "h": 2 }], 4, 4, () => 1, () => 0, "", null);
    assert.strictEqual(r.overflow, false);
    assert.deepStrictEqual(plain(r.items.map(i => [i.id, i.col, i.row])), [["a", 0, 0], ["b", 2, 0]]);
});
test("fit: an overlapping element moves to a free spot", () => {
    const r = Fit.fit([{ "id": "a", "col": 0, "row": 0, "w": 2, "h": 2 }, { "id": "b", "col": 1, "row": 0, "w": 2, "h": 2 }], 4, 4, () => 1, () => 0, "", null);
    const b = r.items.find(i => i.id === "b");
    assert.ok(b.col >= 2 || b.row >= 2, "b no longer overlaps a");
});
test("fit: nothing ends up outside the grid", () => {
    const r = Fit.fit([{ "id": "a", "col": 5, "row": 5, "w": 3, "h": 3 }], 4, 4, () => 1, () => 0, "", null);
    const a = r.items[0];
    assert.ok(a.col + a.w <= 4 && a.row + a.h <= 4);
});
test("largest free area: the empty part of the grid", () => {
    assert.deepStrictEqual(JSON.parse(JSON.stringify(Fit.largestFreeArea([{ "col": 0, "row": 0, "w": 2, "h": 4 }], 6, 4))), { "col": 2, "row": 0, "w": 4, "h": 4 });
});
test("store and scale back: the same cells", () => {
    const items = [{ "id": "x", "col": 1, "row": 2, "w": 3, "h": 2 }];
    const stored = Fit.layoutToStore(items, 8, 8, 1000);
    assert.deepStrictEqual(JSON.parse(JSON.stringify(Fit.scaleLayoutXY(stored, 1000, 8, 8))), items);
});
test("scale: proportions kept on another grid", () => {
    const back = Fit.scaleLayoutXY([{ "id": "x", "col": 250, "row": 0, "w": 500, "h": 1000 }], 1000, 20, 10);
    assert.deepStrictEqual(JSON.parse(JSON.stringify(back)), [{ "id": "x", "col": 5, "row": 0, "w": 10, "h": 10 }]);
});
console.log(passed + " tests passed");
