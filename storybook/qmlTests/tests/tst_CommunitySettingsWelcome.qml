import QtQuick
import QtTest

import AppLayouts.Communities.panels
import AppLayouts.Communities.views

/*
    Empty community settings screens: airdrops, tokens and permissions.
    The copy and the disabled mint/airdrop actions live in the panels, so
    they do not need a community created in the running app.
*/
Item {
    id: root

    width: 800
    height: 900

    function findByTypePrefix(item, prefix) {
        if (!item)
            return null
        if (item.toString().indexOf(prefix) === 0)
            return item
        const list = item.children
        for (let i = 0; i < list.length; ++i) {
            const found = findByTypePrefix(list[i], prefix)
            if (found)
                return found
        }
        return null
    }

    readonly property QtObject communityDetails: QtObject {
        readonly property string id: "test-community"
        readonly property string name: "Test Community"
        readonly property string image: ""
        readonly property string color: "red"
        readonly property bool owner: true
        readonly property bool admin: false
        readonly property bool tokenMaster: false
    }

    Component {
        id: airdropsComponent

        AirdropsSettingsPanel {
            width: root.width
            height: root.height

            communityDetails: root.communityDetails
            isOwner: true
            isTokenMasterOwner: false
            isAdmin: false
            isOwnerTokenDeployed: false
            isTMasterTokenDeployed: false
            assetsModel: ListModel {}
            collectiblesModel: ListModel {}
            membersModel: ListModel {}
            accountsModel: ListModel {}
            enabledChainIds: "1"
        }
    }

    Component {
        id: tokensComponent

        MintTokensSettingsPanel {
            width: root.width
            height: root.height

            communityId: root.communityDetails.id
            communityName: root.communityDetails.name
            communityLogo: ""
            communityColor: root.communityDetails.color
            isOwner: true
            isTokenMasterOwner: false
            isAdmin: false
            isOwnerTokenDeployed: false
            isTMasterTokenDeployed: false
            tokensModel: ListModel {}
            referenceTokenGroupsModel: ListModel {}
            enabledChainIds: "1"
        }
    }

    Component {
        id: permissionsComponent

        PermissionsSettingsPanel {
            width: root.width
            height: root.height

            permissionsModel: ListModel {}
            assetsModel: ListModel {}
            collectiblesModel: ListModel {}
            channelsModel: ListModel {}
            communityDetails: root.communityDetails
        }
    }

    TestCase {
        name: "CommunitySettingsWelcome"
        when: windowShown

        function verifyChecklist(panel, lines) {
            const checklist = findChild(panel, "checkListItem")
            verify(!!checklist)
            compare(checklist.count, lines.length)
            for (let i = 0; i < lines.length; ++i) {
                const line = findChild(panel, "checkListText_" + i)
                verify(!!line, "checklist line " + i + " is missing")
                compare(line.text, lines[i])
            }
        }

        function verifyIntro(panel, title, subtitle, lines) {
            const titleItem = findChild(panel, "welcomeSettingsTitle")
            const subtitleItem = findChild(panel, "welcomeSettingsSubtitle")
            verify(!!titleItem)
            verify(!!subtitleItem)
            compare(titleItem.text, title)
            compare(subtitleItem.text, subtitle)
            verifyChecklist(panel, lines)
        }

        function verifyWelcomeImage(panel, assetName) {
            const image = findChild(panel, "welcomeSettingsImage")
            verify(!!image, "welcome image is missing")
            verify(String(image.source).indexOf(assetName) !== -1,
                   "welcome image " + image.source + " does not contain " + assetName)
        }

        function verifyMintOwnerInfoBox(panel) {
            const infoBox = root.findByTypePrefix(panel, "StatusInfoBox")
            verify(!!infoBox)
            compare(infoBox.title, qsTr("Get started"))
            compare(infoBox.text, qsTr("In order to Mint, Import and Airdrop community tokens, you first need to mint your Owner token which will give you permissions to access the token management features for your community."))
            compare(infoBox.buttonText, qsTr("Mint Owner token"))
            compare(infoBox.buttonVisible, true)
        }

        function test_welcomeScreen_data() {
            return [
                {
                    tag: "airdrops",
                    component: airdropsComponent,
                    imageAsset: "airdrops8_1",
                    title: qsTr("Airdrop community tokens"),
                    subtitle: qsTr("You can mint custom tokens and collectibles for your community"),
                    checklist: [
                        qsTr("Reward individual members with custom tokens for their contribution"),
                        qsTr("Incentivise joining, retention, moderation and desired behaviour"),
                        qsTr("Require holding a token or NFT to obtain exclusive membership rights")
                    ],
                    newButtonText: qsTr("New Airdrop"),
                    newButtonInteractive: false,
                    expectInfoBox: true
                },
                {
                    tag: "tokens",
                    component: tokensComponent,
                    imageAsset: "mint2_1",
                    title: qsTr("Community tokens"),
                    subtitle: qsTr("You can mint custom tokens and import tokens for your community"),
                    checklist: [
                        qsTr("Create remotely destructible soulbound tokens for admin permissions"),
                        qsTr("Reward individual members with custom tokens for their contribution"),
                        qsTr("Mint tokens for use with community and channel permissions")
                    ],
                    newButtonText: qsTr("Mint token"),
                    newButtonInteractive: false,
                    expectInfoBox: true
                },
                {
                    tag: "permissions",
                    component: permissionsComponent,
                    imageAsset: "permissions2_3",
                    title: qsTr("Permissions"),
                    subtitle: qsTr("You can manage your community by creating and issuing membership and access permissions"),
                    checklist: [
                        qsTr("Give individual members access to private channels"),
                        qsTr("Monetise your community with subscriptions and fees"),
                        qsTr("Require holding a token or NFT to obtain exclusive membership rights")
                    ],
                    newButtonText: qsTr("Add new permission"),
                    newButtonInteractive: undefined,
                    expectInfoBox: false
                }
            ]
        }

        function test_welcomeScreen(data) {
            const panel = createTemporaryObject(data.component, root)
            verify(!!panel)
            waitForRendering(panel)

            verifyWelcomeImage(panel, data.imageAsset)
            verifyIntro(panel, data.title, data.subtitle, data.checklist)

            if (data.expectInfoBox)
                verifyMintOwnerInfoBox(panel)

            const newItem = findChild(panel, "addNewItemButton")
            verify(!!newItem)
            compare(newItem.text, data.newButtonText)
            if (data.newButtonInteractive !== undefined)
                compare(newItem.interactive, data.newButtonInteractive)
        }
    }
}
