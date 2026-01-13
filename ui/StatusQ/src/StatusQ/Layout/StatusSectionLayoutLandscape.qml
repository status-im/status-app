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

        leftFloatingPanelItem: Item {
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
        \qmlproperty Item StatusSectionLayout::leftFloatingPanelItem
        This property holds the left floating panel of the component.
    */
    property Item leftFloatingPanelItem
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
    property alias rightPanel: rightPanelProxy.target
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
        \qmlproperty int StatusSectionLayout::headerPadding
        This property sets the padding for the header component
        Default value is Theme.halfPadding.
    */
    property int headerPadding: Theme.halfPadding

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

    /*!
        \qmlmethod StatusSectionLayout::openFloatingPanel()
        This method is used to open left floating panel triggering the needed animations and transitions.
    */
    function openFloatingPanel(isAnimated) {
        floatingPanel.openPanel(isAnimated)
    }
    /*!
        \qmlmethod StatusSectionLayout::closeFloatingPanel()
        This method is used to close left floating  panel triggering the needed animations and transitions.
    */
    function closeFloatingPanel() {
        floatingPanel.closeAnimated()
    }

    QtObject {
        id: d

        // Default width of the left panel in its collapsed state.
        readonly property int defaultLeftPanelWidth: 306

        // Width of the left panel when expanded while the floating panel is open.
        readonly property int extendedLeftPanelWidth: 344

        // Effective left panel width when the floating panel is closed and no real
        // leftPanel exists, allowing smooth center panel animation.
        readonly property int collapsedLeftPanelWidth: root.leftPanel ? d.defaultLeftPanelWidth : 0

        // Current left panel width used by the layout and animated by state changes.
        property int leftPanelWidth: d.defaultLeftPanelWidth

        // Whenever “floating panel is relevant”
        readonly property bool floatingPanelActive: (d.floatingPanelOpen || floatingPanel.y < floatingPanel.closedY())

        // Keeps the virtual left panel in the layout during collapse animations
        // to avoid abrupt center panel repositioning when no real leftPanel exists.
        property bool keepVirtualLeftPanel: false

        // Effective left panel used for geometry reference:
        // - If real leftPanel if provided
        // - else virtualLeftPanel while floating is active
        property Item effectiveLeftPanel: root.leftPanel ? root.leftPanel
                                                         : (d.keepVirtualLeftPanel ? virtualLeftPanel : null)

        // State
        property bool floatingPanelOpen: false
    }

    // ------------------------------------------------------------------------------------
    // Main SplitView layout: displays a three column layout with a
    // header in the central panel to be used as the base layout of all application
    // ------------------------------------------------------------------------------------
    SplitView {
        anchors.fill: parent
        handle: root.handle

        // Use effectiveLeftPanel so geometry exists when leftPanel == null but floating is active
        Control {
            id: leftPanelSlot
            SplitView.minimumWidth: !!d.effectiveLeftPanel ? d.leftPanelWidth : 0
            SplitView.preferredWidth: !!d.effectiveLeftPanel ? d.leftPanelWidth : 0
            SplitView.fillHeight: !!d.effectiveLeftPanel
            background: Rectangle {
                color: Theme.palette.baseColor4
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
                    id: headerBackgroundSlot
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
                        id: headerContentProxy
                        target: root.headerContent
                    }
                    onBackButtonClicked: root.backButtonClicked()
                }

                LayoutItemProxy {
                    id: centerPanelProxy
                    width: parent.width
                    anchors.top: statusToolBar.bottom
                    anchors.bottom: footerSlot.top
                    anchors.bottomMargin: !!root.footer ? Theme.halfPadding : 0
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
                color: Theme.palette.baseColor4
            }
            contentItem: LayoutItemProxy {
                id: rightPanelProxy
                target: root.rightPanel
            }
        }
    }

    // -------------------------------------------------------------------------------------------------------------
    // Virtual left panel is a real item in the scene graph.
    // It exists only to give geometry/anchor reference when no leftPanel is provided and floating panel is ac.
    // -------------------------------------------------------------------------------------------------------------
    Rectangle {
        id: virtualLeftPanel
        visible: d.keepVirtualLeftPanel && !root.leftPanel
        width: d.leftPanelWidth
        height: root.height
        color: root.backgroundColor
    }

    // --------------------------------------------------------------------------------------------------
    // Floating panel overlay (driven from outside openFloatingPanel / closeFloatingPanel)
    // --------------------------------------------------------------------------------------------------
    LayoutItemProxy {
        id: floatingPanel

        // State
        property bool openAnimationEnabled: true

        // Public API
        function openPanel(isAnimated)  {
            openAnimationEnabled = isAnimated
            if (!!root.leftFloatingPanelItem) {
                if (!root.leftPanel) d.keepVirtualLeftPanel = true
                d.floatingPanelOpen = true
            }
        }

        function closeAnimated() {
            d.floatingPanelOpen = false
        }

        // Helpers
        function leftPanelTopLeftInRoot() {
            const lp = d.effectiveLeftPanel
            return lp ? root.mapFromItem(lp, 0, 0) : Qt.point(0, 0)
        }

        function targetX() {
            const lp = d.effectiveLeftPanel
            if (!lp) return 0
            const p = leftPanelTopLeftInRoot()
            return p.x + lp.width - width - Theme.halfPadding
        }

        function targetY() {
            return Theme.halfPadding
        }

        function closedY() {
            return root.height
        }

        width: d.leftPanelWidth - Theme.halfPadding
        height: d.effectiveLeftPanel
                ? Math.min(root.height - Theme.halfPadding, d.effectiveLeftPanel.height - Theme.halfPadding)
                : (root.height - Theme.halfPadding)

        x: targetX()
        y: closedY()

        visible: d.floatingPanelOpen || y < closedY()
        target: root.leftFloatingPanelItem

        // State machine (controls `Y` and `leftPanelWidth`)
        states: [
            State {
                name: "open"
                when: d.floatingPanelOpen
                PropertyChanges { target: floatingPanel; y: floatingPanel.targetY() }
                PropertyChanges { target: d; leftPanelWidth: d.extendedLeftPanelWidth }
            },
            State {
                name: "closed"
                when: !d.floatingPanelOpen
                PropertyChanges { target: floatingPanel; y: floatingPanel.closedY() }
                PropertyChanges { target: d; leftPanelWidth: d.collapsedLeftPanelWidth }
            }
        ]

        // Animate `Y` and `leftPanelCollapsed`/ `leftPanelExpanded`
        transitions: [
            Transition {
                enabled: floatingPanel.openAnimationEnabled
                from: "closed"
                to: "open"
                NumberAnimation { properties: "y, leftPanelWidth"; duration: ThemeUtils.AnimationDuration.Slow; easing.type: Easing.OutCubic }
            },
            Transition {
                from: "open"
                to: "closed"
                SequentialAnimation {
                    NumberAnimation { properties: "y"; duration: ThemeUtils.AnimationDuration.Slow; easing.type: Easing.InCubic }
                    NumberAnimation { properties: "leftPanelWidth"; duration: ThemeUtils.AnimationDuration.Slow; easing.type: Easing.OutCubic }
                    ScriptAction {
                        script: {
                            if (!root.leftPanel)
                                d.keepVirtualLeftPanel = false
                        }
                    }
                }
            }
        ]
    }
}
