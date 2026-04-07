pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import StatusQ.Core
import StatusQ.Core.Theme

/*!
      \qmltype StatusWarningBox
      \inherits Control
      \inqmlmodule StatusQ.Controls
      \since StatusQ.Controls 0.1
      \brief Displays a customizable WarningBox component.
      Inherits \l{https://doc.qt.io/qt-5/qml-qtquick-controls2-control.html}{Control}.

      The \c StatusWarningBox displays a customizable WarningBox for users to show an icon and text.
      For example:

      \qml
      StatusWarningBox {
          icon: "caution"
          text: qsTr("Warning!")
          bgColor: Theme.palette.warningColor1
      }
      \endqml

      \image status_warning_box.png

      For a list of components available see StatusQ.
*/

Control {
    id: root
    padding: 16

    /*!
        \qmlproperty string StatusWarningBox::text
        This property holds a reference to the StatusBaseText component's text property and displays the
        warning text.
    */
    property string text
    /*!
        \qmlproperty string StatusWarningBox::icon
        This property sets the StatusWarningBox icon.
    */
    property string icon
    /*!
        \qmlproperty color StatusWarningBox::iconColor
        This property sets the StatusWarningBox icon color.
    */
    property color iconColor: "transparent"
    /*!
        \qmlproperty int StatusWarningBox::iconAlignment
        This property allows setting the position of the icon inside the warning box component.
    */
    property int iconAlignment: Qt.AlignTop
    /*!
        \qmlproperty color StatusWarningBox::bgColor
        This property sets the StatusWarningBox background color.
    */
    property color bgColor: "transparent"
    /*!
        \qmlproperty color StatusWarningBox::borderColor
        This property sets the StatusWarningBox border color.
    */
    property color borderColor: Theme.palette.warningColor1
    /*!
        \qmlproperty color StatusWarningBox::textColor
        This property sets the StatusWarningBox text color.
    */
    property color textColor: Theme.palette.warningColor1
    /*!
        \qmlproperty int StatusWarningBox::textSize
        This property sets the StatusWarningBox text pixel size
    */
    property int textSize: Theme.primaryTextFontSize
    /*!
        \qmlproperty bool StatusWarningBox::isRowLayout
        This property sets the StatusWarningBox layout as row or column.
    */
    property bool isRowLayout: true
    /*!
        \qmlproperty Component StatusWarningBox::extraContentComponent
        This property lets you add some extra component on the trailing side (like a button)
    */
    property Component extraContentComponent

    background: Rectangle {
        radius: 8
        opacity: 0.5
        border.color: root.borderColor
        color: "transparent"
        Rectangle {
            anchors.fill: parent
            color: root.bgColor
            radius: 8
            opacity: 0.2
        }
    }

    contentItem: RowLayout {
        spacing: 8
        StatusIcon {
            Layout.alignment: root.iconAlignment
            icon: root.icon
            color: root.iconColor
        }
        Loader {
            Layout.fillWidth: true
            sourceComponent: root.isRowLayout ? rowLayoutComponent : columnLayoutComponent
        }
    }

    Component {
        id: rowLayoutComponent
        RowLayout {
            StatusBaseText {
                id: warningText
                Layout.fillWidth: true
                text: root.text
                wrapMode: Text.WordWrap
                font.pixelSize: root.textSize
                color: root.textColor
            }
            Loader {
                sourceComponent: extraContentComponent
            }
        }
    }

    Component {
        id: columnLayoutComponent
        ColumnLayout {
            StatusBaseText {
                id: warningText
                Layout.fillWidth: true
                text: root.text
                wrapMode: Text.WordWrap
                font.pixelSize: root.textSize
                color: root.textColor
            }
            Loader {
                sourceComponent: extraContentComponent
            }
        }
    }
}
