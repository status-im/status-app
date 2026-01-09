import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Layouts
import QtQml.Models
import QtQml

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme

Dialog {
    id: root

    property string subtitle

    /*!
       \qmlproperty bool destroyOnClose
        This property decides whether the popup component should be destroyed when closed. Default value is false.
    */
    property bool destroyOnClose: false

    /*!
       \qmlproperty color backgroundColor
        This property decides the modal background color
    */
    property color backgroundColor: contentItem.Theme.palette.statusModal.backgroundColor

    /*!
       \qmlproperty var closeHandler
        This property decides the action to be performed when the close button is clicked. It allows to define
        a custom function to be called when the popup is closed by the user.
    */
    property var closeHandler: root.close

    /*!
       \qmlproperty string okButtonText
        This property decides what text to use for an "OK" button
    */
    property string okButtonText: qsTr("OK")

    readonly property bool bottomSheet: d.windowHeight > d.windowWidth
                                        && d.windowWidth <= ThemeUtils.portraitBreakpoint.width // The max width of a phone in portrait mode

    readonly property real desiredY: root.bottomSheet ? d.windowHeight - root.height
                                                      : (root.Overlay.overlay.height - root.height) / 2

    /*!
       \qmlproperty bool fillHeightOnBottomSheet
        This property decides the height of the dialog when `bottomSheet` is active:
          * If active: it fills the 90% of the screen viewport.
          * If not active: the height is the minimum value between the implicitHeight and the 90% of the screen viewport.
    */
    property bool fillHeightOnBottomSheet: false

    /*!
       \qmlproperty bool fullScreen
        This property decides whether the dialog should take the full screen size.
    */
    property bool fullScreenSheet: false

    QtObject {
        id: d

        // NB: needs to be delayed for the `contentItem` to be not null
        property int windowWidth
        property int windowHeight

        readonly property real bottomSheetHeightRatio: 0.90
    }

    onAboutToShow: {
        d.windowWidth = Qt.binding(() => root.contentItem.Window ? root.contentItem.Window.width: Screen.width)
        d.windowHeight = Qt.binding(() => root.contentItem.Window? root.contentItem.Window.height : Screen.height)
    }

    // For some reason the default exit transition will not work properly
    // when the dialog is closed and using safe areas, so we define our own
    // Test Android if you want to change this
    exit: Transition {
        id: exitTransition
        NumberAnimation {
            property: "opacity"; from: 1; to: 0
            duration: ThemeUtils.AnimationDuration.Fast
            easing.type: Easing.OutQuint
        }
        NumberAnimation {
            property: "y"; from: root.y; to: root.parent.height
            duration: ThemeUtils.AnimationDuration.Fast
            easing.type: Easing.OutCubic
        }
    }

    enter: Transition {
        id: enterTransition
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: ThemeUtils.AnimationDuration.Fast
            }
            NumberAnimation {
                property: "y"
                from: root.parent.height
                to: root.desiredY
                duration: ThemeUtils.AnimationDuration.Fast
                easing.type: Easing.OutCubic
            }
        }
    }

    enabled: opened

    // Binding positioning the content when there's no footer
    Binding on bottomPadding {
        when: root.bottomSheet && !enterTransition.running && (!footer || footer.height === 0 || !footer.visible)
        value: padding + root.parent.SafeArea.margins.bottom
    }
    Binding on width {
        when: root.bottomSheet
        value: d.windowWidth
    }
    Binding on height {
        when: root.bottomSheet && !enterTransition.running && !root.fullScreenSheet
        value: root.fillHeightOnBottomSheet ? d.windowHeight * d.bottomSheetHeightRatio : Math.min(implicitHeight, d.windowHeight * d.bottomSheetHeightRatio)

    }
    Binding on height {
        when: root.bottomSheet && root.fullScreenSheet
        value: d.windowHeight
    }

    Binding on y {
        when: root.bottomSheet && !enterTransition.running && !root.fullScreenSheet
        value: root.desiredY
    }

    Binding on y {
        when: !root.bottomSheet && !enterTransition.running
        value: (d.windowHeight - root.height) / 2
    }

    Binding on x {
        when: !root.bottomSheet
        value: (d.windowWidth - root.width) / 2
    }

    Binding on x {
        when: root.bottomSheet
        value: 0
    }

    Binding on margins {
        when: root.bottomSheet
        value: -1
    }

    parent: Overlay.overlay

    modal: true

    standardButtons: Dialog.Cancel | Dialog.Ok

    Overlay.modal: Rectangle {
        color: Theme.palette.backdropColor
    }

    background: StatusDialogBackground {
        color: root.backgroundColor
    }

    header: StatusDialogHeader {
        visible: root.title || root.subtitle
        headline.title: root.title
        headline.subtitle: root.subtitle
        actions.closeButton.onClicked: root.closeHandler()
    }

    footer: StatusDialogFooter {
        id: footerItem

        readonly property int rejectRoleFlags: Dialog.Cancel | Dialog.Close | Dialog.Abort
        readonly property int noRoleFlags: Dialog.No | Dialog.NoToAll
        readonly property int acceptRoleFlags: Dialog.Ok | Dialog.Open | Dialog.Save
                                               | Dialog.SaveAll | Dialog.Retry | Dialog.Ignore
        readonly property int yesRoleFlags: Dialog.Yes | Dialog.YesToAll

        visible: rightButtons
                 && root.standardButtons & (rejectRoleFlags | noRoleFlags | acceptRoleFlags
                                            | yesRoleFlags | Dialog.ApplyRole)

        rightButtons: ObjectModel {
            StatusButton {
                visible: root.standardButtons & footerItem.rejectRoleFlags
                type: StatusButton.Danger
                text: {
                    if (root.standardButtons & Dialog.Close)
                        return qsTr("Close")
                    if (root.standardButtons & Dialog.Abort)
                        return qsTr("Abort")
                    return qsTr("Cancel")
                }

                onClicked: root.reject()
            }

            StatusButton {
                visible: root.standardButtons & footerItem.noRoleFlags
                type: StatusButton.Danger
                text: {
                    if (root.standardButtons & Dialog.NoToAll)
                        return qsTr("No to all")
                    return qsTr("No")
                }

                onClicked: root.reject()
            }

            StatusButton {
                visible: root.standardButtons & footerItem.acceptRoleFlags
                text: {
                    if (root.standardButtons & Dialog.Open)
                        return qsTr("Open")
                    if (root.standardButtons & Dialog.Save)
                        return qsTr("Save")
                    if (root.standardButtons & Dialog.SaveAll)
                        return qsTr("Save all")
                    if (root.standardButtons & Dialog.Retry)
                        return qsTr("Retry")
                    if (root.standardButtons & Dialog.Ignore)
                        return qsTr("Ignore")
                    return root.okButtonText
                }

                onClicked: root.accept()
            }

            StatusButton {
                visible: root.standardButtons & footerItem.yesRoleFlags
                type: StatusButton.Danger
                text: {
                    if (root.standardButtons & Dialog.YesToAll)
                        return qsTr("Yes to all")
                    return qsTr("Yes")
                }

                onClicked: root.accept()
            }

            StatusButton {
                visible: root.standardButtons & Dialog.ApplyRole
                text: qsTr("Apply")

                onClicked: root.applied()
            }
        }
    }

    onClosed: {
        if (root.destroyOnClose) {
            root.destroy()
        }
    }
}
