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

import Models
import Storybook

import SortFilterProxyModel

import utils

import AppLayouts.Profile.views

Item {
    id: root

    AppearanceView {
        anchors.fill: parent
        anchors.topMargin: 80
        contentWidth: root.width

        theme: ThemeUtils.Style.System
        fontSize: ThemeUtils.FontSize.FontSizeM
        paddingFactor: ThemeUtils.PaddingFactor.PaddingM

        onThemeChangeRequested: theme => this.theme = theme
    }
}

// category: Settings
// status: good
