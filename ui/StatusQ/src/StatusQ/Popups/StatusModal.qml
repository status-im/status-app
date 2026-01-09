import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Popups.Dialog

import "statusModal" as Spares

/*!
   \qmltype StatusModal
   \inherits StatusDialog
   \inqmlmodule StatusQ.Popups
   \since StatusQ.Popups 0.1
   \brief DEPRECATED: for new code, please use StatusDialog! The StatusModal provides a template for creating Modals.

   Example of how to use it:

   \qml
        StatusModal {
            anchors.centerIn: parent
            headerSettings.title: "Some Title"
            headerSettings.subTitle: "Subtitle"
            headerActionButton: StatusFlatRoundButton {
                type: StatusFlatRoundButton.Type.Secondary
                width: 32
                height: 32

                icon.width: 20
                icon.height: 20
                icon.name: "info"
            }

            leftButtons: [
                StatusRoundButton {
                    icon.name: "arrow-left"
                }
            ]
            rightButtons: [
                StatusButton {
                    text: qsTr("Button")
                },
                StatusButton {
                    text: qsTr("Button")
                }
            ]
        }
   \endqml

   For a list of components available see StatusQ.
*/

StatusDialog {
    id: root

    /*!
       \qmlproperty advancedHeader
        This property represents the item loaded in header loader.
        Can be used to read values from the component assigned to the loader.
    */
    property alias advancedHeader: advancedHeader.item
    /*!
       \qmlproperty advancedHeader
        This property represents the item loaded in footer loader.
        Can be used to read values from the component assigned to the loader.
    */
    property alias advancedFooter: advancedFooter.item
    /*!
       \qmlproperty advancedHeader
        This property can be used to assign a Component to the advanced loader.
        This was introduced to give more control to user on the Modal Header

        example usage below

        \qml
            StatusModal {
                id: advancedHeaderFooterModal
                anchors.centerIn: parent
                showHeader: false
                showAdvancedHeader: true
                advancedHeaderComponent: Rectangle {
                    width: parent.width
                    height: 50
                    color: Theme.palette.baseColor1
                    border.width: 1
                    StatusBaseText {
                        anchors.centerIn: parent
                        text: qsTr("Add any header here")
                        font.pixelSize: Theme.primaryTextFontSize
                        color: Theme.palette.directColor1
                    }
                }
        \endqml
    */
    property alias advancedHeaderComponent: advancedHeader.sourceComponent
    /*!
       \qmlproperty advancedHeader
        This property can be used to assign a Component to the advanced loader.
        This was introduced to give more control to user on the Modal Footer.

        example usage below

        \qml
            StatusModal {
                id: advancedHeaderFooterModal
                anchors.centerIn: parent
                showFooter: false
                showAdvancedFooter: true
                advancedFooterComponent: Rectangle {
                    width: parent.width
                    height: 50
                    color: Theme.palette.baseColor1
                    border.width: 1
                    StatusBaseText {
                        anchors.centerIn: parent
                        text: qsTr("Add any footer here")
                        font.pixelSize: Theme.primaryTextFontSize
                        color: Theme.palette.directColor1
                    }
                }
        \endqml
    */
    property alias advancedFooterComponent: advancedFooter.sourceComponent
    /*!
       \qmlproperty headerActionButton
        This property lets the user add a button to the header of the Modal.
        This does not apply to the advanced header!
    */
    property alias headerActionButton: headerImpl.actionButton

    /*!
       \qmlproperty header
        type: StatusModalHeaderSettings
        This property exposes the different properties of the standard header.
    */
    property StatusModalHeaderSettings headerSettings: StatusModalHeaderSettings {
        title: root.title
        subTitle: root.subtitle
    }
    /*!
       \qmlproperty rightButtons
        This property helps user assign the right buttons on the footer.
        This doesn't not apply to the advanced footer!
    */
    property alias rightButtons: footerImpl.rightButtons
    /*!
       \qmlproperty leftButtons
        This property helps user assign the left buttons on the footer.
        This doesn't not apply to the advanced footer!
    */
    property alias leftButtons: footerImpl.leftButtons
    /*!
       \qmlproperty showHeader
        This property to decides whether the standard header is shown.
        default value is true
    */
    property bool showHeader: true
    /*!
       \qmlproperty showHeader
        This property to decides whether the standard footer is shown.
        default value is true
    */
    property bool showFooter: true
    /*!
       \qmlproperty showAdvancedHeader
        This property to decides whether the advanced header is shown.
        default value is false.
    */
    property bool showAdvancedHeader: false
    /*!
       \qmlproperty showAdvancedFooter
        This property decides whether the advanced footer is shown.
        default value is false.
    */
    property bool showAdvancedFooter: false
    /*!
       \qmlproperty hasCloseButton
        This property decides whether the standard header has a close button.
    */
    property bool hasCloseButton: true
    /*!
       \qmlproperty hasFloatingButtons
        This property decides whether the advanced header has floating buttons on top of the Modal
    */
    property bool hasFloatingButtons: false

    signal editButtonClicked()
    signal headerImageClicked()

    // Simple popups for now. The complex ones need more work
    fullScreenSheet: hasCloseButton && !showAdvancedHeader

    width: 480

    padding: 0

    header: ToolBar {
        position: ToolBar.Top
        background: StatusDialogBackground {
            implicitHeight: headerImpl.implicitHeight
        }
        Spares.StatusModalHeader {
            id: headerImpl
            anchors.top: parent.top
            width: visible ? parent.width : 0
            height: visible ? implicitHeight : 0

            visible: root.showHeader
            title: headerSettings.title
            titleElide: headerSettings.titleElide
            subTitle: headerSettings.subTitle
            subTitleElide: headerSettings.subTitleElide
            asset: headerSettings.asset
            popupMenu: headerSettings.popupMenu
            headerImageEditable: headerSettings.headerImageEditable
            editable: headerSettings.editable
            hasCloseButton: root.hasCloseButton

            onEditButtonClicked: root.editButtonClicked()
            onHeaderImageClicked: root.headerImageClicked()
            onClose: root.closeHandler()
        }

        Loader {
            id: advancedHeader
            anchors.top: parent.top
            anchors.topMargin: hasFloatingButtons ? -18 - height : 0
            width: visible ? parent.width : 0
            active: root.showAdvancedHeader
        }
    }

    footer: ToolBar {
        background: StatusDialogBackground {
            implicitHeight: footerImpl.implicitHeight
        }
        position: ToolBar.Bottom
        Spares.StatusModalFooter {
            id: footerImpl
            anchors.bottom: parent.bottom
            width: visible ? parent.width : 0
            height: visible ? implicitHeight : 0
            showFooter: root.showFooter
            visible: root.showFooter
        }

        Loader {
            id: advancedFooter
            anchors.bottom: parent.bottom
            width: visible ? parent.width : 0
            active: root.showAdvancedFooter
        }
    }
}
