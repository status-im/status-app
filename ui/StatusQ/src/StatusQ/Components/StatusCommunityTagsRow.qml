import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls

StatusListView {
    id: root

    property string tags // JSON object (stringified) mapping tag names to emoji
    property var selectedTagsNames: []

    property color gradientColor: Theme.palette.statusAppLayout.backgroundColor
    property bool showIcon: true

    property bool clickable: true

    implicitHeight: 32 // by design, StatusCommunityTag height
    orientation: ListView.Horizontal
    spacing: Theme.halfPadding
    StatusScrollBar.horizontal.policy: StatusScrollBar.AlwaysOff

    onTagsChanged: {
        var obj = JSON.parse(tags);

        d.tagsModel.clear();
        for (const key of Object.keys(obj)) {
            d.tagsModel.append({ name: key, emoji: obj[key], selected: false });
        }

        d.evaluateSelectedTags()
    }

    QtObject {
        id: d

        property ListModel tagsModel: ListModel {}

        function evaluateSelectedTags() {
            let selectedTagsNames = []
            for(let i = 0; i < tagsModel.count; i++) {
                let tag = tagsModel.get(i)
                if (tag.selected) selectedTagsNames.push(tag.name)
            }
            root.selectedTagsNames = selectedTagsNames
        }
    }

    model: d.tagsModel
    delegate: StatusCommunityTag {
        height: ListView.view.height
        name: model.name
        emoji: model.emoji
        highlighted: model?.selected ?? false
        interactive: root.clickable
        onClicked: {
            model.selected = !model.selected
            d.evaluateSelectedTags()
        }
    }

    StatusNavigationButton {
        width: height
        anchors.left: parent.left
        height: parent.height
        visible: !root.atXBeginning
        gradientColor: root.gradientColor
        showIcon: root.showIcon
        onClicked: flick(root.width, 0)
    }

    StatusNavigationButton {
        width: height
        anchors.right: parent.right
        height: parent.height
        visible: !root.atXEnd
        gradientColor: root.gradientColor
        navigateForward: true
        showIcon: root.showIcon
        onClicked: flick(-root.width, 0)
    }
}
