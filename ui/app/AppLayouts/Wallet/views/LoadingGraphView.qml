import QtQuick
import QtQuick.Controls

import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Core
import StatusQ.Controls

import utils
import shared.views
import shared.controls

import "../stores"

Loader {
    id: root
    active: false
    sourceComponent: Item {
        Image {
            id: graphMask
            anchors.fill: parent
            source: Assets.svg("mask/dummyLineGraph")
            sourceSize: Qt.size(parent.width, parent.height)
            smooth: true
            visible: false
            cache: false
        }

        // the loading shimmer, drawn where the graph's outline is opaque
        LoadingSkeletonTile {
            anchors.fill: parent
            mask: graphMask
        }
    }
}
