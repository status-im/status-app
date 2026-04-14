import QtQuick
import QtQuick.Controls

import StatusQ.Popups.Dialog

import shared.views
import shared.controls

StatusDialog {
    id: root

    property var parentPopup

    property alias contactDetails: profileView.contactDetails

    property alias profileStore: profileView.profileStore
    property alias contactsStore: profileView.contactsStore
    property alias walletStore: profileView.walletStore
    property alias utilsStore: profileView.utilsStore
    property alias networksStore: profileView.networksStore

    property alias sendToAccountEnabled: profileView.sendToAccountEnabled

    property alias showcaseCommunitiesModel: profileView.showcaseCommunitiesModel
    property alias showcaseAccountsModel: profileView.showcaseAccountsModel
    property alias showcaseCollectiblesModel: profileView.showcaseCollectiblesModel
    property alias showcaseSocialLinksModel: profileView.showcaseSocialLinksModel
    property alias showcaseAssetsModel: profileView.showcaseAssetsModel

    property alias assetsModel: profileView.assetsModel
    property alias collectiblesModel: profileView.collectiblesModel

    // Triggered whenever an action inside this component causes a navigation away from it.
    // The following actions are considered::
    // ** Sending a message
    // ** Editing profile
    signal navigationRequested()

    implicitHeight: implicitContentHeight + (header.visible ? header.height : 0)
    width: 640
    padding: 0

    footer: null
    background: null
    header: Item {
        id: headerItem
        height: selector.height + 20
        visible: profileView.isCurrentUser

        TapHandler {
            enabled: root.closePolicy != Popup.NoAutoClose
            onTapped: {
                root.close()
            }   
        }
        ProfilePerspectiveSelector {
            id: selector
            showcaseVisibility: profileView.showcaseMaxVisibility
            onVisibilitySelected: (visibility) => profileView.showcaseMaxVisibility = visibility
        }
    }

    contentItem: ProfileDialogView {
        id: profileView

        onCloseRequested: root.close()
        onNavigationRequested: root.navigationRequested()
    }
}
