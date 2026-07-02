import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme

import AppLayouts.Profile.views

Item {
    id: root

    AppearanceView {
        anchors.fill: parent
        anchors.topMargin: 80
        contentWidth: Math.min(650, root.width)

        theme: ThemeUtils.Style.System
        onThemeChangeRequested: function(theme) {
            console.info("AppearanceView.onThemeChangeRequested:", theme)
            this.theme = theme
        }

        onRestartRequested: console.info("AppearanceView.onRestartRequested")
    }
}

// category: Settings
// status: good
