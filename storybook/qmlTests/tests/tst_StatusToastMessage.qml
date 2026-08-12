import QtQuick
import QtTest

import StatusQ.Components
import StatusQ.Core

Item {
    id: root
    width: 500
    height: 600

    ListModel {
        id: ephemeralModel
    }

    Component {
        id: toastStackComponent
        StatusListView {
            objectName: "ephemeralNotificationList"
            width: 374
            height: 500
            spacing: 8
            clip: false
            verticalLayoutDirection: ListView.BottomToTop
            model: ephemeralModel

            delegate: StatusToastMessage {
                objectName: "statusToastMessage"
                width: ListView.view.width
                primaryText: model.title
                secondaryText: model.subTitle
                image: model.image
                icon.name: model.icon
                iconColor: model.iconColor
                loading: model.loading
                type: model.ephNotifType
                linkUrl: model.url
                actionRequired: model.actionType !== 0
                duration: model.durationInMs
                onClose: ephemeralModel.remove(index)
            }
        }
    }

    Component {
        id: toastComponent
        StatusToastMessage {
            anchors.centerIn: parent
            primaryText: "Primary"
            secondaryText: "Secondary"
        }
    }

    function appendToast(props) {
        ephemeralModel.append(Object.assign({
                                                title: "",
                                                subTitle: "",
                                                image: "",
                                                icon: "",
                                                iconColor: "",
                                                loading: false,
                                                ephNotifType: StatusToastMessage.Type.Default,
                                                url: "",
                                                actionType: 0,
                                                durationInMs: 0
                                            }, props))
    }

    TestCase {
        name: "StatusToastMessage"
        when: windowShown

        function cleanup() {
            ephemeralModel.clear()
        }

        function test_defaultsAndTexts() {
            const toast = createTemporaryObject(toastComponent, root)
            verify(!!toast)
            compare(toast.primaryText, "Primary")
            compare(toast.secondaryText, "Secondary")
            compare(toast.type, StatusToastMessage.Type.Default)
            verify(toast.open)
            verify(!toast.loading)
            compare(toast.duration, 0)
        }

        function test_typesAndLoading() {
            const toast = createTemporaryObject(toastComponent, root)
            verify(!!toast)

            toast.type = StatusToastMessage.Type.Success
            compare(toast.type, StatusToastMessage.Type.Success)
            toast.type = StatusToastMessage.Type.Danger
            compare(toast.type, StatusToastMessage.Type.Danger)

            toast.loading = true
            verify(toast.loading)
        }

        function test_durationAutoDismiss() {
            const toast = createTemporaryObject(toastComponent, root, { duration: 100 })
            verify(!!toast)
            verify(toast.open)
            tryCompare(toast, "open", false, 2000)
        }

        function test_listScene_bindsModelAndStacks() {
            const stack = createTemporaryObject(toastStackComponent, root)
            verify(!!stack)
            compare(stack.verticalLayoutDirection, ListView.BottomToTop)

            appendToast({
                            title: "\"Acc1\" successfully added",
                            icon: "checkmark-circle",
                            ephNotifType: StatusToastMessage.Type.Success
                        })
            tryCompare(stack, "count", 1)
            waitForRendering(stack)
            compare(stack.itemAtIndex(0).primaryText, "\"Acc1\" successfully added")
            compare(stack.itemAtIndex(0).type, StatusToastMessage.Type.Success)

            appendToast({
                            title: "Alice was banned from MyCommunity",
                            ephNotifType: StatusToastMessage.Type.Success
                        })
            tryCompare(stack, "count", 2)
            waitForRendering(stack)
            compare(stack.itemAtIndex(0).primaryText, "\"Acc1\" successfully added")
            compare(stack.itemAtIndex(1).primaryText, "Alice was banned from MyCommunity")
        }

        function test_listScene_loadingAndLink() {
            const stack = createTemporaryObject(toastStackComponent, root)
            verify(!!stack)

            appendToast({
                            title: "Collectible is being minted...",
                            subTitle: "View on Etherscan",
                            url: "https://etherscan.io/tx/0xabc",
                            loading: true
                        })
            tryCompare(stack, "count", 1)
            waitForRendering(stack)

            const toast = stack.itemAtIndex(0)
            compare(toast.primaryText, "Collectible is being minted...")
            compare(toast.secondaryText, "View on Etherscan")
            compare(toast.linkUrl, "https://etherscan.io/tx/0xabc")
            verify(toast.loading)
        }

        function test_listScene_closeRemovesItem() {
            const stack = createTemporaryObject(toastStackComponent, root)
            verify(!!stack)

            appendToast({
                            title: "Contact removed",
                            ephNotifType: StatusToastMessage.Type.Success
                        })
            tryCompare(stack, "count", 1)
            waitForRendering(stack)

            stack.itemAtIndex(0).close()
            tryCompare(stack, "count", 0)
        }
    }
}
