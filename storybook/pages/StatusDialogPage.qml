import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import Storybook

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups.Dialog

import AppLayouts.Wallet.controls

SplitView {
    id: root

    orientation: Qt.Horizontal

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        PopupBackground {
            anchors.fill: parent
            Button {
                anchors.centerIn: parent
                text: "Reopen"
                onClicked: dialog.open()
            }
        }

        StatusDialog {
            id: dialog

            title: ctrlTitle.text
            subtitle: ctrlSubTitle.text
            backgroundColor: !!ctrlBgColor.text ? ctrlBgColor.text : Theme.palette.statusModal.backgroundColor

            padding: ctrlPadding.text

            contentItem: ColumnLayout {
                spacing: 16
                StatusBaseText {
                    Layout.fillWidth: true
                    font.pixelSize: Theme.fontSize(22)
                    font.bold: true
                    text: "Custom header inside contentItem"
                }
                StatusBaseText {
                    Layout.fillWidth: true
                    font.pixelSize: Theme.secondaryAdditionalTextSize
                    text: "Here comes the content\n\nThe quick brown fox jumps over the lazy dog"
                }
            }

            // custom bg, not needed unless you want a gradient
            background: StatusDialogBackground {
                gradient: Gradient {
                    GradientStop { position: 0.0; color: ctrlBgGradient.checked ? "ghostwhite" : dialog.backgroundColor }
                    GradientStop { position: 1.0; color: dialog.backgroundColor }
                }
            }

            // custom header; not needed unless you want to override the icon or the (close) button(s)
            header: StatusDialogHeader {
                color: !!ctrlHeaderBgColor.text ? ctrlHeaderBgColor.text : Theme.palette.statusModal.backgroundColor
                dropShadowEnabled: ctrlHeaderDropShadow.checked

                visible: dialog.title || dialog.subtitle
                headline.title: dialog.title
                headline.subtitle: dialog.subtitle
                actions.closeButton.onClicked: dialog.closeHandler()

                leftComponent: ctrlHeaderIconComponent.checked ? headerIconComponent : null
            }

            Component {
                id: headerIconComponent
                StatusRoundIcon {
                    asset.name: "settings"
                    asset.width: 24
                    asset.height: 24
                }
            }

            footer: StatusDialogFooter {
                color: !!ctrlFooterBgColor.text ? ctrlFooterBgColor.text : Theme.palette.statusModal.backgroundColor
                dropShadowEnabled: ctrlDropShadow.checked

                leftButtons: ObjectModel {
                    ColumnLayout {
                        Layout.leftMargin: dialog.leftPadding/2
                        StatusBaseText {
                            text: "Max. slippage:"
                            color: Theme.palette.baseColor1
                            font.pixelSize: Theme.additionalTextSize
                        }
                        StatusBaseText {
                            text: "0.5%"
                            font.pixelSize: Theme.additionalTextSize
                        }
                    }
                }
                rightButtons: ObjectModel {
                    RowLayout {
                        Layout.rightMargin: dialog.rightPadding/2
                        spacing: 16
                        StatusFlatButton {
                            icon.name: "settings-advanced"
                            textColor: Theme.palette.directColor1
                        }
                        ColumnLayout {
                            StatusBaseText {
                                text: "Max. fees:"
                                color: Theme.palette.baseColor1
                                font.pixelSize: Theme.additionalTextSize
                            }
                            StatusBaseText {
                                text: "1.54 EUR"
                                font.pixelSize: Theme.additionalTextSize
                            }
                        }
                        StatusButton {
                            icon.name: "password"
                            text: "Swap"
                        }
                    }
                }

                errorTags: ctrlAddErrorTags.checked ? errorTagsModel: null
            }
        }
    }

    ObjectModel {
        id: errorTagsModel
        RouterErrorTag {
            errorTitle: "Error 1"
            buttonText: "Add ETH"
        }
        RouterErrorTag {
            errorTitle: "Error 2"
            buttonText: "Add ETH"
            errorDetails: "Details will appear here"
            expandable: true
        }
    }

    LogsAndControlsPanel {
        SplitView.preferredWidth: 320
        SplitView.fillHeight: true

        ColumnLayout {
            Layout.fillWidth: true

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Title:"
                }
                TextField {
                    Layout.fillWidth: true
                    id: ctrlTitle
                    text: "Remove me to hide the header"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Subtitle:"
                }
                TextField {
                    Layout.fillWidth: true
                    id: ctrlSubTitle
                    text: ""
                }
            }

            CheckBox {
                id: ctrlHeaderIconComponent
                text: "Header icon"
            }

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Padding:"
                }
                TextField {
                    Layout.fillWidth: true
                    id: ctrlPadding
                    text: "32"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Custom bg color:"
                }
                TextField {
                    Layout.fillWidth: true
                    id: ctrlBgColor
                    text: ""
                }
            }

            CheckBox {
                Layout.leftMargin: 24
                id: ctrlBgGradient
                text: "Bg gradient"
            }

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Header bg color:"
                }
                TextField {
                    Layout.fillWidth: true
                    id: ctrlHeaderBgColor
                    text: ""
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Footer bg color:"
                }
                TextField {
                    Layout.fillWidth: true
                    id: ctrlFooterBgColor
                    text: ""
                }
            }
            CheckBox {
                id: ctrlDropShadow
                text: "Footer drop shadow"
            }
            CheckBox {
                id: ctrlHeaderDropShadow
                text: "Header drop shadow"
            }
            CheckBox {
                id: ctrlAddErrorTags
                text: "Add error tags"
            }
        }
    }
}

// category: Popups
// status: good
