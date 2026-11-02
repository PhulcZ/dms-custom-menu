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
import "../../Defaults.js" as Defaults
import "../common"

// ── Category editor (element pen of the categories element) ──
// Like the buttons editor: one row per category in its order
// (drag handle), icon (picker), name (own ones editable), start
// category, show/hide, delete. "All" and "Hidden" can be moved
// and hidden, not deleted.
Item {
    id: categoriesEditor
    // The menu widget (CustomMenuWidget): its settings and functions
    required property Item menu

    visible: menu.editingCategories
    anchors.fill: parent
    anchors.margins: menu.cardPadding
    property string pickingKey: ""

    Column {
        id: catEditorHead
        visible: categoriesEditor.pickingKey === ""
        width: parent.width
        spacing: Theme.spacingS

        Item {
            width: parent.width
            height: catDoneButton.height
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.trFor("customMenu", "Edit categories")
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Theme.fontWeightMedium
                color: menu.appTextColor
            }
            DButton {
                id: catDoneButton
                anchors.right: parent.right
                iconName: "check"
                text: I18n.trFor("customMenu", "Done")
                onClicked: menu.editingCategories = false
            }
        }
        Flow {
            width: parent.width
            spacing: Theme.spacingXS
            DButton {
                iconName: "add"
                text: I18n.trFor("customMenu", "New category")
                onClicked: menu.addCustomCategory()
            }
            DButton {
                visible: menu.deletedCategories.length > 0
                iconName: "restore"
                text: I18n.trFor("customMenu", "Restore deleted DMS categories")
                onClicked: menu.restoreDeletedCategories()
            }
        }
    }

    DFlickable {
        id: catFlickEdit
        fadeEdges: false
        EdgeFade {
            menu: categoriesEditor.menu
            parent: catFlickEdit.parent
            target: catFlickEdit
        }
        visible: categoriesEditor.pickingKey === ""
        anchors.top: catEditorHead.bottom
        anchors.topMargin: Theme.spacingXL
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        contentWidth: width
        contentHeight: catList.implicitHeight + Theme.spacingXL

        // Same columns in every row: handle, icon, name (at most
        // 280 px), start, show/hide, delete, new sub-category
        readonly property real btn: 40
        readonly property real gap: Theme.spacingS
        readonly property real labelW: Math.max(120, Math.min(280, width - 6 * btn - 6 * gap))
        readonly property real rowWidth: 6 * btn + labelW + 6 * gap

        Column {
            id: catList
            x: Math.max(0, (parent.width - width) / 2)
            width: Math.min(catFlickEdit.width, catFlickEdit.rowWidth)
            spacing: Theme.spacingXS

            Repeater {
                id: catRepeater
                model: menu.categoryEntries

                // One block per category: its row, below it its sub-
                // categories (dragging the handle moves the block)
                Column {
                    id: catBlock
                    required property var modelData
                    required property int index
                    width: catList.width
                    spacing: Theme.spacingXS
                    // Sub-categories and the "other apps" entry, in their order
                    readonly property var subs: menu.subOrder(modelData.key)

                Row {
                    id: catRow
                    readonly property var modelData: catBlock.modelData
                    readonly property int index: catBlock.index
                    readonly property string key: modelData.key
                    readonly property bool own: modelData.kind === "custom"
                    readonly property bool isStart: menu.startCategory === key
                    width: catList.width
                    spacing: catFlickEdit.gap
                    opacity: modelData.hidden ? 0.5 : 1

                    ReorderHandle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: catFlickEdit.btn
                        row: catBlock
                        index: catBlock.index
                        repeater: catRepeater
                        iconColor: menu.appTextColor
                        onMoveRequested: (from, to) => menu.moveCategoryTo(from, to)
                    }
                    // Icon (as on the chips): opens the icon picker
                    DActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        buttonSize: catFlickEdit.btn
                        // The category's own icon is drawn on top (FlexIcon)
                        iconName: ""
                        tooltipText: I18n.trFor("customMenu", "Choose icon")
                        onClicked: categoriesEditor.pickingKey = catRow.key
                        FlexIcon {
                            anchors.centerIn: parent
                            icon: (menu.cfg.catIcons ?? {})[catRow.key] || catRow.modelData.icon
                            size: Theme.iconSize
                            color: menu.appTextColor
                        }
                    }
                    // Name: own categories editable, the others as text
                    // where the field texts start
                    DTextField {
                        visible: catRow.own
                        anchors.verticalCenter: parent.verticalCenter
                        width: catFlickEdit.labelW
                        height: 36
                        text: catRow.modelData.text
                        placeholderText: I18n.trFor("customMenu", "Name")
                        placeholderColor: Theme.withAlpha(menu.appTextColor, 0.5)
                        onEditingFinished: menu.renameCustomCategory(catRow.key.slice(7), text)
                    }
                    Item {
                        visible: !catRow.own
                        width: catFlickEdit.labelW
                        height: 36
                        anchors.verticalCenter: parent.verticalCenter
                        StyledText {
                            x: Theme.spacingM
                            width: parent.width - Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            text: catRow.modelData.text
                            elide: Text.ElideRight
                            font.pixelSize: Theme.fontSizeMedium
                            color: menu.appTextColor
                        }
                    }
                    // Selected when the menu opens
                    DActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        buttonSize: catFlickEdit.btn
                        iconName: catRow.isStart ? "radio_button_checked" : "radio_button_unchecked"
                        iconColor: catRow.isStart ? Theme.primary : menu.appTextColor
                        tooltipText: catRow.isStart ? I18n.trFor("customMenu", "Selected when the menu opens") : I18n.trFor("customMenu", "Select when the menu opens")
                        onClicked: menu.saveKey("startCategory", catRow.key)
                    }
                    DActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        buttonSize: catFlickEdit.btn
                        iconName: catRow.modelData.hidden ? "visibility_off" : "visibility"
                        iconColor: menu.appTextColor
                        tooltipText: catRow.modelData.hidden ? I18n.trFor("customMenu", "Show again") : I18n.trFor("customMenu", "Hide")
                        onClicked: menu.setCategoryHidden(catRow.key, !catRow.modelData.hidden)
                    }
                    DActionButton {
                        visible: catRow.modelData.kind === "dms" || catRow.own
                        anchors.verticalCenter: parent.verticalCenter
                        buttonSize: catFlickEdit.btn
                        iconName: "delete"
                        iconColor: menu.appTextColor
                        tooltipText: I18n.trFor("customMenu", "Delete category")
                        onClicked: menu.deleteCategory(catRow.modelData)
                    }
                    Item {
                        visible: !(catRow.modelData.kind === "dms" || catRow.own)
                        width: catFlickEdit.btn
                        height: 1
                    }
                    // New sub-category in this category
                    DActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        buttonSize: catFlickEdit.btn
                        iconName: "subdirectory_arrow_right"
                        iconColor: menu.appTextColor
                        tooltipText: I18n.trFor("customMenu", "New subcategory")
                        onClicked: menu.addSubcategory(catRow.key)
                    }
                }

                // Sub-categories: indented, own order (handle), name, delete.
                // The Item keeps the handle's drop line out of the Column.
                Item {
                    visible: catBlock.subs.length > 0
                    width: catBlock.width
                    height: subColumn.implicitHeight
                    Column {
                        id: subColumn
                        width: parent.width
                        spacing: Theme.spacingXS
                        Repeater {
                            id: subRepeater
                            model: catBlock.subs
                            Row {
                                id: subRow
                                required property var modelData
                                required property int index
                                width: subColumn.width
                                spacing: catFlickEdit.gap
                                // Indent: below the category's icon
                                Item {
                                    width: catFlickEdit.btn
                                    height: 1
                                }
                                ReorderHandle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: catFlickEdit.btn
                                    row: subRow
                                    index: subRow.index
                                    repeater: subRepeater
                                    iconColor: menu.appTextColor
                                    onMoveRequested: (from, to) => menu.moveSubcategoryTo(catBlock.modelData.key, from, to)
                                }
                                // The rest: a fixed name (where the field texts start)
                                Item {
                                    visible: subRow.modelData.id === "__rest"
                                    width: catFlickEdit.labelW
                                    height: 36
                                    anchors.verticalCenter: parent.verticalCenter
                                    StyledText {
                                        x: Theme.spacingM
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: I18n.trFor("customMenu", "Other apps")
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.italic: true
                                        color: Theme.withAlpha(menu.appTextColor, 0.7)
                                    }
                                }
                                DTextField {
                                    visible: subRow.modelData.id !== "__rest"
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: catFlickEdit.labelW
                                    height: 36
                                    text: subRow.modelData.name
                                    placeholderText: I18n.trFor("customMenu", "Name")
                                    placeholderColor: Theme.withAlpha(menu.appTextColor, 0.5)
                                    onEditingFinished: menu.renameSubcategory(catBlock.modelData.key, subRow.modelData.id, text)
                                }
                                // Columns of start and show/hide stay free
                                Item {
                                    width: catFlickEdit.btn * 2 + catFlickEdit.gap
                                    height: 1
                                }
                                DActionButton {
                                    visible: subRow.modelData.id !== "__rest"
                                    anchors.verticalCenter: parent.verticalCenter
                                    buttonSize: catFlickEdit.btn
                                    iconName: "delete"
                                    iconColor: menu.appTextColor
                                    tooltipText: I18n.trFor("customMenu", "Delete subcategory")
                                    onClicked: menu.deleteSubcategory(catBlock.modelData.key, subRow.modelData.id)
                                }
                            }
                        }
                    }
                }
                }
            }

            StyledText {
                width: catList.width
                topPadding: Theme.spacingM
                wrapMode: Text.WordWrap
                text: I18n.trFor("customMenu", "Drag to change the order. The filled circle marks the category shown when the menu opens. Hidden categories stay in this list; deleted DMS categories can be restored. Custom categories exist only in CustomMenu; add apps by drag and drop. Subcategories (arrow button) appear as sections with headings within their category; drag apps into them in the menu.")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.withAlpha(menu.appTextColor, 0.6)
            }
        }
    }

    IconPicker {
        visible: categoriesEditor.pickingKey !== ""
        // Category icons are drawn by FlexIcon: logos work
        allowLogos: true
        anchors.fill: parent
        currentIcon: (menu.cfg.catIcons ?? {})[categoriesEditor.pickingKey] || ""
        favorites: [menu.cfg.iconFavorite1 ?? "", menu.cfg.iconFavorite2 ?? "", menu.cfg.iconFavorite3 ?? ""]
        suggestions: Defaults.iconSuggestions.category
        textColor: menu.appTextColor
        onPicked: path => {
            menu.setCategoryIcon(categoriesEditor.pickingKey, path);
            categoriesEditor.pickingKey = "";
        }
        onCancelled: categoriesEditor.pickingKey = ""
    }
}
