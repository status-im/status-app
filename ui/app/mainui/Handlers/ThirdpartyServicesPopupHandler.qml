import QtQuick

import StatusQ.Core.Utils as SQUtils

QtObject {
    id: root

    required property var popupParent
    required property bool thirdPartyServicesEnabled

    signal toggleThirdpartyServicesEnabledRequested()
    signal openDiscussPageRequested()
    signal openThirdpartyServicesArticleRequested()

    function openPopup()
    {
        let thirdpartyServicesPopupInst = thirdpartyServicesPopup.createObject(popupParent)
        thirdpartyServicesPopupInst.open()
    }

    readonly property SQUtils.DeferredComponent thirdpartyServicesPopup: SQUtils.DeferredComponent {
        source: Qt.resolvedUrl("../../../imports/shared/popups/ThirdpartyServicesPopup.qml")
        properties: ({ thirdPartyServicesEnabled: Qt.binding(() => root.thirdPartyServicesEnabled) })
        onCreated: popup => {
            popup.toggleThirdpartyServicesEnabledRequested.connect(root.toggleThirdpartyServicesEnabledRequested)
            popup.openDiscussPageRequested.connect(root.openDiscussPageRequested)
            popup.openThirdpartyServicesArticleRequested.connect(root.openThirdpartyServicesArticleRequested)
        }
    }
}
