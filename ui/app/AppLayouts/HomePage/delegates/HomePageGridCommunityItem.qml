import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core.Theme

import utils
import shared.controls

HomePageGridItem {
    id: root

    property int membersCount
    property int activeMembersCount
    property bool pending
    property bool banned

    sectionType: Constants.appSection.community

    function numberFormat(number) {
        let res = number
        const million = 1000000
        const ks = 1000
        if(number > million) {
            res = number / million
            res = Number(number / million).toLocaleString(root.locale, 'f', 1) + 'M'
        }
        else if(number > ks) {
            res = number / ks
            res = Number(number / ks).toLocaleString(root.locale, 'f', 1) + 'K'
        }
        else
            res = Number(number).toLocaleString(root.locale, 'f', 0)
        return res
    }

    bottomRowComponent: Loader {
        sourceComponent: {
            if (root.banned)
                return bannedTagComponent
            if (root.pending)
                return pendingTagComponent
            return membersComponent
        }
    }

    iconLoaderComponent: StatusSmartIdenticon {
        asset.width: root.icon.width
        asset.height: root.icon.height
        asset.letterSize: Theme.secondaryAdditionalTextSize
        name: root.title
        asset.name: root.icon.source
        asset.color: root.color
    }

    component CustomInfoTag: InformationTag {
        height: Theme.bigPadding
        spacing: 4
        horizontalPadding: 6
        verticalPadding: 2
        bgRadius: 20
        bgBorderColor: Theme.palette.directColor6
        tagPrimaryLabel.font.pixelSize: Theme.fontSize(11)
        tagPrimaryLabel.font.weight: Font.Medium
        asset.color: Theme.palette.baseColor1
    }

    Component {
        id: membersComponent
        CustomInfoTag {
            asset.name: root.activeMembersCount ? "tiny/flash" : "tiny/members"
            tagPrimaryLabel.text: root.numberFormat(root.activeMembersCount ? root.activeMembersCount : root.membersCount)
        }
    }

    Component {
        id: pendingTagComponent
        CustomInfoTag {
            asset.name: "history" // TODO correct new "pending" icon
            tagPrimaryLabel.text: qsTr("Pending")
        }
    }

    Component {
        id: bannedTagComponent
        ErrorTag {
            height: Theme.bigPadding
            spacing: 4
            leftPadding: 4
            verticalPadding: 4
            bgRadius: 20
            tagPrimaryLabel.text: qsTr("Banned")
            tagPrimaryLabel.font.pixelSize: Theme.fontSize(11)
            tagPrimaryLabel.font.weight: Font.Medium
        }
    }
}
