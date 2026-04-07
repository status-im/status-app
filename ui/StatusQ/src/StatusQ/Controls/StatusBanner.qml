pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme

/*!
   \qmltype StatusBanner
   \inherits Column
   \inqmlmodule StatusQ.Controls
   \since StatusQ.Controls 0.1
   \brief It displays a banner with a custom text, size and type.  Inherits \l{https://doc.qt.io/qt-5/qml-qtquick-column.html}{Column}.

   The \c StatusBanner displays a banner with a custom text, size and type (Info, Danger, Success or Warning).

   Example of how the control looks like:
   \image status_banner.png

   Example of how to use it:

   \qml
        StatusBanner {
            width: parent.width
            visible: popup.userIsBlocked
            type: StatusBanner.Type.Danger
            statusText: qsTr("Blocked")
        }
   \endqml

   For a list of components available see StatusQ.
*/
Column {
    id: statusBanner

    /*!
       \qmlproperty string StatusBanner::statusText
       This property holds the text the banner will display.
    */
    property string statusText
    /*!
       \qmlproperty int StatusBanner::type
       This property holds type of banner. Possible values are:
       \qml
        enum Type {
            Info, // 0
            Danger, // 1
            Success, // 2
            Warning // 3
        }
        \endqml
    */
    property int type: StatusBanner.Type.Info
    /*!
       \qmlproperty int StatusBanner::textPixels
       This property holds the pixels size of the text inside the banner.
    */
    property int textPixels: Theme.primaryTextFontSize
    /*!
       \qmlproperty int StatusBanner::statusBannerHeight
       This property holds the height of the banner rectangle.
    */
    property int statusBannerHeight: 38

    // "private" properties
    QtObject {
           id: d
           property color backgroundColor
           property color bordersColor
           property color fontColor
    }

    enum Type {
        Info, // 0
        Danger, // 1
        Success, // 2
        Warning // 3
    }    

    width: parent.width

    // Component definition
    Rectangle {
        id: topDiv
        color: d.bordersColor
        height: 1
        width: parent.width
    }

    Rectangle {
        id: box
        width: parent.width
        height: statusBanner.statusBannerHeight
        color: d.backgroundColor

        StatusBaseText {
            id: statusTxt
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: statusBanner.textPixels
            elide: Text.ElideRight
            text: statusBanner.statusText
            color: d.fontColor
        }
    }

    Rectangle {
        id: bottomDiv
        color: d.bordersColor
        height: 1
        width: parent.width
    }

    // Behavior
    states: [
        State {
            when: statusBanner.type === StatusBanner.Type.Info
            PropertyChanges { target: d; backgroundColor: Theme.palette.primaryColor3}
            PropertyChanges { target: d; bordersColor: Theme.palette.primaryColor2}
            PropertyChanges { target: d; fontColor: Theme.palette.primaryColor1}
        },
        State {
            when: statusBanner.type === StatusBanner.Type.Danger
            PropertyChanges { target: d; backgroundColor: Theme.palette.dangerColor3}
            PropertyChanges { target: d; bordersColor: Theme.palette.dangerColor2}
            PropertyChanges { target: d; fontColor: Theme.palette.dangerColor1}
        },
        State {
            when: statusBanner.type === StatusBanner.Type.Success
            PropertyChanges { target: d; backgroundColor: Theme.palette.successColor2}
            PropertyChanges { target: d; bordersColor: Theme.palette.successColor2}
            PropertyChanges { target: d; fontColor: Theme.palette.successColor1}
        },
        State {
            when: statusBanner.type === StatusBanner.Type.Warning
            PropertyChanges { target: d; backgroundColor: Theme.palette.warningColor3}
            PropertyChanges { target: d; bordersColor: Theme.palette.warningColor2}
            PropertyChanges { target: d; fontColor: Theme.palette.warningColor1}
        }
    ]
}
