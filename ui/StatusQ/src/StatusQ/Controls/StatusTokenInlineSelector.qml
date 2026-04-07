pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Components
import StatusQ.Core.Theme

/*!
   \qmltype StatusTokenInlineSelector
   \inherits RowLayout
   \inqmlmodule StatusQ.Controls
   \since StatusQ.Controls 0.1
   \brief It presents selectable tokens in inline form.

   The \c StatusTokenInlineSelector is a graphical component that is meant to be used as inline text input.

   Example of how the component looks like:
   \image status_token_inline_selector.png
*/

RowLayout {
    id: root

    /*!
       \qmlproperty var StatusTokenInlineSelector::tokens
       This is a REQUIRED property that contains an array of objects that describes each token.

       \qml
            tokens: [{amount: 0.1, token: "ETH"}, {amount: 10, token: "SNT"}]
       \endqml
    */
    property var tokens

    /*!
       \qmlproperty var StatusTokenInlineSelector::tokenImageSourceGetter
       This is a property function used to acquire image source for given token.
    */
    property var tokenImageSourceGetter: function (token: string): string {
        return Qt.resolvedUrl("../../assets/img/icons/%1.png".arg(token))
    }

    signal triggered(real amount, string token)

    StatusBaseText {
        text: qsTr("Hold")
        color: Theme.palette.directColor6
        font.pixelSize: Theme.primaryTextFontSize
    }

    Repeater {
        model: Math.max(0, root.tokens.length - 1)
        delegate: Loader {
            sourceComponent: tokenComponent
            onLoaded: d.assignItemProperties(item, index, root.tokens[index])
        }
    }

    StatusBaseText {
        text: qsTr("or")
        color: Theme.palette.directColor6
        font.pixelSize: Theme.primaryTextFontSize
    }

    Loader {
        active: root.tokens.length > 1
        sourceComponent: tokenComponent
        onLoaded: {
            const index = root.tokens.length - 1
            d.assignItemProperties(item, index, root.tokens[index])
        }
    }

    StatusBaseText {
        text: qsTr("to post")
        color: Theme.palette.directColor6
        font.pixelSize: Theme.primaryTextFontSize
    }

    QtObject {
        id: d
        function assignItemProperties(item: var, index: int, modelData: var): void {
            item.tokenImageSource = root.tokenImageSourceGetter(modelData.token)
            item.token = modelData.token
            item.amount = modelData.amount
            item.backgroundColor = Qt.binding(() => index % 2 ? Theme.palette.primaryColor3 : Theme.palette.dangerColor3)
            item.hoverColor = Qt.binding(() => index % 2 ? Theme.palette.primaryColor2 : Theme.palette.dangerColor2)
            item.textColor = Qt.binding(() => index % 2 ? Theme.palette.primaryColor1 : Theme.palette.dangerColor1)
        }
    }

    Component {
        id: tokenComponent

        Rectangle {
            property string amount
            property string token
            property string tokenImageSource
            property color backgroundColor
            property color hoverColor
            property color textColor

            width: content.width + 4
            height: content.height + 4

            radius: height/2

            color: mouseArea.containsMouse ? hoverColor : backgroundColor

            Behavior on color {
                ColorAnimation {
                    running: visible
                }
            }

            RowLayout {
                id: content

                anchors.centerIn: parent

                StatusRoundedImage {
                    id: roundedImage
                    Layout.maximumHeight: text.height + 2
                    Layout.maximumWidth: text.height + 2
                    image.source: tokenImageSource
                }

                StatusBaseText {
                    id: text
                    text: amount + " " + token
                    color: textColor
                    font.pixelSize: Theme.primaryTextFontSize
                }

                Item {
                    implicitWidth: 2
                }
            }

            StatusMouseArea {
                id: mouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                propagateComposedEvents: true
            }

            Rectangle {
                id: pressIndicator

                height: parent.height
                radius: height / 2
                color: textColor
                opacity: 0.1

                NumberAnimation on width {
                    from: 0
                    to: parent.width
                    duration: 800
                    running: visible && mouseArea.containsPress

                    onStopped: {
                        if (pressIndicator.width == parent.width) {
                            root.triggered(amount, token)
                        }
                        pressIndicator.width = 0
                    }
                }
            }
        }
    }
}
