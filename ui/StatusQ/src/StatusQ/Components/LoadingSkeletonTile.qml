import QtQuick

import StatusQ.Core.Theme

/*!
   \qmltype LoadingSkeletonTile
   \inherits Rectangle
   \inqmlmodule StatusQ.Components
   \since StatusQ.Components 0.1
   \brief A plain skeleton shape, meant to be arranged inside a
   LoadingSkeletonGroup which provides the shared shimmer.
*/
Rectangle {
    color: Theme.palette.statusLoadingHighlight
    radius: 4
}
