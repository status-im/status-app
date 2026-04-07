pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme

/*!
   \qmltype StatusTabBar
   \inherits TabBar
   \inqmlmodule StatusQ.Controls
   \since StatusQ.Controls 0.1
   \brief StatusTabBar provides a tab-based navigation model

   It's customized from Qt's \l{https://doc.qt.io/qt-5/qml-qtquick-controls2-tabbar.html}{TabBar},
   adding a transparent background.
*/

TabBar {
   id: root

    spacing: Theme.bigPadding

    background: null

    contentItem: ListView {
        model: root.contentModel
        currentIndex: root.currentIndex
        clip: true
        spacing: root.spacing
        orientation: ListView.Horizontal
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.AutoFlickIfNeeded
        snapMode: ListView.SnapToItem
    }
}
