import QtQuick

import StatusQ.Core

import utils

/// Offers to make Status the app that opens a file type while a Tab shows a file
/// of that type another app handed over. Only the user picks a default on
/// Android: the offer leads to the system's choice of app, or to the settings of
/// the app that has it. Elsewhere the platform says nothing and the offer never shows.
QtObject {
    id: root

    /// The current Tab's Opened File while the Tab shows it, else "".
    property string openedFile: ""
    /// The type the system was asked about in this run.
    property string askedType: ""
    /// The type Status became the app for after the offer, until the user acknowledges it.
    property string confirmedType: ""

    property var fileTypeFn: file => SystemUtils.openedFileInfo(file).mimeType ?? ""
    property var defaultViewerFn: type => SystemUtils.defaultViewer(type)
    property var offerFn: type => SystemUtils.offerDefaultViewer(type)
    /// Whether the user wants the offer; the host keeps it.
    property var suggestedFn: () => true
    property var dismissFn: () => {}

    /// What the platform last said about fileType: "self", "none", "other:<app name>" or "".
    property string defaultViewer: ""
    property bool suggested: true

    readonly property string fileType: openedFile ? String(fileTypeFn(openedFile) || "").toLowerCase() : ""
    /// How the offer names fileType; "" for a type Status does not claim.
    readonly property string typeName: DefaultViewerTypes.name(fileType)
    readonly property string otherApp: defaultViewer.startsWith("other:") ? defaultViewer.slice(6) : ""
    readonly property bool shown: typeName !== "" && suggested && askedType !== fileType
                                  && (defaultViewer === "none" || otherApp !== "")
    /// Status opens fileType now, after the user went through the offer.
    readonly property bool confirmed: confirmedType !== "" && confirmedType === fileType

    // Reads fileType, not typeName: it runs on fileTypeChanged, maybe before typeName follows.
    function refresh() {
        suggested = !!suggestedFn()
        const name = DefaultViewerTypes.name(fileType)
        const was = defaultViewer
        defaultViewer = name ? (defaultViewerFn(fileType) || "") : ""
        if (askedType && askedType === fileType && was !== "self" && defaultViewer === "self")
            confirmedType = fileType
    }

    function accept() {
        askedType = fileType
        offerFn(fileType)
    }

    function acknowledge() {
        confirmedType = ""
    }

    function dismiss() {
        suggested = false
        dismissFn()
    }

    onFileTypeChanged: refresh()
    Component.onCompleted: refresh()

    // The user comes back from the system screen or from the settings.
    readonly property Connections appState: Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive && root.typeName)
                root.refresh()
        }
    }
}
