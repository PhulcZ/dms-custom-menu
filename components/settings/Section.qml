import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets

// Title colour by level: top level primary (DMS' own), second level
// secondary, deeper tertiary. A level is a section above, or a block
// marked countsAsLevel (the instance block). DMS' SettingsCard has no
// property for it (the label colour is fixed), so the title text is
// looked up once built; if DMS changes that, all titles stay primary.
SettingsCard {
    id: section
    // The settings page (CustomMenuSettings): found up the parents, also
    // when built later inside a section's lazy body
    property Item settings: null
    function findSettings() {
        for (let p = parent; p; p = p.parent) {
            if (p.loadValue !== undefined && p.saveValue !== undefined && p.sectionExpanded !== undefined)
                return p;
        }
        return null;
    }
    onParentChanged: if (!settings) settings = findSettings()
    property string key: ""
    readonly property bool isCustomMenuSection: true
    property bool nested: false
    property int level: 0
    width: parent ? parent.width : 0
    collapsible: true
    expanded: settings ? settings.sectionExpanded(key) : false
    onExpandedChanged: {
        if (settings)
            settings.setSectionExpanded(key, expanded);
        if (expanded)
            ensureBody();
    }

    // The content, built only when the section is first expanded (or a
    // jump needs it, settings.loadAllBodies): a closed section costs almost
    // nothing, so the page opens and switches instances fast. Built
    // into a holder, its items then move next to bodyAnchor into DMS'
    // group, so each keeps its own row as before.
    property Component body: null
    property var bodyObject: null
    function ensureBody() {
        if (bodyObject || !body)
            return;
        const holder = body.createObject(bodyAnchor);
        const items = [];
        for (let i = 0; i < holder.children.length; i++)
            items.push(holder.children[i]);
        for (const item of items)
            item.parent = bodyAnchor.parent;
        bodyObject = holder;
    }
    Connections {
        target: section.settings
        ignoreUnknownSignals: true
        function onLoadAllBodiesChanged() {
            if (section.settings?.loadAllBodies)
                section.ensureBody();
        }
    }
    Item {
        id: bodyAnchor
        visible: false
        width: 0
        height: 0
    }

    function findTitle(item) {
        for (const child of item.children) {
            if (child.text === section.title && child.color !== undefined && child.font !== undefined)
                return child;
            // Depth-first: the header label comes before the content
            const found = findTitle(child);
            if (found)
                return found;
        }
        return null;
    }
    Component.onCompleted: Qt.callLater(() => {
        if (!section.settings)
            section.settings = section.findSettings();
        if (section.expanded || section.settings?.loadAllBodies)
            section.ensureBody();
        if (section.settings)
            section.settings.sectionItems[section.key] = section;
        let level = 0;
        for (let p = section.parent; p; p = p.parent) {
            if (p.isCustomMenuSection || p.countsAsLevel === true)
                level++;
        }
        section.level = level;
        section.nested = level > 0;
        const label = findTitle(section);
        // DMS' keyboard focus ring on the title: DMS sometimes hands the
        // focus to the first title when the page opens, which then shows
        // as a framed, highlighted bar. Off for these titles.
        for (const c of label?.parent?.children ?? []) {
            if (c.pointerFocused !== undefined && c.parentFocused !== undefined)
                c.visible = false;
        }
        if (label && section.nested)
            label.color = Qt.binding(() => section.level === 1 ? Theme.secondary : Theme.tertiary);
    })
}
