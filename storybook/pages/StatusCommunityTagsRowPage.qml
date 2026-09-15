import QtQuick
import QtQuick.Controls

import StatusQ.Components

import Models
import Storybook

import utils

Item {
    id: root

    StatusCommunityTagsRow {
        id: tagsRow
        Tracer {}
        width: parent.width *.66
        anchors.centerIn: parent
        tags: ModelsData.communityTags
    }

    Label {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
        elide: Text.ElideRight
        text: "Selected: %1; count: %2".arg(JSON.stringify(tagsRow.selectedTagsNames)).arg(tagsRow.selectedTagsNames.length)
    }
}

// category: Controls
// status: good
