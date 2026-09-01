import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Qt5Compat.GraphicalEffects
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Core.Utils

/*!
    \qmltype StatusToastMessage
    \inherits Control
    \inqmlmodule StatusQ.Components
    \since StatusQ.Components 0.1
    \brief Displays a toast message in the UI. Inherits \l{https://doc.qt.io/qt-5/qml-qtquick-controls2-control.html}{Control}.

    The \c StatusToastMessage displays a toast message in the UI either standalone or as part
    of a stack of toast messages.
    For example:

    \qml
    StatusToastMessage {
        primaryText: qsTr("Collectible is being minted...")
        secondaryText: qsTr("View on Etherscan")
        loading: true
        type: 0
        linkUrl: "http://google.com"
        duration: 5000
    }
    \endqml

    \image status_toast_message.png

    For a list of components available see StatusQ.
 */


Control {
    id: root
    implicitWidth: 374

    verticalPadding: 15
    leftPadding: 12
    rightPadding: 8

    /*!
        \qmlproperty bool StatusToastMessage::open
        This property represents all steps and their descriptions as provided by the user.
    */
    property bool open: true
    /*!
        \qmlproperty string StatusToastMessage::primaryText
        This property represents the title text of the ToastMessage.
    */
    property string primaryText: ""
    /*!
        \qmlproperty string StatusToastMessage::secondaryText
        This property represents the subtitle text of the ToastMessage.
    */
    property string secondaryText: ""
    /*!
        \qmlproperty bool StatusToastMessage::loading
        This property represents activates/deactivates the loading indicator of the ToastMessage.
    */
    property bool loading: false
    /*!
        \qmlproperty string StatusToastMessage::linkUrl
        This property represents all steps and their descriptions as provided by the user.
    */
    property string linkUrl: ""

    /*!
        \qmlproperty int StatusToastMessage::duration
        This property represents duration in milliseconds, for how long a toast will be visible. If 0 is set for
        duration, that means a toast won't dissapear without user's interaction (click on close).
    */
    property int duration: 0

    /*!
        \qmlproperty StatusAssetSettings StatusToastMessage::icon
        This property holds a set of settings for the icon of the ToastMessage.
    */
    property StatusAssetSettings icon: StatusAssetSettings {
        width: 23
        height: 23
    }

    /*!
        \qmlproperty string StatusToastMessage::image
        This property holds an image source to be displayed in the ToastMessage.
    */
    property string image: ""

    /*!
        \qmlproperty real StatusToastMessage::imageSize
        This property holds the imageSize of the image to be displayed in the ToastMessage.
    */
    property int imageSize: 32

    /*!
        \qmlproperty real StatusToastMessage::imageRadius
        This property holds the imageRadius of the image to be displayed in the ToastMessage.
    */
    property real imageRadius: imageSize / 2

    /*!
        \qmlproperty int StatusToastMessage::type
        This property holds the type of the ToastMessage. Values are:
        \list
            \li Default
            \li Success
        \endlist

    */
    property int type: StatusToastMessage.Type.Default
    enum Type {
        Default,
        Success,
        Danger
    }

    /*!
        \qmlproperty bool StatusToastMessage::actionRequired
        This property holds if the specific toast message will enable a specific UI action apart from an external link navigation.
    */
    property bool actionRequired: false

    /*!
        \qmlproperty bool StatusToastMessage::iconColor
        This property holds icon color if it needs a customized color, otherwise, it will depend on toast type.
    */
    property string iconColor: ""

    Accessible.name: Utils.formatAccessibleName(root.primaryText + (root.secondaryText.length ? (" — " + root.secondaryText) : ""), objectName)

    /*!
        \qmlsignal
        This signal is emitted when the ToastMessage is clicked.
    */
    signal clicked()
    /*!
        \qmlsignal
        This signal is emitted when the ToastMessage is closed (after animation).
    */
    signal close()
    /*!
        \qmlsignal
        This signal is emitted when the ToastMessage contains a url and this url
        is clicked by the user.
    */
    signal linkActivated(string link)

    QtObject {
        id: d

        readonly property string openedState: "opened"
        readonly property string closedState: "closed"
        readonly property string iconColor: {
            // If specified:
            if(root.iconColor != "")
                return root.iconColor

            // If not specified
            switch(root.type) {
            case StatusToastMessage.Type.Success:
                return Theme.palette.successColor1
            case StatusToastMessage.Type.Danger:
                return Theme.palette.dangerColor1
            default:
                return Theme.palette.primaryColor1
            }
        }
        readonly property string iconBgColor: {
            // If specified:
            if(root.iconColor != "")
                return StatusColors.getColor(root.iconColor, 0.1)

            // If not specified
            switch(root.type) {
            case StatusToastMessage.Type.Success:
                return Theme.palette.successColor2
            case StatusToastMessage.Type.Danger:
                return Theme.palette.dangerColor3
            default:
                return Theme.palette.primaryColor3
            }
        }
    }

    Timer {
        interval: root.duration
        running: root.duration > 0
        onTriggered: {
            root.open = false;
        }
    }

    states: [
        State {
            name: d.openedState
            when: root.open
            PropertyChanges {
                target: root
                anchors.rightMargin: 0
                opacity: 1.0
            }
        },
        State {
            name: d.closedState
            when: !root.open
            PropertyChanges {
                target: root
                anchors.rightMargin: -width
                opacity: 0.0
            }
        }
    ]

    transitions: [
        Transition {
            to: "*"
            NumberAnimation { properties: "anchors.rightMargin,opacity"; duration: 400 }

            onRunningChanged: {
                if(!running && state == d.closedState) {
                    root.close();
                }
            }
        }
    ]

    background: Rectangle {
        id: background
        color: Theme.palette.statusToastMessage.backgroundColor
        radius: 8
        border.color: Theme.palette.baseColor2
        layer.enabled: true
        layer.effect: DropShadow {
            verticalOffset: 3
            radius: 8
            samples: 15
            fast: true
            cached: true
            color: Theme.palette.dropShadow
        }
    }

    contentItem: Item {
        implicitWidth: layout.implicitWidth
        implicitHeight: layout.implicitHeight
        StatusMouseArea {
            anchors.fill: parent
            onMouseXChanged: {
                root.open = (mouseX < (root.width/3));
            }
            onClicked: {
                root.clicked();
            }
        }
        RowLayout {
            id: layout
            anchors.fill: parent
            spacing: 12
            Rectangle {
                implicitWidth: 32
                implicitHeight: 32
                Layout.alignment: Qt.AlignVCenter
                radius: (root.width/2)
                color: d.iconBgColor
                visible: loader.sourceComponent != undefined
                Loader {
                    id: loader
                    anchors.centerIn: parent
                    sourceComponent: root.loading ? loadingInd :
                                                    root.icon.name != "" ? statusIcon :
                                                                           root.image !== "" ? statusImage : undefined

                    Component {
                        id: loadingInd
                        StatusLoadingIndicator {
                            color: d.iconColor
                        }
                    }
                    Component {
                        id: statusIcon
                        StatusIcon {
                            anchors.centerIn: parent
                            width: root.icon.width
                            height: root.icon.height
                            color: d.iconColor
                            icon: root.icon.name
                        }
                    }

                    Component {
                        id: statusImage
                        StatusRoundedImage {
                            anchors.centerIn: parent
                            radius: root.imageRadius
                            width: root.imageSize
                            height: root.imageSize
                            image.source: root.image
                            showLoadingIndicator: false
                            image.fillMode: Image.PreserveAspectCrop
                        }
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                StatusBaseText {
                    id: title
                    Layout.fillWidth: true
                    font.pixelSize: Theme.additionalTextSize
                    color: Theme.palette.directColor1
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap
                    textFormat: Text.RichText
                    text: root.primaryText
                    maximumLineCount: root.secondaryText ? 2 : 3
                    onLinkActivated: {
                        root.linkActivated(link);
                    }
                }
                StatusBaseText {
                    Layout.fillWidth: true
                    visible: (!linkText.visible && !!root.secondaryText)
                    height: visible ? contentHeight : 0
                    font.pixelSize: Theme.additionalTextSize
                    color: Theme.palette.baseColor1
                    text: root.secondaryText
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
                StatusSelectableText {
                    id: linkText

                    Layout.fillWidth: true
                    visible: (!!root.linkUrl) || root.actionRequired
                    height: visible ? implicitHeight : 0
                    font.pixelSize: Theme.additionalTextSize
                    hoveredLinkColor: Theme.palette.primaryColor1
                    text: root.actionRequired ? "<p><a style='text-decoration:none' href=' '>%1</a></p>".arg(root.secondaryText) :
                                                "<p><a style='text-decoration:none' href='%1'>%2</a></p>".arg(root.linkUrl).arg(root.secondaryText)
                    onLinkActivated: {
                        root.linkActivated(link);
                    }
                }
            }
            StatusFlatRoundButton {
                type: StatusFlatRoundButton.Type.Secondary
                icon.name: "close"
                icon.color: Theme.palette.directColor1
                implicitWidth: 30
                implicitHeight: 30
                onClicked: {
                    root.open = false;
                }
            }
        }
    }
}
