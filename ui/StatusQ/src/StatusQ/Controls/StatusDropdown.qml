import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Controls as QC
import QtQml

import StatusQ.Core.Theme

/*!
   \qmltype StatusDropdown
   \inherits Popup
   \inqmlmodule StatusQ.Controls
   \since StatusQ.Controls 0.1
   \brief The StatusDropdown provides a template for creating dropdowns.

   NOTE: Each consumer needs to set the x and y postion of the dropdown.

   Example of how to use it:

   \qml
        StatusDropdown {
            x: root.x + margins
            y: root.y + margins
            contentItem: ColumnLayout {
                ...
            }
        }
   \endqml

   For a list of components available see StatusQ.
*/
QC.Popup {
    id: root

    /*!
        \qmlproperty bool StatusDropdown::bottomSheetAllowed
        Controls whether the dropdown may switch to a bottom-sheet presentation when vertical
        space is limited. Set to false to force classic anchored dropdown behavior.
        Default: true.
    */
    property bool bottomSheetAllowed: true
    /*!
        \qmlproperty Item StatusDropdown::directParent
        The visual parent (an Item) used for anchoring/positioning when NOT in bottom-sheet mode.
        Required.
    */
    required property Item directParent
    /*!
        \qmlproperty real StatusDropdown::relativeX
        Horizontal offset applied relative to \c directParent in classic dropdown mode.
        Useful for left/right alignment nudges after mapping coordinates into the parent space.
        Default: 0.
    */
    property real relativeX: 0
    /*!
        \qmlproperty real StatusDropdown::relativeY
        Vertical offset applied relative to \c directParent in classic dropdown mode.
        Typical usage is to open below the anchor by mapping the anchor’s height, then adding
        this offset. Ignored in bottom-sheet mode.
        Default: 0.
    */
    property real relativeY: 0
    /*!
        \qmlproperty bool StatusDropdown::bottomSheet
        Read-only flag indicating whether the dropdown should present as a bottom sheet.
        True when:
          - \c bottomSheetAllowed is true, and
          - the window is in portrait (\c d.windowHeight > d.windowWidth), and
          - the window width is at or below \c ThemeUtils.portraitBreakpoint.width.
        Otherwise false. Used to switch layout/parenting to a full-width, bottom-anchored sheet.
    */
    readonly property bool bottomSheet: !bottomSheetAllowed ? false:
                                            d.windowHeight > d.windowWidth
                                            && d.windowWidth <= ThemeUtils.portraitBreakpoint.width

    /*!
       \qmlproperty bool fillHeightOnBottomSheet
        This property decides the height of the dialog when `bottomSheet` is active:
          * If active: it fills the 90% of the screen viewport.
          * If not active: the height is the minimum value between the implicitHeight and the 90% of the screen viewport.
    */
    property bool fillHeightOnBottomSheet: false

    QtObject {
       id: d
       readonly property var window: root.contentItem.Window.window
       readonly property int windowWidth: window ? window.width: Screen.width
       readonly property int windowHeight: window ? window.height: Screen.height

       // Set to 85% since some dropdowns are opened as children of Status dialogs.
       // Keeping a small gap at the top lets users tap to return to the underlying dialog
       // instead of closing the entire flow.
       readonly property real bottomSheetHeightRatio: 0.85
    }

    // workaround for QTBUG-142248
    Binding on contentItem {
        Theme.style: root.Theme.style
        Theme.padding: root.Theme.padding
        Theme.fontSizeOffset: root.Theme.fontSizeOffset
    }

    Binding {
        when: !root.bottomSheet

        root {
            parent: root.directParent
            modal: false
            dim: false
            closePolicy: QC.Popup.CloseOnEscape | QC.Popup.CloseOnPressOutsideParent

            x: root.relativeX
            y: root.relativeY

            margins: Theme.halfPadding
        }
    }

    Binding {
        when: root.bottomSheet

        root {
            parent: QC.Overlay && QC.Overlay.overlay ? QC.Overlay.overlay:
                    d.window && d.window.contentItem ? d.window.contentItem : parent
            modal: true
            dim: true
            closePolicy: QC.Popup.CloseOnPressOutside

            x: 0
            y: d.windowHeight - height
            width: d.windowWidth
            height: root.fillHeightOnBottomSheet ? d.windowHeight * d.bottomSheetHeightRatio : Math.min(implicitHeight, d.windowHeight * d.bottomSheetHeightRatio)
            bottomPadding: !!d.window ? d.window.SafeArea.margins.bottom: 0
            margins: 0
        }
    }

    background: Rectangle {
       color: Theme.palette.statusMenu.backgroundColor
       radius: Theme.radius
       border.color: "transparent"
       layer.enabled: true
       layer.effect: DropShadow {
           source: root.background
           horizontalOffset: 0
           verticalOffset: 4
           radius: 12
           samples: 25
           spread: 0.2
           color: Theme.palette.dropShadow
       }
    }

    // workaround for https://bugreports.qt.io/browse/QTBUG-87804
    Binding on margins {
        id: workaroundBinding

        when: false
        restoreMode: Binding.RestoreBindingOrValue
    }

    onImplicitContentHeightChanged: {
        workaroundBinding.value = root.margins + 1
        workaroundBinding.when = true
        workaroundBinding.when = false
    }
}
