.pragma library

// Fits the menu layout into the columns × rows grid, so no element ends up
// outside the menu (DMS' DEditableGrid has no row limit: dragging or
// being pushed by another element can move an element below the last row;
// a smaller menu raises the minimum rows of elements with a fixed pixel
// height).
//
// items: [{ id, col, row, w, h }]; minRows(id) → minimum height in rows;
// fixedRows(id) → exact height or 0 (the search element); yieldingId = the
// element that gives way first (apps: it scrolls anyway), handled last.
// firstId (optional) = id or list of ids placed first and kept (locked
// elements, the one just aligned).
// Elements that fit and do not overlap stay where they are. The others move
// to the nearest free spot, shrinking down to their minimum if needed.
// Returns { items, overflow }; overflow = an element found no free spot
// (menu too small for all elements); it is then kept at its clamped place.
function fit(items, columns, rows, minRows, fixedRows, yieldingId, firstId) {
    const occupied = [];
    for (let r = 0; r < rows; r++)
        occupied.push(new Array(columns).fill(false));

    function isFree(col, row, w, h) {
        if (col < 0 || row < 0 || col + w > columns || row + h > rows)
            return false;
        for (let r = row; r < row + h; r++) {
            for (let c = col; c < col + w; c++) {
                if (occupied[r][c])
                    return false;
            }
        }
        return true;
    }

    function occupy(col, row, w, h) {
        for (let r = Math.max(0, row); r < Math.min(rows, row + h); r++) {
            for (let c = Math.max(0, col); c < Math.min(columns, col + w); c++)
                occupied[r][c] = true;
        }
    }

    // Nearest free spot for a w × h element, measured from (col, row)
    function nearestFree(col, row, w, h) {
        let best = null;
        for (let r = 0; r + h <= rows; r++) {
            for (let c = 0; c + w <= columns; c++) {
                if (!isFree(c, r, w, h))
                    continue;
                const d = Math.abs(r - row) + Math.abs(c - col);
                if (!best || d < best.d)
                    best = { "col": c, "row": r, "d": d };
            }
        }
        return best;
    }

    // Largest free rectangle up to maxW × maxH (height at least minH)
    function largestFree(col, row, maxW, maxH, minH) {
        let best = null;
        for (let r = 0; r + minH <= rows; r++) {
            for (let c = 0; c < columns; c++) {
                if (occupied[r][c])
                    continue;
                // Grow the width; per width the free height is the minimum
                // of the free run below each column
                let height = maxH;
                for (let w = 1; w <= maxW && c + w <= columns; w++) {
                    let run = 0;
                    while (run < height && r + run < rows && !occupied[r + run][c + w - 1])
                        run++;
                    height = run;
                    if (height < minH)
                        break;
                    const area = w * height;
                    const d = Math.abs(r - row) + Math.abs(c - col);
                    if (!best || area > best.area || (area === best.area && d < best.d))
                        best = { "col": c, "row": r, "w": w, "h": height, "area": area, "d": d };
                }
            }
        }
        return best ? { "col": best.col, "row": best.row, "w": best.w, "h": best.h } : null;
    }

    // Same column and width, only shorter (at least minH rows): first the
    // bottom edge stays (an element above grew into it), then the top edge
    // stays (one below grew). Keeps the arrangement instead of moving the
    // element far away.
    function shrinkInPlace(col, row, w, h, minH) {
        for (let top = row + 1; top + minH <= row + h; top++) {
            if (isFree(col, top, w, row + h - top))
                return { "col": col, "row": top, "w": w, "h": row + h - top };
        }
        for (let height = h - 1; height >= minH; height--) {
            if (isFree(col, row, w, height))
                return { "col": col, "row": row, "w": w, "h": height };
        }
        return null;
    }

    // Size limits per element
    const sized = items.map(i => {
        const fixed = fixedRows(i.id);
        const minH = Math.min(rows, fixed > 0 ? fixed : Math.max(1, minRows(i.id)));
        const w = Math.max(1, Math.min(columns, i.w));
        const h = fixed > 0 ? minH : Math.max(minH, Math.min(rows, i.h));
        return { "item": i, "w": w, "h": h, "minH": minH };
    });

    const result = new Array(items.length);
    const pending = [];

    // 1. Elements that are inside and do not overlap keep their place
    //    (in reading order, so the upper of two overlapping ones wins;
    //    the yielding element last)
    // firstId: one id or a list (locked elements, the just aligned one)
    const firsts = Array.isArray(firstId) ? firstId : (firstId ? [firstId] : []);
    // Earlier in the list = placed earlier (locked ones before the aligned one)
    const yields = index => {
        const pos = firsts.indexOf(items[index].id);
        return pos >= 0 ? pos - firsts.length : items[index].id === yieldingId ? 1 : 0;
    };
    const order = sized.map((s, index) => index).sort((a, b) => (yields(a) - yields(b)) || (items[a].row - items[b].row) || (items[a].col - items[b].col));
    for (const index of order) {
        const s = sized[index];
        if (isFree(s.item.col, s.item.row, s.w, s.h)) {
            occupy(s.item.col, s.item.row, s.w, s.h);
            result[index] = { "id": s.item.id, "col": s.item.col, "row": s.item.row, "w": s.w, "h": s.h };
        } else {
            pending.push(index);
        }
    }

    // 2. The others: same size at the nearest free spot; otherwise the
    //    largest free rectangle (at most their size, at least minH rows),
    //    on a tie the nearest
    let overflow = false;
    for (const index of pending) {
        const s = sized[index];
        const col = Math.max(0, Math.min(columns - s.w, s.item.col));
        const row = Math.max(0, Math.min(rows - s.h, s.item.row));
        let placed = shrinkInPlace(col, row, s.w, s.h, s.minH);
        const spot = placed ? null : nearestFree(col, row, s.w, s.h);
        if (spot)
            placed = { "col": spot.col, "row": spot.row, "w": s.w, "h": s.h };
        if (!placed)
            placed = largestFree(col, row, s.w, s.h, s.minH);
        if (!placed) {
            overflow = true;
            placed = { "col": col, "row": Math.max(0, rows - s.minH), "w": s.w, "h": s.minH };
        }
        occupy(placed.col, placed.row, placed.w, placed.h);
        result[index] = Object.assign({ "id": s.item.id }, placed);
    }

    return { "items": result, "overflow": overflow };
}

// Width and height scaled apart (from = units of both axes)
function scaleLayoutXY(items, from, toCols, toRows) {
    if (!(from > 0) || !(toCols > 0) || !(toRows > 0))
        return items;
    const fx = toCols / from, fy = toRows / from;
    return items.map(i => {
        const col = Math.round(i.col * fx);
        const row = Math.round(i.row * fy);
        return {
            "id": i.id,
            "col": col,
            "row": row,
            "w": Math.max(1, Math.round((i.col + i.w) * fx) - col),
            "h": Math.max(1, Math.round((i.row + i.h) * fy) - row)
        };
    });
}

// Cells → stored units (thousandths of width and height)
function layoutToStore(items, columns, rows, n) {
    const fx = n / columns, fy = n / rows;
    return items.map(i => {
        const col = Math.round(i.col * fx), row = Math.round(i.row * fy);
        return { "id": i.id, "col": col, "row": row, "w": Math.round((i.col + i.w) * fx) - col, "h": Math.round((i.row + i.h) * fy) - row };
    });
}

// Largest free rectangle of the grid (by area; between equal ones the
// first from the top left), from the elements as shown:
// { col, row, w, h }, w = 0 if the grid is full
function largestFreeArea(items, cols, rows) {
    const used = [];
    for (let r = 0; r < rows; r++)
        used.push(new Array(cols).fill(false));
    for (const i of items) {
        for (let r = Math.max(0, i.row); r < Math.min(rows, i.row + i.h); r++)
            for (let c = Math.max(0, i.col); c < Math.min(cols, i.col + i.w); c++)
                used[r][c] = true;
    }
    // Per row the free height above each column, then the largest
    // rectangle in that histogram (stack)
    const height = new Array(cols).fill(0);
    let best = { "col": 0, "row": 0, "w": 0, "h": 0 };
    for (let r = 0; r < rows; r++) {
        for (let c = 0; c < cols; c++)
            height[c] = used[r][c] ? 0 : height[c] + 1;
        const stack = [];
        for (let c = 0; c <= cols; c++) {
            const hc = c < cols ? height[c] : 0;
            let start = c;
            while (stack.length > 0 && stack[stack.length - 1].h >= hc) {
                const top = stack.pop();
                const w = c - top.start;
                if (top.h * w > best.w * best.h)
                    best = { "col": top.start, "row": r - top.h + 1, "w": w, "h": top.h };
                start = top.start;
            }
            stack.push({ "start": start, "h": hc });
        }
    }
    return best;
}
