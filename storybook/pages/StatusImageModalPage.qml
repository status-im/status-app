import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme

import Models
import Storybook

import SortFilterProxyModel

import utils
import shared.status

SplitView {
    id: root

    orientation: Qt.Vertical

    Logs { id: logs }

    Item {
        id: popupContainer
        SplitView.fillHeight: true
        SplitView.fillWidth: true

        Rectangle {
            anchors.fill: parent
            color: Theme.palette.background
        }

        Image {
            id: localImage
            anchors.centerIn: parent
            source: ModelsData.banners.cryptPunks
            visible: false
        }

        Button {
            anchors.centerIn: parent
            text: "Open"
            visible: !popup.visible
            onClicked: popup.open()
        }

        StatusImageModal {
            id: popup
            Tracer {}
            parent: popupContainer
            modal: false
            visible: true
            closePolicy: Popup.NoAutoClose

            Binding on url {
                value: urlGroup.checkedButton.url
                when: !ctrlLocalImage.checked
            }

            Binding on image {
                value: localImage
                when: ctrlLocalImage.checked
            }
        }

        Label {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            text: "iscale: %1".arg(popup.iscale)
        }

        Label {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: "fitSize: %1".arg(popup.fitSize)
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 320
        SplitView.preferredHeight: 320

        logsView.logText: logs.logText

        ButtonGroup {
            id: urlGroup
            buttons: buttonsColumn.children
        }

        ColumnLayout {
            id: buttonsColumn
            anchors.fill: parent

            UrlRadioButton {
                id: ctrlLocalImage
                text: "Local Image (Status)"
                checked: true
            }
            UrlRadioButton {
                text: "Local image URL (Socks)"
                url: ModelsData.icons.socks
            }
            UrlRadioButton {
                text: "Remote JPEG"
                url: "https://www.deepsilver.com/media/nuhnnymt/kcd2_re_desktop_3840x2160.jpg"
            }
            UrlRadioButton {
                text: "Remote GIF"
                url: "https://media1.giphy.com/media/v1.Y2lkPTc5MGI3NjExZjdtY2dpbnFxczViM2wwMWNjaW43NXdza214eGFuMHg1Y3pjaG9layZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/804TNmnYLfNao/giphy.gif"
            }
            UrlRadioButton {
                text: "Remote SVG"
                url: "https://upload.wikimedia.org/wikipedia/commons/7/7b/Znak_Moravy.svg"
            }
            UrlRadioButton {
                text: "Empty image/url"
                url: ""
            }
            UrlRadioButton {
                text: "Non existing image"
                url: "file://tmp/not/here/foobar.jpg"
            }
        }
    }

    component UrlRadioButton: RadioButton {
        property url url
    }
}

// category: Popups
// status: good
