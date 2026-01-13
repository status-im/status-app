import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

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
        \qmlproperty Item StatusSectionLayout::leftFloatingPanelItem
        This property holds the left floating panel of the component.
    */
    property Item leftFloatingPanelItem
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
        \qmlproperty int StatusSectionLayout::headerPadding
        This property sets the padding for the header component
        Default value is Theme.halfPadding.
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
        \qmlsignal
        This signal is emitted when the back button of the header component
        is pressed.
    */
    signal backButtonClicked()

    /*!
        \qmlsignal
        This signal is emitted when the floating panel has been automatically closed.
    */
    signal floatingPanelAutoClosed()

    /*!
        \qmlmethod StatusSectionLayout::openFloatingPanel()
        This method is used to open left floating panel modal.
    */
    function openFloatingPanel()  {
        floatingPopup.open()
    }
    /*!
        \qmlmethod StatusSectionLayout::closeFloatingPanel()
        This method is used to close left floating panel modal.
    */
    function closeFloatingPanel() {
        floatingPopup.close()
    }

    QtObject {
        id: d
        // Cache wrapper items removed from the swipe view
        property list<Item> items: []

        function handleBackAction() {
            if (!!root.backButtonName) {
                root.backButtonClicked()
                return
            }

            if (root.currentIndex > 0) {
                root.currentIndex--
            }
        }
    }

    Keys.onPressed: function(e) {
        if (e.key === Qt.Key_Back && root.currentIndex > 0) {
            e.accepted = true
            d.handleBackAction()
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
            if (!inView && !!parent) {
                d.items.push(root.takeItem(baseProxyPanel.implicitIndex));
            } else if (inView && !parent) {
                root.insertItem(implicitIndex, baseProxyPanel)
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
        id: leftPanelProxy
        backgroundColor: Theme.palette.baseColor4
        implicitIndex: 0
        inView: !!root.leftPanel
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
            LayoutItemProxy {
                id: centerPanelProxy
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.row: 1
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
            LayoutItemProxy {
                id: rightPanelProxy
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }

    component BaseToolBar: StatusToolBar {
        visible: root.showHeader
        padding: root.headerPadding
        backButtonVisible: root.currentIndex !== 0
        onBackButtonClicked: d.handleBackAction()
    }

    // --------------------------------------------------------------
    // Floating overlay: Just a bottom sheet popup.
    // Open/close is driven from outsite of the component.
    // --------------------------------------------------------------
    StatusDialog {
        id: floatingPopup
        parent: Overlay.overlay
        modal: true
        focus: true

        padding: 0
        margins: 0
        bottomPadding: 0
        topPadding: 0

        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
        fillHeightOnBottomSheet: true

        width: root.width
        height: root.height - 2 * Theme.padding

        header: null
        footer: null
        contentItem: LayoutItemProxy { target: root.leftFloatingPanelItem }

        onClosed: root.floatingPanelAutoClosed()
    }
}
