import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme

/*!
     \qmltype StatusTagItem
     \inherits Control
     \inqmlmodule StatusQ.Controls
     \since StatusQ.Controls 0.1
     \brief Represents a tag item.
     Inherits \l{https://doc.qt.io/qt-5/qml-qtquick-controls2-control.html}{Control}.

     The \c StatusTagItem represents a tag item where a name and icon can be displayed and can be clicked.
     Example:

     \qml
        StatusTagItem {
            isReadonly: model.isReadonly
            text: model.name
            icon: model.tagIcon

            onClicked: { console.log("Tag selected!") }
        }
     \endqml

     For a list of components available see StatusQ.
  */
Control {
    id: root

    /*!
    \qmlproperty bool StatusTagItem::isReadonly
    This property sets if the tag is readonly or not.
*/
    property bool isReadonly
    /*!
    \qmlproperty string StatusTagItem::text
    This property sets the tag text to display.
*/
    property string text
    /*!
    \qmlproperty string StatusTagItem::icon
    This property sets the tag icon to display.
*/
    property string icon

    /*!
    \qmlproperty int StatusTagItem::elideMode
    This property sets elide mode for the text.
    */
    property int elideMode: Text.ElideRight

    /*!
    \qmlsignal
    This signal is emitted when the close button is clicked.
*/
    signal closed()

    QtObject {
        id: d
        readonly property int tagMargins: 8
        readonly property int tagIconsSize: 20

        function getTagColor(isReadonly) {
            if(isReadonly)
                return root.Theme.palette.baseColor1
            return root.hovered ? root.Theme.palette.miscColor1 : root.Theme.palette.primaryColor1
        }
    }

    implicitHeight: 30
    horizontalPadding: d.tagMargins
    font.pixelSize: Theme.primaryTextFontSize
    font.family: Fonts.baseFont.family

    background: Rectangle {
        color: d.getTagColor(root.isReadonly)
        radius: Theme.radius
    }

    contentItem: RowLayout {
        spacing: 2

        StatusIcon {
            Layout.preferredWidth: root.icon ? d.tagIconsSize : 0
            Layout.preferredHeight: d.tagIconsSize

            visible: root.icon
            color: Theme.palette.indirectColor1
            icon: root.icon
        }
        StatusBaseText {
            Layout.fillWidth: true

            color: Theme.palette.indirectColor1
            font: root.font
            text: root.text
            elide: root.elideMode
        }
        StatusIcon {
            Layout.leftMargin: d.tagMargins
            Layout.preferredWidth: d.tagIconsSize
            Layout.preferredHeight: d.tagIconsSize

            visible: !root.isReadonly
            color: Theme.palette.indirectColor1
            icon: "close"
            StatusMouseArea {
                enabled: !root.isReadonly
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: { root.closed() }
            }
        }
    }
}
