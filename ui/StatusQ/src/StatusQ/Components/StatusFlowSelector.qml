pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Core.Theme
import StatusQ.Controls

/*!
   \qmltype StatusFlowSelector
   \inherits StatusGroupBox
   \inqmlmodule StatusQ.Components
   \since StatusQ.Components 0.1
   \brief It allows to add items and display them as a list within a Flow
   component.

   The \c StatusFlowSelector can be populated with a repeater.

   Example of how the component looks like:
   \image status_item_selector.png

   Example of how to use it:
   \qml
        StatusFlowSelector {
            icon: Assets.svg("contact_verified")
            title: qsTr("Who holds")
            placeholderItem.visible: listModel.count === 0

            Repeater {
                id: repeater

                model: ListModel {
                    id: listModel
                }

                property int counter: 0

                delegate: StatusListItemTag {
                    title: `tag ${model.name}`

                    onClicked: listModel.remove(index)
                }
            }

            addButton.onClicked: {
                listModel.append({ name: `item ${repeater.counter++}` })
            }
        }
   \endqml
   For a list of components available see StatusQ.
*/
StatusGroupBox {
    id: root

    default property alias content: flow.data

    /*!
       \qmlproperty string StatusFlowSelector::placeholderText
       This property holds the placeholder item text which can be shown when the
       list of items is empty.
    */
    property string placeholderText

    /*!
       \qmlproperty url StatusFlowSelector::placeholderImageSource
       This property holds the default item icon shown when the list of items is empty.
    */
    property url placeholderImageSource

    /*!
       \qmlproperty int StatusFlowSelector::flowSpacing
       This property specifies spacing between items in the selector.
    */
    property alias flowSpacing: flow.spacing

    /*!
       \qmlproperty int StatusFlowSelector::placeholderItemHeight
       This property specifies the height of the placeholder item.
    */
    property int placeholderItemHeight: 32

    /*!
       \qmlproperty StatusListItemTag StatusFlowSelector::placeholder
       This property holds an alias to the placeholder item.
    */
    readonly property alias placeholderItem: placeholderListItemTag

    /*!
       \qmlproperty StatusRoundButton StatusFlowSelector::addButton
       This property holds an alias to the `add` button.
    */
    readonly property alias addButton: addItemButton

    Flow {
        id: flow

        width: root.availableWidth
        spacing: 6

        StatusListItemTag {
            id: placeholderListItemTag

            leftPadding: 12
            rightPadding: 12

            width: Math.min(flow.width, implicitWidth)

            bgColor: Theme.palette.baseColor2
            title: root.placeholderText
            asset.name: root.placeholderImageSource
            asset.isImage: true
            closeButtonVisible: false
            titleText.color: Theme.palette.baseColor1
            titleText.font.pixelSize: Theme.primaryTextFontSize

            height: root.placeholderItemHeight
        }

        onPositioningComplete: {
            // the "add" button is intended to be the last item in the flow
            if (addItemButton.Positioner.isLastItem || !addItemButton.visible)
                return

            addItemButton.parent = null
            addItemButton.parent = flow
        }

        StatusRoundButton {
            id: addItemButton
            objectName: "addItemButton_" + root.title

            implicitHeight: root.placeholderItemHeight
            implicitWidth: implicitHeight
            height: width
            type: StatusRoundButton.Type.Secondary
            icon.name: "add"
        }
    }
}
