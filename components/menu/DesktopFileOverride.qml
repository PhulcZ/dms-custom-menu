import QtQuick
import Quickshell
import Quickshell.Io

// App changes on Linux level: own start file with the same name in
// ~/.local/share/applications. Per the XDG specification it shadows the
// original and applies to every launcher, dock and xdg-open.
//
// Flow: find the original file in XDG_DATA_DIRS → take its text → replace
// Name/Icon/Comment/Exec in the [Desktop Entry] section (drop localized
// variants like Name[de]=, they would take precedence) → write. The file
// gets the marker X-CustomMenu-Override=true; "Reset" only deletes files
// marked like that (into the trash), hand-made files stay untouched.
Item {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string userDir: home + "/.local/share/applications"
    readonly property var dataDirs: (Quickshell.env("XDG_DATA_DIRS") || "/usr/local/share:/usr/share").split(":").filter(d => d)

    property string appId: ""
    readonly property string fileName: appId.endsWith(".desktop") ? appId : appId + ".desktop"
    readonly property string targetPath: userDir + "/" + fileName

    // State after load(): source text, whether a copy exists, whether it is ours
    property string sourceText: ""
    property bool hasUserFile: false
    property bool isOurOverride: false
    property bool ready: false

    signal saved
    signal failed(string reason)

    property var _candidates: []
    property int _index: 0

    function load(id) {
        appId = id || "";
        ready = false;
        sourceText = "";
        hasUserFile = false;
        isOurOverride = false;
        // Own copy first, then system
        _candidates = [targetPath].concat(dataDirs.map(d => d + "/applications/" + fileName));
        _index = 0;
        // Reset first: the same path again would not load a second time
        reader.path = "";
        Qt.callLater(() => reader.path = _candidates[0]);
    }

    FileView {
        id: reader
        printErrors: false
        onLoaded: {
            root.sourceText = text();
            root.hasUserFile = path === root.targetPath;
            root.isOurOverride = root.hasUserFile && /^X-CustomMenu-Override=true$/m.test(root.sourceText);
            root.ready = true;
        }
        onLoadFailed: {
            // Set the next candidate in the next tick; set directly in the
            // handler, FileView does not load again.
            if (++root._index < root._candidates.length)
                Qt.callLater(() => reader.path = root._candidates[root._index]);
            else
                root.ready = true; // no file found, save() creates a new one
        }
    }

    FileView {
        id: writer
        atomicWrites: true
        printErrors: true
        onSaved: root.saved()
        onSaveFailed: root.failed("write")
    }

    // edits: { name, icon, comment, exec, addCategory, removeCategories };
    // empty values leave the field as is. addCategory: a freedesktop
    // category appended to Categories= (kept if already there);
    // removeCategories: freedesktop categories taken out of it.
    function save(edits) {
        if (!appId)
            return;
        const lines = (sourceText || "[Desktop Entry]\nType=Application\n").split("\n");
        const replaced = {};
        const keyOf = { name: "Name", icon: "Icon", comment: "Comment", exec: "Exec" };
        const out = [];
        let inMain = false;
        for (const line of lines) {
            const section = line.match(/^\s*\[(.+)\]\s*$/);
            if (section) {
                if (inMain)
                    flushMissing(out, edits, keyOf, replaced);
                inMain = section[1] === "Desktop Entry";
                out.push(line);
                continue;
            }
            if (inMain) {
                const kv = line.match(/^([A-Za-z0-9-]+)(\[[^\]]+\])?\s*=/);
                if (kv) {
                    const field = Object.keys(keyOf).find(f => keyOf[f] === kv[1]);
                    if (field && (edits[field] || "").trim()) {
                        if (kv[2])
                            continue; // drop localized variant
                        out.push(kv[1] + "=" + edits[field].trim());
                        replaced[field] = true;
                        continue;
                    }
                    if (kv[1] === "X-CustomMenu-Override")
                        continue;
                    if (kv[1] === "Categories" && !kv[2] && (edits.addCategory || edits.removeCategories)) {
                        const drop = edits.removeCategories ?? [];
                        const cats = line.substring(line.indexOf("=") + 1).split(";").map(c => c.trim()).filter(c => c && drop.indexOf(c) < 0);
                        if (edits.addCategory && cats.indexOf(edits.addCategory) < 0)
                            cats.push(edits.addCategory);
                        out.push("Categories=" + cats.join(";") + ";");
                        replaced.addCategory = true;
                        continue;
                    }
                }
            }
            out.push(line);
        }
        if (inMain)
            flushMissing(out, edits, keyOf, replaced);

        // Marker right after the section header
        const head = out.findIndex(l => /^\s*\[Desktop Entry\]\s*$/.test(l));
        out.splice(head + 1, 0, "X-CustomMenu-Override=true");

        writer.path = targetPath;
        writer.setText(out.join("\n").replace(/\n*$/, "\n"));
    }

    function flushMissing(out, edits, keyOf, replaced) {
        // Append fields missing in the original at the end of the section
        let insertAt = out.length;
        while (insertAt > 0 && out[insertAt - 1].trim() === "")
            insertAt--;
        for (const field of Object.keys(keyOf)) {
            if (!replaced[field] && (edits[field] || "").trim()) {
                out.splice(insertAt++, 0, keyOf[field] + "=" + edits[field].trim());
                replaced[field] = true;
            }
        }
        if (edits.addCategory && !replaced.addCategory) {
            out.splice(insertAt++, 0, "Categories=" + edits.addCategory + ";");
            replaced.addCategory = true;
        }
    }

    // Only remove own copies, via DMS' trash, not permanently.
    function reset() {
        if (!isOurOverride)
            return false;
        Quickshell.execDetached(["dms", "trash", "put", targetPath]);
        return true;
    }
}
