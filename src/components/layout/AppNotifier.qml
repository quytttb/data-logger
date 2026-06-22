pragma Singleton
import QtQuick

QtObject {
    id: root

    property string toastSummary:  ""
    property string toastSemantic: "info"
    property bool   toastVisible:  false
    property int    toastDurationMs: 5000

    property string pendingCopyPath: ""
    property string pendingDetailText:  ""
    property string pendingDetailTitle: ""
    property bool suppressed: false

    function show(summary, semantic, options) {
        if (suppressed) return
        toastSummary   = summary  || ""
        toastSemantic  = semantic || "info"
        toastDurationMs = (options && options.durationMs > 0) ? options.durationMs : 5000
        pendingCopyPath = (options && options.copyPath) ? options.copyPath : ""
        pendingDetailText  = (options && options.detailText)  ? options.detailText  : ""
        pendingDetailTitle = (options && options.detailTitle) ? options.detailTitle : (summary || "")
        toastVisible = true
    }

    function dismiss() {
        toastVisible = false
    }

    function openDetail(title, body) {
        root.detailRequested(title || "", body || "")
    }

    signal detailRequested(string title, string body)
}
