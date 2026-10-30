import QtQuick

import StatusQ
import StatusQ.Core.Theme

/*!
   \qmltype LoadingSkeletonTile
   \inherits SkeletonTileItem
   \inqmlmodule StatusQ.Components
   \since StatusQ.Components 0.1
   \brief A rounded skeleton shape with a shimmer sweep, drawn in a single
   pass without offscreen layers.

   Inside a LoadingSkeletonGroup the sweep runs across the whole group,
   otherwise across the tile itself. All tiles share one clock, so a tile that
   appears later stays in step with the band.

   Nothing is drawn under the software scene graph; there is no fallback, as
   the app never selects it.

   Only \c color and \c radius are meant to be set; \c sweepOrigin, \c sweepSize
   and \c highlightColor are internal shader inputs.
*/
SkeletonTileItem {
    id: root

    color: Theme.palette.statusLoadingHighlight
    highlightColor: Theme.palette.statusLoadingHighlight2

    // position and size of the area the sweep travels across
    sweepOrigin: {
        if (!d.group)
            return Qt.point(0, 0)
        let x = 0
        let y = 0
        for (let p = root; p && p !== d.group; p = p.parent) {
            x += p.x
            y += p.y
        }
        return Qt.point(x, y)
    }
    sweepSize: d.group ? Qt.size(d.group.width, d.group.height)
                       : Qt.size(width, height)

    QtObject {
        id: d

        readonly property LoadingSkeletonGroup group: {
            for (let p = root.parent; p; p = p.parent) {
                if (p instanceof LoadingSkeletonGroup)
                    return p
            }
            return null
        }
    }
}
