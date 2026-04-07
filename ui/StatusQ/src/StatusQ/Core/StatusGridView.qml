pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

/*!
   \qmltype StatusGridView
   \inherits GridView
   \inqmlmodule StatusQ.Core
   \since StatusQ.Core 0.1
   \brief GridView wrapper with tuned scrolling and custom scrollbars.

   The \c StatusGridView can be used just like a plain GridView.

   Example of how to use it:

   \qml
        StatusGridView {
            id: GridView
            anchors.fill: parent
            model: someModel

            delegate: DelegateItem {
                ...
            }
        }
   \endqml

   For a Grid of components available see StatusQ.
*/
GridView {
    id: root

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    maximumFlickVelocity: 2000
    synchronousDrag: true
}
