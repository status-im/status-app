import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ

import mainui
import shared.stores as SharedStores
import AppLayouts.stores as AppLayoutsStores
import AppLayouts.Communities.panels

import Storybook

SplitView {
    id: root
    SplitView.fillWidth: true

    Keychain {
        id: popupsKeychain
    }

    Popups {
        keychain: popupsKeychain
        popupParent: root
        sharedRootStore: SharedStores.RootStore {}
        rootStore: AppLayoutsStores.RootStore {}
        communityTokensStore: SharedStores.CommunityTokensStore {}
        networksStore: SharedStores.NetworksStore {}
    }

    EditSettingsPanel {
        id: panel
        SplitView.fillWidth: true
        SplitView.fillHeight: true
        name: communityEditor.name
        color: communityEditor.color
        logoImageData: communityEditor.image
        description: communityEditor.description
        bannerImageData: communityEditor.banner
    }

    ScrollView {
         SplitView.minimumWidth: 300
         SplitView.preferredWidth: 300

         CommunityInfoEditor {
             id: communityEditor
             anchors.fill: parent
             colorVisible: true
         }
     }
}

// category: Panels
// status: good
// https://www.figma.com/file/17fc13UBFvInrLgNUKJJg5/Kuba⎜Desktop?node-id=3132%3A383870&mode=dev
