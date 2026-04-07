pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core.Theme

import "private"

/*!
   \qmltype StatusDotsLoadingIndicator
   \inherits Control
   \inqmlmodule StatusQ.Components
   \since StatusQ.Components 0.1
   \brief It is a 3 dots loading animation.

   The \c StatusDotsLoadingIndicator displays 3 dots blinking animation.

   Example of how the control looks like:
   \image status_dots_loading_indicator.png

   Example of how to use it:

   \qml
        StatusDotsLoadingIndicator {
            dotsDiameter: 5
            duration: 1000
            dotsColor: "orange"
        }
   \endqml

   For a list of components available see StatusQ.
*/
Control {
    id: root

    /*!
       \qmlproperty string StatusDotsLoadingIndicator::dotsDiameter
       This property holds the diameter of the dots.
    */
    property double dotsDiameter: 4.5

    /*!
       \qmlproperty string StatusDotsLoadingIndicator::duration
       This property holds the duration of the animation in milliseconds
    */
    property int duration: 1500

    /*!
       \qmlproperty string StatusDotsLoadingIndicator::dotsColor
       This property holds the color of the dots.
    */
    property color dotsColor: Theme.palette.baseColor1

    QtObject {
        id: d

        readonly property double opacity1: 1
        readonly property double opacity2: 0.6
        readonly property double opacity3: 0.2
    }

    spacing: 2

    contentItem: RowLayout {
        spacing: root.spacing

        LoadingDotItem { dotsDiameter: root.dotsDiameter; duration: root.duration; dotsColor: root.dotsColor; maxOpacity: d.opacity1 }
        LoadingDotItem { dotsDiameter: root.dotsDiameter; duration: root.duration; dotsColor: root.dotsColor; maxOpacity: d.opacity2 }
        LoadingDotItem { dotsDiameter: root.dotsDiameter; duration: root.duration; dotsColor: root.dotsColor; maxOpacity: d.opacity3 }
    }
}
