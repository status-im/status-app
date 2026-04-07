pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

/*!
   \qmltype StatusItemSelector
   \inherits StatusFlowSelector
   \inqmlmodule StatusQ.Components
   \since StatusQ.Components 0.1
   \brief It allows to add items and display them as a tag item with an image
   and text. It also allows to store and display logical `and` / `or` operators
   into the list.

   The \c StatusItemSelector is populated with a data model. The data model is
   commonly a JavaScript array or a ListModel object with specific expected roles.

   Example of how the component looks like:
   \image status_item_selector.png

   Example of how to use it:
   \qml
        StatusItemSelector {
            icon: Assets.svg("contact_verified")
            title: qsTr("Who holds")
            defaultItemText: qsTr("Example: 10 SNT")
            andOperatorText: qsTr("and")
            orOperatorText: qsTr("or")

            CustomPopup {
                id: popup
            }

            addButton.onClicked: {
                popup.x = mouse.x
                popup.y = mouse.y
                popup.open()
            }
        }
   \endqml
   For a list of components available see StatusQ.
*/
StatusFlowSelector {
    id: root

    /*!
       \qmlproperty ListModel StatusItemSelector::model
       This property holds the data that will be populated in the items selector.

       Here an example of the model roles expected:
       \qml
        model: ListModel {
            ListElement {
                text: "Socks"
                imageSource: "qrc:imports/assets/png/tokens/SOCKS.png"
                isIcon: false
                color: ""
                emoji: ""
                operator: Utils.Operator.None
            }
            ListElement {
                text: "ZRX"
                imageSource: "qrc:imports/assets/png/tokens/ZRX.png"
                isIcon: false
                color: ""
                emoji: ""
                operator: Utils.Operator.Or
            }
            ListElement {
                text: "Custom Token"
                imageSource: ""
                isIcon: true
                color: "red"
                emoji: "⚽"
                operator: Utils.Operator.Or
            }
        }
       \endqml
    */
    property alias model: repeater.model

    property StatusAssetSettings asset: StatusAssetSettings {
        height: 20
        width: 20
        bgHeight: height
        bgWidth: width
        bgColor: "transparent"
        isLetterIdenticon: root.useLetterIdenticons
    }
    property int tagLeftPadding: 6

    /*!
       \qmlproperty bool StatusItemSelector::useLetterIdenticons
       This property determines if letter identicons should be used. If set to
       true, the model is expected to contain roles "color" and "emoji".
    */
    property bool useLetterIdenticons: false

    /*!
       \qmlproperty bool StatusItemSelector::itemsClickable
       This property determines if items in the selector are clickable (cursor
       is changed on hover and itemClicked emitted when clicked)
    */
    property bool itemsClickable: true

    readonly property alias count: repeater.count

    /*!
       \qmlsignal StatusItemSelector::itemClicked
       This signal is emitted when the item is clicked.
    */
    signal itemClicked(var item, int index, var mouse)

    placeholderItem.visible: repeater.count === 0

    Repeater {
        id: repeater

        RowLayout {
            spacing: flowSpacing

            StatusBaseText {
                visible: model.operator !== OperatorsUtils.Operators.None
                Layout.alignment: Qt.AlignVCenter
                text: OperatorsUtils.setOperatorTextFormat(model.operator)
                color: Theme.palette.primaryColor1
                font.pixelSize: Theme.secondaryAdditionalTextSize
                StatusMouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // Switch operator
                        if(model.operator === OperatorsUtils.Operators.And)
                            model.operator = OperatorsUtils.Operators.Or
                        else
                            model.operator = OperatorsUtils.Operators.And
                    }
                }
            }
            StatusListItemTag {
                title: model.text

                asset.height: root.asset.height
                asset.width: root.asset.width
                asset.bgHeight: root.asset.bgHeight
                asset.bgWidth: root.asset.bgWidth
                asset.name: root.useLetterIdenticons ? model.text : (model.imageSource ?? "")
                asset.isImage: !model.isIcon
                asset.bgColor: root.asset.bgColor
                asset.emoji: model.emoji ? model.emoji : ""
                asset.color: model.color ? model.color : titleText.color
                asset.isLetterIdenticon: root.useLetterIdenticons
                closeButtonVisible: false
                titleText.color: Theme.palette.primaryColor1
                titleText.font.pixelSize: Theme.primaryTextFontSize
                leftPadding: root.tagLeftPadding

                StatusMouseArea {
                    anchors.fill: parent
                    enabled: root.itemsClickable
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => root.itemClicked(parent, model.index, mouse)
                }
            }
        }
    }
}
