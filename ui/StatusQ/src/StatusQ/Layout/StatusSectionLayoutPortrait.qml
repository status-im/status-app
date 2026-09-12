import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog
import StatusQ.Core.Utils

/*!
     \qmltype StatusSectionLayoutPortrait
     \inherits SwipeView
     \inqmlmodule StatusQ.Layout
     \since StatusQ.Layout 0.1
     \brief Displays a three views swipe layout with a header in the central panel.
     Inherits \l{https://doc.qt.io/qt-6/qml-qtquick-controls2-splitview.html}{SplitView}.

     The \c StatusSectionLayoutPortrait displays a three views swipe layout with a header in the central panel to be used as the base layout of all application
     sections.
     For example:

     \qml
    StatusSectionLayoutPortrait {
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

SwipeView {
    id: root
    implicitWidth: 822
    implicitHeight: 600

    /*!
        \qmlproperty Item StatusSectionLayout::leftPanel
        This property holds the left panel of the component.
    */
    property alias leftPanel: leftPanelProxy.target
    /*!
        \qmlproperty Item StatusSectionLayout::centerPanel
        This property holds the center panel of the component.
    */
    property alias centerPanel: centerPanelProxy.target
    /*!
        \qmlproperty Item StatusSectionLayout::rightPanel
        This property holds the right panel of the component.
    */
    property alias rightPanel: rightPanelProxy.target
    /*!
        \qmlproperty Item StatusSectionLayout::footer
        This property holds the footer of the component.
    */
    property alias footer: footerProxy.target
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
        \qmlproperty int StatusSectionLayout::leftPadding
        This property sets the left padding for the component.

        Example:
        \qml
            leftPadding: Utils.swipeIndicatorWidth + Theme.halfPadding
        \endqml

        Default value is 0.
    */
    leftPadding: 0
    /*!
        \qmlproperty alias StatusSectionLayout::backButtonName
        This property holds a reference to the backButtonName property of the
        header component.
    */
    property alias backButtonName: statusToolBar.backButtonName

    /*!
        \qmlproperty alias StatusSectionLayout::headerContent
        This property holds a reference to the custom header content of
        the header component.
    */
    property Item headerContent
    /*!
        \qmlproperty color StatusSectionLayoutPortrait::backgroundColor
        This property holds color of the centeral component of
        the section
    */
    property color backgroundColor: Theme.palette.statusAppLayout.rightPanelBackgroundColor
    /*!
        \qmlproperty bool StatusSectionLayoutPortrait::invertedLayout
        This property sets the flow to  Footer - Center - Header
        when true, otherwise  Header - Center - Footer
    */
    property bool invertedLayout: false
    /*!
        \qmlproperty bool StatusSectionLayoutPortrait::panelsFrozen
        While true the panel slots stop tracking their box: each panel keeps the
        last geometry it was given. Raised by \l StatusSectionLayout for the
        duration of a geometry transition it did not initiate (a device
        rotation, an orientation swap), so a burst of host sizes costs one
        relayout of the panel subtree instead of one per size.
    */
    property bool panelsFrozen: false

    /*!
        \qmlproperty real StatusSectionLayoutPortrait::leftPanelSlotWidth
        \qmlproperty real StatusSectionLayoutPortrait::leftPanelSlotHeight
        The box the left panel slot will give its panel. Valid whether or not a
        panel has arrived, so a section that builds its panel before the chrome
        adopts it can pre-size it exactly and make the handoff resize-free.
    */
    readonly property real leftPanelSlotWidth: leftPanelProxy.width
    readonly property real leftPanelSlotHeight: leftPanelProxy.height
    /*!
        \qmlproperty real StatusSectionLayoutPortrait::centerPanelSlotWidth
        \qmlproperty real StatusSectionLayoutPortrait::centerPanelSlotHeight
        The box the centre panel slot will give its panel. Valid whether or not a
        panel has arrived, so a section that builds its panel before the chrome
        adopts it can pre-size it exactly and make the handoff resize-free.
    */
    readonly property real centerPanelSlotWidth: centerPanelProxy.width
    readonly property real centerPanelSlotHeight: centerPanelProxy.height
    /*!
        \qmlproperty real StatusSectionLayoutPortrait::rightPanelSlotWidth
        \qmlproperty real StatusSectionLayoutPortrait::rightPanelSlotHeight
        The box the right panel slot will give its panel. Valid whether or not a
        panel has arrived, so a section that builds its panel before the chrome
        adopts it can pre-size it exactly and make the handoff resize-free.
    */
    readonly property real rightPanelSlotWidth: rightPanelProxy.width
    readonly property real rightPanelSlotHeight: rightPanelProxy.height

    /*!
        \qmlsignal
        This signal is emitted when the back button of the header component
        is pressed.
    */
    signal backButtonClicked()

    /*!
        \qmlsignal StatusSectionLayoutPortrait::panelSwitchStarted()
        Emitted when a swipe between panels starts moving — the user drags,
        or the slide following a \c currentIndex change begins. Paired with
        \l panelSwitchEnded; consumers should defer expensive panel swaps
        (e.g. replacing a skeleton with the real panel) to the end signal,
        or the swap frame stutters the slide.
    */
    signal panelSwitchStarted()

    /*!
        \qmlsignal StatusSectionLayoutPortrait::panelSwitchEnded()
        Emitted when the swipe between panels settles on a page.
    */
    signal panelSwitchEnded()

    // Bound (not a function) so StatusSectionLayout.canGoBack stays reactive.
    readonly property bool canGoBackInternally: root.currentIndex > 0 || !!root.backButtonName

    QtObject {
        id: d
        // Cache wrapper items removed from the swipe view
        property list<Item> items: []

        // A switch is in flight while the user drags the view or while the
        // slide following a currentIndex change is off the target page.
        readonly property bool panelSwitchOngoing:
            root.contentItem.moving
            || (!!root.currentItem
                && Math.abs(root.contentItem.contentX - root.currentItem.x) > 0.5)

        onPanelSwitchOngoingChanged: {
            if (panelSwitchOngoing)
                root.panelSwitchStarted()
            else
                root.panelSwitchEnded()
        }

        // Where the page currently sits in the view, or -1 if it has been taken
        // out of it.
        function pageIndexOf(page) {
            for (let i = 0; i < root.count; ++i)
                if (root.itemAt(i) === page)
                    return i
            return -1
        }

        // Pages keep their declared order, so a page belongs after every
        // lower-numbered page that is currently in the view.
        function insertionIndexFor(page) {
            let at = 0
            for (let i = 0; i < root.count; ++i) {
                const other = root.itemAt(i)
                if (!!other && other.implicitIndex < page.implicitIndex)
                    ++at
            }
            return at
        }

        function handleBackAction() {
            if (!!root.backButtonName) {
                root.backButtonClicked()
                return
            }
            if (root.currentIndex > 0)
                root.currentIndex--
        }
    }

    Keys.onPressed: function(e) {
        if (e.key === Qt.Key_Back && root.canGoBackInternally) {
            e.accepted = true
            d.handleBackAction()
        }
    }

    function tryGoBack() {
        if (root.canGoBackInternally) {
            d.handleBackAction()
            return true
        }
        return false
    }

    onCurrentItemChanged: {
        if (currentItem) {
            currentItem.focus = true
            currentItem.forceActiveFocus()
        }
    }

    onVisibleChanged: {
         if (visible && currentItem) {
             currentItem.focus = true
             currentItem.forceActiveFocus()
         }
     }

    component BaseProxyPanel : Control {
        id: baseProxyPanel
        readonly property int index: SwipeView.index !== undefined ? SwipeView.index : -1

        property color backgroundColor
        property Item target: null
        property int implicitIndex
        property bool inView: true

        background: Rectangle {
            color: baseProxyPanel.backgroundColor || root.backgroundColor
        }
        onInViewChanged: {
            // If the panel is not in view, we need to remove it from the swipe view
            // and add it to the cache wrapper items so that we can restore it later if needed.
            //
            // Both positions are looked up rather than taken from implicitIndex:
            // SwipeView indices close up as pages come and go, so with no left
            // panel the right panel's page sits at index 1, and takeItem(2)
            // would silently leave it in the view.
            const at = d.pageIndexOf(baseProxyPanel)
            if (!inView && at >= 0) {
                d.items.push(root.takeItem(at));
            } else if (inView && at < 0) {
                root.insertItem(d.insertionIndexFor(baseProxyPanel), baseProxyPanel)
                d.items.splice(d.items.indexOf(this), 1);
            }
        }
        contentItem: RowLayout {
            spacing: 0
            LayoutItemProxy {
                Layout.fillWidth: true
                Layout.fillHeight: true
                target: baseProxyPanel.target
            }
        }
    }

    BaseProxyPanel {
        backgroundColor: Theme.palette.baseColor4
        implicitIndex: 0
        inView: !!root.leftPanel
        target: SectionPanelSlot {
            id: leftPanelProxy
            anchors.fill: parent
            frozen: root.panelsFrozen
        }
    }

    BaseProxyPanel {
        id: centerPanelBase
        backgroundColor: root.backgroundColor
        implicitIndex: 1
        inView: !!root.centerPanel

        target: GridLayout {
            objectName: "centerPanelLayout"
            anchors.fill: parent
            columns: 1
            rowSpacing: 0

            // Header
            Item {
                id: headerItem
                Layout.fillWidth: true
                implicitHeight: statusToolBar.implicitHeight
                Layout.row: root.invertedLayout ? 2 : 0

                LayoutItemProxy {
                    id: headerBackgroundProxy
                    anchors.fill: parent
                    target: root.headerBackground
                }
                BaseToolBar {
                    id: statusToolBar
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    headerContent: LayoutItemProxy {
                        id: headerContentProxy
                        target: root.headerContent
                    }
                }
            }

            // Central
            SectionPanelSlot {
                id: centerPanelProxy
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.row: 1
                frozen: root.panelsFrozen
                implicitHeight: centerPanel ? centerPanel.implicitHeight : 0
                implicitWidth: centerPanel ? centerPanel.implicitWidth : 0
            }

            // Footer
            LayoutItemProxy {
                id: footerProxy
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? implicitHeight : 0
                Layout.row: root.invertedLayout ? 0 : 2

                visible: root.showFooter && !!target
            }
        }
    }

    BaseProxyPanel {
        backgroundColor: Theme.palette.baseColor4
        implicitIndex: 2
        inView: !!root.rightPanel && root.showRightPanel
        target: ColumnLayout {
            objectName: "rightPanelLayout"
            anchors.fill: parent
            spacing: 0
            BaseToolBar {
                Layout.fillWidth: true
            }
            SectionPanelSlot {
                id: rightPanelProxy
                Layout.fillWidth: true
                Layout.fillHeight: true
                frozen: root.panelsFrozen
            }
        }
    }

    component BaseToolBar: StatusToolBar {
        visible: root.showHeader
        padding: root.headerPadding
        backButtonVisible: root.currentIndex !== 0
        onBackButtonClicked: d.handleBackAction()
    }
}
