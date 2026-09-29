import QtQuick
import QtTest

import StatusQ.Core.Theme

import utils
import mainui

Item {
    id: root
    width: 360
    height: 200

    Component {
        id: delegateComponent
        ShareDestinationDelegate {
            width: 343
            chatId: "0x04abc"
            name: "Darrell Steward"
            color: "#ff7d46"
            colorId: 1
            icon: ""
            emoji: ""
            chatType: Constants.chatType.oneToOne
            membersCount: 0
            onlineStatus: 1
            sectionName: "Chat"
        }
    }

    SignalSpy { id: toggledSpy; signalName: "toggled" }

    TestCase {
        name: "ShareDestinationDelegate"
        when: windowShown

        function init() { toggledSpy.clear() }

        function create(props = {}) {
            const item = createTemporaryObject(delegateComponent, root, props)
            toggledSpy.target = item
            waitForRendering(item)
            return item
        }

        function test_contactSubtitleIsElidedCompressedPubkeyWithOnlineDot() {
            const item = create()
            compare(item.subTitle, Utils.getElidedCompressedPk("0x04abc"))
            compare(item.statusListItemTitle.font.weight, Font.DemiBold)
            verify(item.statusListItemIcon.badge.visible)
            compare(item.statusListItemIcon.badge.color, Theme.palette.successColor1)
        }

        function test_groupSubtitleIsMembersCount() {
            const item = create({ chatType: Constants.chatType.privateGroupChat, membersCount: 25, name: "Travel Days" })
            compare(item.title, "Travel Days")
            compare(item.statusListItemTitle.font.weight, Font.DemiBold)
            compare(item.subTitle, qsTr("%n member(s)", "", 25))
            verify(!item.statusListItemIcon.badge.visible)
        }

        function test_communityChannelTitleHasHashAndSectionSubtitle() {
            const item = create({ chatType: Constants.chatType.communityChat, name: "pets", sectionName: "Status" })
            compare(item.title, "#pets")
            compare(item.statusListItemTitle.font.weight, Font.Normal)
            compare(item.subTitle, "Status")
        }

        function test_checkedDrivesCheckboxAndBackground() {
            const item = create({ checked: true })
            const checkBox = findChild(item, "shareDestinationCheckBox")
            verify(checkBox.checked)
            compare(item.bgColor, Theme.palette.primaryColor3)
        }

        function test_clickingRowOrCheckboxEmitsToggledOnce() {
            const item = create()
            mouseClick(item)
            compare(toggledSpy.count, 1)
            compare(toggledSpy.signalArguments[0][0], "0x04abc")
            const checkBox = findChild(item, "shareDestinationCheckBox")
            mouseClick(checkBox)
            compare(toggledSpy.count, 2)
            verify(!checkBox.checked)   // binding to `checked` survives the click
        }
    }
}
