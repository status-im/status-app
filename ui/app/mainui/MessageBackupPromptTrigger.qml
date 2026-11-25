import QtQml

import utils

QtObject {
    id: root

    required property QtObject settings
    required property bool sessionReady
    required property string sectionId
    required property int sectionType

    signal promptRequested()

    function recordSuccessfulContactRequest() {
        if (!root.sessionReady || root.settings.messageBackupContactRequestCompleted)
            return

        root.settings.messageBackupContactRequestCompleted = true
        root.promptRequested()
    }

    // The section ID and type can change in the same navigation update.
    onSectionIdChanged: Qt.callLater(d.recordVisit)
    onSectionTypeChanged: Qt.callLater(d.recordVisit)
    onSessionReadyChanged: Qt.callLater(d.recordVisit)
    Component.onCompleted: Qt.callLater(d.recordVisit)

    readonly property QtObject _d: QtObject {
        id: d

        readonly property int visitThreshold: 3
        property string lastSectionId

        function recordVisit() {
            if (!root.sessionReady || !root.sectionId || root.sectionId === lastSectionId)
                return

            lastSectionId = root.sectionId
            if (root.sectionType !== Constants.appSection.chat &&
                    root.sectionType !== Constants.appSection.community)
                return

            if (root.settings.messageBackupVisitCount < visitThreshold)
                ++root.settings.messageBackupVisitCount
            if (root.settings.messageBackupVisitCount >= visitThreshold)
                root.promptRequested()
        }
    }
}
