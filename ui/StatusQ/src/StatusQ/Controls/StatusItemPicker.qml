pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

/*!
   \qmltype StatusItemPicker
   \inherits Item
   \inqmlmodule StatusQ.Controls
   \since StatusQ.Controls 0.1
   \brief It presents a selectable item to the user. Inherits \l{https://doc.qt.io/qt-5/qml-qtquick-rectangle.html}{Rectangle}.

   The \c StatusItemPicker is populated with the given properties data.

   StatusItemPicker can be made as a RadioButton or CheckBox selectable item.

   Example of how the component looks like:
   \image status_item_picker.png
   Example of how to use it:
   \qml
        StatusItemPicker {
            width: 300
            height: 40
            imageSource: model.imageSource
            name: model.name
            shortName: model.shortName
            selectorType: root.multiSelection ? StatusItemPicker.SelectorType.CheckBox : StatusItemPicker.SelectorType.RadioButton
            selected: model.selected
            radioGroup: content.radioGroup

            onCheckedChanged: { // Some updates }
        }
   \endqml
   For a list of components available see StatusQ.
*/
Rectangle {
    id: root

    /*!
       \qmlproperty string StatusItemPicker::asset
       This property holds the asset(image/icon) settings information.
    */
    property StatusAssetSettings asset

    /*!
       \qmlproperty string StatusItemPicker::name
       This property holds the main text or name to be displayed.
    */
    property string name

    /*!
       \qmlproperty int StatusItemPicker::namePixelSize
       This property holds pixel size of the name to be displayed.
    */
    property int namePixelSize: Theme.primaryTextFontSize

    /*!
       \qmlproperty string StatusItemPicker::shortName
       This property holds the secondary text or short name to be displayed.
    */
    property string shortName

    /*!
       \qmlproperty string StatusItemPicker::selectorType
       This property holds the selector type. Possible options are:
       \qml
        enum SelectorType {
            RadioButton,
            CheckBox
        }
      \endqml
      By default, RadioButton.
    */
    property int selectorType: StatusItemPicker.SelectorType.RadioButton

    /*!
       \qmlproperty string StatusItemPicker::selected
       This property holds if the item is selected.
    */
    property bool selected

    /*!
       \qmlproperty string StatusItemPicker::radioGroup
       This property holds the button group object the radiobutton belongs to.
    */
    property ButtonGroup radioGroup

    /*!
       \qmlproperty int StatusItemPicker::radioButtonSize
       This property holds size type of the radio button.
       Possible values are:
       - Small
       - Large (default size)
    */
    property int radioButtonSize: StatusRadioButton.Size.Large

    /*!
        \qmlsignal StatusItemPicker::checkedChanged(bool checked)
        This signal is emitted when the item is selected by pressing the radiobutton or the checkbox.
    */
    signal checkedChanged(bool checked)

    enum SelectorType {
        RadioButton,
        CheckBox
    }

    QtObject {
        id: d

        readonly property int minShortNameWidth: root.shortName ? 50 : 0

        function availableTextWidth(): real {
             return root.width - imageItem.width - row.spacing - shortNameItem.anchors.rightMargin - selector.width - selector.anchors.rightMargin - 24/*Margin between both texts*/
        }
    }

    Row {
        id: row
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        StatusIcon {
            id: imageItem
            anchors.verticalCenter: parent.verticalCenter
            source: root.asset && root.asset.name ? root.asset.name : ""
            width: root.asset ? root.asset.width : 0
            height: root.asset ? root.asset.height : 0
            visible: root.asset && root.asset.name !== undefined
        }

        StatusBaseText {
            id: nameItem
            anchors.verticalCenter: parent.verticalCenter
            width: dummyNameItem.width > d.availableTextWidth() - d.minShortNameWidth ?
                   d.availableTextWidth() - d.minShortNameWidth :
                   dummyNameItem.width
            text: root.name
            color: Theme.palette.directColor1
            font.pixelSize: root.namePixelSize
            clip: true
            elide: Text.ElideRight
        }
        // Dummy object just to exactly know the width needed by `name` and dynamically set a limit for nameItem and shortNameItem components
        StatusBaseText {
            id: dummyNameItem
            visible: false
            text: root.name
            font.pixelSize: Theme.primaryTextFontSize
        }
    }

    StatusBaseText {
        id: shortNameItem
        width: d.availableTextWidth() - nameItem.width < d.minShortNameWidth ?
               d.minShortNameWidth :
               d.availableTextWidth() - nameItem.width
        anchors.right: selector.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.shortName
        color: Theme.palette.baseColor1
        font.pixelSize: Theme.primaryTextFontSize
        clip: true
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignRight
    }

    // 2 different options: Or with radio buttons or with checkboxes:
    Loader {
        id: selector
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 18
        sourceComponent: root.selectorType === StatusItemPicker.SelectorType.RadioButton ? radioBtn : checkbox
    }

    Component {
        id: radioBtn
        StatusRadioButton {
            size: root.radioButtonSize
            ButtonGroup.group: root.radioGroup
            checked: root.selected
            onCheckedChanged: {
                root.selected = checked
                root.checkedChanged(checked)
            }
        }
    }

    Component {
        id: checkbox
        StatusCheckBox {
            checked: root.selected
            onCheckedChanged: {
                root.selected = checked
                root.checkedChanged(checked)
            }
        }
    }
}// End of Content item
