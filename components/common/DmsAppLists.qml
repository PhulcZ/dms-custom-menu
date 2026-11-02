import QtQuick
import qs.Services

// DMS' category names and visible apps, fetched in a handler instead of a
// binding. AppSearchService.getAllCategories() and getVisibleApplications()
// fill DMS' own cache on their first call after a change; called inside a
// binding that reads and writes the same property (Qt warns of a binding
// loop). Bind to these lists instead.
QtObject {
    id: root

    property var categories: []
    property var visibleApps: []

    function refresh() {
        categories = AppSearchService.getAllCategories();
        visibleApps = AppSearchService.getVisibleApplications();
    }

    // Every reset of DMS' cache comes with one of these signals; later,
    // so DMS' own handlers have cleared the cache first
    readonly property Connections watch: Connections {
        target: AppSearchService
        function onCacheVersionChanged() {
            Qt.callLater(root.refresh);
        }
        function onApplicationsChanged() {
            Qt.callLater(root.refresh);
        }
        function on_CategoryMapChanged() {
            Qt.callLater(root.refresh);
        }
    }

    Component.onCompleted: refresh()
}
