import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Components
import StatusQ.Core.Theme
/*!
     \qmltype StatusSectionLayoutLandscape
     \inherits SplitView
     \inqmlmodule StatusQ.Layout
     \since StatusQ.Layout 0.1
     \brief Displays a three column layout with a header in the central panel + floating panel.
     Inherits \l{https://doc.qt.io/qt-6/qml-qtquick-controls-control.html}{Control}.

     The \c StatusSectionLayoutLandscape displays a three column layout with a header in the central panel to be used as the base layout of all application
     sections.
     For example:

     \qml
    StatusSectionLayoutLandscape {
        id: root

        headerContent: RowLayout {
            ...
        }

        leftPanel: Item {
            ...
        }

        centerPanel: Item {
            ...
        }

        rightPanel: Item {
            ...
        }
     }
     \endqml

     For a list of components available see StatusQ.
*/

Control {
    id: root
    implicitWidth: 822
    implicitHeight: 600

    // Keep same “API surface” used by StatusSectionLayout.qml
    property Component handle: Item { }
    /*!
        \qmlproperty int StatusSectionLayoutLandscape::leftPanelWidthOverride
        This property provides an external override for the left panel width.

        When greater than 0, the layout uses this value to temporarily expand the
        left panel area. When set to 0, the override is cleared and the layout
        collapses the left panel back to its default width.
    */
    property int leftPanelWidthOverride: root.leftPanel ? d.defaultLeftPanelWidth : 0
    /*!
        \qmlproperty Item StatusSectionLayout::leftPanel
        This property holds the left panel of the component.
    */
    property Item leftPanel
    /*!
        \qmlproperty Item StatusSectionLayout::centerPanel
        This property holds the center panel of the component.
    */
    property Item centerPanel
    /*!
        \qmlproperty Item StatusSectionLayout::rightPanel
        This property holds the right panel of the component.
    */
    property Item rightPanel
    /*!
        \qmlproperty Item StatusSectionLayout::footer
        This property holds the footer of the component.
    */
    property Item footer
    /*!
        \qmlproperty Item StatusAppLayout::headerBackground
        This property holds the headerBackground of the component.
    */
    property Item headerBackground
    /*!
        \qmlproperty bool StatusSectionLayout::showRightPanel
        This property sets the right panel component's visibility to true/false.
        Default value is false.
    */
    property bool showRightPanel: false

    /*!
        \qmlproperty int StatusSectionLayout::rightPanelWidth
        This property sets the right panel component's width.
        Default value is 250.
    */
    property int rightPanelWidth: 250
    /*!
        \qmlproperty bool StatusSectionLayout::showHeader
        This property sets the header component's visibility to true/false.
        Default value is true.
    */
    property bool showHeader: true

    /*!
        \qmlproperty bool StatusSectionLayout::showFooter
        This property sets the footer component's visibility to true/false.
        Default value is true.
    */
    property bool showFooter: true

    /*!
        \qmlproperty real StatusSectionLayout::headerPadding
        This property sets the padding for the header component
        Default value is Theme.halfPadding.
    */
    property real headerPadding: Theme.halfPadding

    /*!
        \qmlproperty alias StatusSectionLayout::backButtonName
        This property holds a reference to the backButtonName property of the
        header component.
    */
    property alias backButtonName: statusToolBar.backButtonName

    /*!
        \qmlproperty Item StatusSectionLayout::headerContent
        This property holds a reference to the custom header content of
        the header component.
    */
    property Item headerContent

    /*!
        \qmlproperty color StatusSectionLayoutLandscape::backgroundColor
        This property holds color of the centeral component of
        the section
    */
    property color backgroundColor: Theme.palette.statusAppLayout.rightPanelBackgroundColor

    /*!
        \qmlsignal
        This signal is emitted when the back button of the header component
        is pressed.
    */
    signal backButtonClicked()

    QtObject {
        id: d

        // Default width of the left panel in its collapsed state.
        readonly property int defaultLeftPanelWidth: 306

        // Effective left panel used for geometry reference:
        // - If real leftPanel if provided
        // - else virtualLeftPanel while leftPanelWidth is provided
        readonly property Item effectiveLeftPanel: root.leftPanel ? root.leftPanel
                                                                  : (root.leftPanelWidthOverride != 0 ? virtualLeftPanel : null)

        // Resolved left panel width used by the layout, taking overrides into account.
        property int effectiveLeftPanelWidth: root.leftPanelWidthOverride != 0 ? root.leftPanelWidthOverride :
                                                                                 (root.leftPanel ? d.defaultLeftPanelWidth : 0)

        Behavior on effectiveLeftPanelWidth {
            NumberAnimation {
                duration: ThemeUtils.AnimationDuration.Slow
                easing.type: Easing.InOutCubic
            }
        }
    }

    // ------------------------------------------------------------------------------------
    // Main SplitView layout: displays a three column layout with a
    // header in the central panel to be used as the base layout of all application
    // ------------------------------------------------------------------------------------
    SplitView {
        id: splitView
        anchors.fill: parent
        handle: root.handle

        // Use effectiveLeftPanel so geometry exists when leftPanel == null but a leftPanelWidth value is provided
        Control {
            id: leftPanelSlot
            SplitView.preferredWidth: d.effectiveLeftPanelWidth
            SplitView.fillHeight: true
            background: Rectangle {
                color: root.Theme.palette.baseColor4
            }
            contentItem: LayoutItemProxy {
                target: d.effectiveLeftPanel
            }
        }

        Control {
            SplitView.minimumWidth: !!root.centerPanel ? 300 : 0
            SplitView.fillWidth: !!root.centerPanel
            SplitView.fillHeight: !!root.centerPanel
            background: Rectangle {
                color: root.backgroundColor
            }

            contentItem: Item {
                LayoutItemProxy {
                    anchors.top: parent.top
                    width: parent.width
                    target: root.headerBackground
                }

                StatusToolBar {
                    id: statusToolBar
                    anchors.top: parent.top
                    width: visible ? parent.width : 0
                    height: visible ? implicitHeight : 0
                    visible: root.showHeader
                    padding: root.headerPadding
                    backButtonName: root.backButtonName
                    headerContent: LayoutItemProxy {
                        target: root.headerContent
                    }
                    onBackButtonClicked: root.backButtonClicked()
                }

                LayoutItemProxy {
                    id: centerPanelProxy
                    width: parent.width
                    anchors.top: statusToolBar.bottom
                    anchors.bottom: footerSlot.top
                    anchors.bottomMargin: footerSlot.visible ? Theme.halfPadding : 0
                    target: root.centerPanel
                }

                LayoutItemProxy {
                    id: footerSlot
                    width: parent.width
                    height: visible ? implicitHeight : 0
                    anchors.bottom: parent.bottom
                    target: root.footer
                    visible: root.showFooter && !!target
                }
            }
        }

        Control {
            SplitView.preferredWidth: root.showRightPanel ? root.rightPanelWidth : 0
            SplitView.minimumWidth: root.showRightPanel ? 58 : 0
            opacity: root.showRightPanel ? 1.0 : 0.0
            visible: (opacity > 0.1)
            background: Rectangle {
                color: root.Theme.palette.baseColor4
            }
            contentItem: LayoutItemProxy {
                target: root.rightPanel
            }
        }
    }

    // -------------------------------------------------------------------------------------------------------------
    // Virtual left panel is a real item in the scene graph.
    // It exists only to give geometry/anchor reference when no leftPanel is provided but there's a need
    // of expanding the left panel area
    // -------------------------------------------------------------------------------------------------------------
    Rectangle {
        id: virtualLeftPanel
        visible: !root.leftPanel && root.leftPanelWidthOverride != 0
        width: root.leftPanelWidthOverride
        height: root.height
        color: Theme.palette.baseColor4
    }
}
