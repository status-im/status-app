import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal

import StatusQ.Core.Theme
import Storybook

// Dummy imports to satisfy androiddeployqt according to
// https://doc.qt.io/qt-6/android-deploy-qt-tool.html#dependencies-detection
import QtQuick.Dialogs
import QtMultimedia

ApplicationWindow {
    id: root

    width: 1450
    height: 840
    visible: true

    title: "%1 – %2".arg(storybook.currentPage).arg(Qt.application.displayName)

    // cf. Universal theme kept here as the basic light/dark theme for the app itself
    Universal.theme: storybook.darkMode ? Universal.Dark : Universal.Light
    font.pixelSize: 13

    Storybook {
        id: storybook

        anchors.fill: parent

        onCurrentPageItemChanged: {
            if (currentPageItem)
                overlay.setPage(currentPage, currentPageItem)
            else
                overlay.clear()
        }

        pageOverlay: PageOverlay {
            id: overlay
        }

        Component.onCompleted: {
            storybook.onCurrentPageItemChanged()
        }
    }
}
