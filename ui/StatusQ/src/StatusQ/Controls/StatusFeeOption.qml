pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Components
import StatusQ.Core.Theme

/*!
    \qmltype StatusFeeOption
    \inherits Control
    \inqmlmodule StatusQ.Controls
    \since StatusQ.Controls 0.1
    \brief Displays a clickable option which content is fully customizable

    By design appearance of subText and additionalText as well as their values should be set from outside.
    If any of those two need to be displayed a component that has an empty value will be rendering a loading state.
    The control renders based on the selected property.
    When control is clicked clicked signal will be emitted.

    Example of how to use it:

    \qml
        StatusFeeOption {
            subText: "1.65 EUR"
            showSubText: true

            additionalText: "~40s"
            showAdditionalText: true

            onSelectedChanged: {
                // this option is selected/unselected
            }
        }
    \endqml

    For a list of components available see StatusQ.
 */

Control {
    id: root

    required property int type

    property bool selected: false

    required property string mainText

    property string subText
    property bool showSubText

    property string additionalText
    property bool showAdditionalText

    property string unselectedText

    required property string icon

    signal clicked()

    font.family: Fonts.baseFont.family
    font.pixelSize: Theme.tertiaryTextFontSize

    horizontalPadding: 8
    verticalPadding: 8

    property Component subTextComponent: StatusAnimatedText {
        verticalAlignment: Qt.AlignVCenter
        text: root.subText
        font: root.font
    }

    property Component additionalTextComponent: StatusAnimatedText {
        verticalAlignment: Qt.AlignVCenter
        text: root.additionalText
        font: root.font
        color: Theme.palette.baseColor1
    }

    property Component unselectedTextComponent: StatusBaseText {
        verticalAlignment: Qt.AlignVCenter
        text: root.unselectedText
        color: Theme.palette.baseColor1
        font.family: root.font.family
        font.pixelSize: root.font.pixelSize
        wrapMode: Text.WordWrap
        elide: Text.ElideRight
    }

    property Component loaderComponent: LoadingComponent {
        radius: 4
        height: root.font.pixelSize
    }

    background: Rectangle {
        id: background
        implicitHeight: 84
        implicitWidth: 101
        radius: Theme.radius
        border.width: 1
        border.color: root.selected? Theme.palette.primaryColor1 : Theme.palette.baseColor2
        color: {
            if (root.hovered) {
                return Theme.palette.baseColor2
            }

            if (root.selected) {
                return StatusColors.alphaColor(Theme.palette.baseColor2, 0.1)
            }

            return Theme.palette.statusAppLayout.backgroundColor
        }
    }

    contentItem: ColumnLayout {
        spacing: 4

        RowLayout {

            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(mText.height, image.height)

            spacing: 4

            StatusBaseText {
                id: mText
                Layout.fillWidth: true
                verticalAlignment: Qt.AlignVCenter
                text: root.mainText
                font.family: root.font.family
                font.pixelSize: root.font.pixelSize
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
            }

            StatusImage {
                id: image
                visible: root.selected || root.hovered
                width: 20
                height: 20
                source: root.icon
            }
        }

        Item {
            id: spacer
            Layout.fillWidth: true
            Layout.preferredHeight: 8 + (unselectedTextLoader.visible? parent.spacing : 0)
        }

        Loader {
            visible: root.showSubText
            Layout.preferredWidth: parent.width
            sourceComponent: !!root.subText? subTextComponent : loaderComponent
        }

        Loader {
            visible: root.showAdditionalText
            Layout.preferredWidth: parent.width
            sourceComponent: !!root.additionalText? additionalTextComponent : loaderComponent
        }

        Loader {
            id: unselectedTextLoader
            visible: !root.selected && !!root.unselectedText
            Layout.preferredWidth: parent.width
            Layout.fillHeight: true
            sourceComponent: visible? unselectedTextComponent : loaderComponent
        }
    }

    StatusMouseArea {
        anchors.fill: parent
        cursorShape: root.hovered? Qt.PointingHandCursor : undefined
        onClicked: root.clicked()
    }
}
