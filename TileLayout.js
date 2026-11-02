.pragma library

// Placement of the tiles inside a tile element (pure functions, no QML):
// the grid (fixed cells, free ones stay free) and the row (buttons flow in
// their order). Positions in cells.

// Tile sizes in cells: small 1 × 1, large 2 × 2
var tileSizes = { "small": [1, 1], "large": [2, 2] };

// Tiles have fixed inner cells { app, size, col, row }; free cells stay
// free. Tiles without a position (older data) are packed first-fit.
function tileDims(tile, columns) {
    const size = tileSizes[tile.size] ?? tileSizes.small;
    const w = Math.min(size[0], columns);
    return { "w": w, "h": w === size[0] ? size[1] : w };
}

// → [{ tile, col, row, w, h }]: positioned tiles where they fit (inside
// the columns, not overlapping an earlier one), the rest first-fit
function packTiles(tiles, columns) {
    const used = [];
    const free = (c, r, w, h) => {
        if (c < 0 || r < 0 || c + w > columns)
            return false;
        for (let y = r; y < r + h; y++) {
            for (let x = c; x < c + w; x++) {
                if (used[y]?.[x])
                    return false;
            }
        }
        return true;
    };
    const take = (c, r, w, h) => {
        for (let y = r; y < r + h; y++) {
            used[y] = used[y] ?? [];
            for (let x = c; x < c + w; x++)
                used[y][x] = true;
        }
    };
    const out = new Array(tiles.length);
    const rest = [];
    tiles.forEach((t, i) => {
        const d = tileDims(t, columns);
        if (t.col !== undefined && t.row !== undefined && free(t.col, t.row, d.w, d.h)) {
            take(t.col, t.row, d.w, d.h);
            out[i] = { "tile": t, "col": t.col, "row": t.row, "w": d.w, "h": d.h };
        } else {
            rest.push(i);
        }
    });
    for (const i of rest) {
        const t = tiles[i], d = tileDims(t, columns);
        // Nearest free cell to the wanted one (or from the top left)
        const wc = t.col ?? 0, wr = t.row ?? 0;
        let best = null;
        for (let r = 0; r <= used.length + d.h && !(best && r > wr + best.dist); r++) {
            for (let c = 0; c + d.w <= columns; c++) {
                if (!free(c, r, d.w, d.h))
                    continue;
                const dist = t.col === undefined ? r * columns + c : Math.abs(r - wr) + Math.abs(c - wc);
                if (!best || dist < best.dist)
                    best = { "col": c, "row": r, "dist": dist };
            }
        }
        take(best.col, best.row, d.w, d.h);
        out[i] = { "tile": t, "col": best.col, "row": best.row, "w": d.w, "h": d.h };
    }
    return out;
}

// Button elements flow: tiles in their order row by row (first row
// full, then the next), stored positions are ignored. The width of the
// element sets the columns.
// Button elements flow: tiles in their order row by row (first row
// full, then the next), stored positions are ignored. The width of the
// element sets the columns. Positions in cells, fractional where a
// spacer (t.span, in cells: its px / cell step) shifts the rest: in a
// row it moves the following tiles right, in a single column it moves
// the following rows down.
function flowTiles(tiles, columns) {
    const eps = 1e-6;
    // Per row the occupied intervals [x0, x1) (large tiles take 2 rows)
    const blocked = [];
    const block = (r, x0, x1) => {
        blocked[r] = blocked[r] ?? [];
        blocked[r].push([x0, x1]);
    };
    // First free x >= x in rows r..r+h-1 for width w, or -1 (row full)
    const fit = (x, r, w, h) => {
        for (let guard = 0; guard < 64; guard++) {
            if (x + w > columns + eps)
                return -1;
            let moved = false;
            for (let y = r; y < r + h; y++) {
                for (const iv of blocked[y] ?? []) {
                    if (x < iv[1] - eps && x + w > iv[0] + eps) {
                        x = iv[1];
                        moved = true;
                    }
                }
            }
            if (!moved)
                return x;
        }
        return -1;
    };
    const vertical = columns <= 1;
    let x = 0, r = 0, shiftY = 0;
    return tiles.map(t => {
        if (t.span !== undefined) {
            const len = Math.max(0, t.span);
            const out = { "tile": t, "col": x, "row": r + shiftY, "w": 0, "h": 0, "spacer": true };
            if (vertical)
                shiftY += len;
            else
                x = Math.min(columns, x + len);
            return out;
        }
        const d = tileDims(t, columns);
        let at = fit(x, r, d.w, d.h);
        while (at < 0) {
            r++;
            x = 0;
            at = fit(x, r, d.w, d.h);
        }
        for (let y = r; y < r + d.h; y++)
            block(y, at, at + d.w);
        const out = { "tile": t, "col": at, "row": r + shiftY, "w": d.w, "h": d.h };
        x = at + d.w;
        return out;
    });
}
