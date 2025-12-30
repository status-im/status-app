import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core.Theme

/*!
     \qmltype StatusSectionLayout
     \inherits LayoutChooser
     \inqmlmodule StatusQ.Layout
     \since StatusQ.Layout 0.1
     \brief Displays a three column layout in landscape mode or a three views swipeview in portrait mode, with a header in the central panel.
     Inherits \l{https://doc.qt.io/qt-6/qml-qtquick-controls2-splitview.html}{SplitView}.

     The \c StatusSectionLayout displays a three column layout in landscape mode or a three views swipeview in portrait mode, with a header in the central panel to be used as the base layout of all application
     sections.
     For example:

     \qml
    StatusSectionLayout {
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

LayoutChooser {
    id: root
    implicitWidth: ThemeUtils.portraitBreakpoint.width
    implicitHeight: ThemeUtils.portraitBreakpoint.height

    enum Panels {
        LeftPanel,
        CentralPanel,
        RightPanel
    }

    property Component handle: Item { }

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
        \qmlproperty Component StatusSectionLayout::rightPanel
        This property holds the right panel of the component.
    */
    property Item rightPanel
    /*!
        \qmlproperty Item StatusSectionLayout::navBar
        This property holds the navigation bar of the component. Usually displayed next to the leftPanel.
    */
    property Item navBar
    /*!
        \qmlproperty Item StatusSectionLayout::footer
        This property holds the footer of the component.
    */
    property Item footer
    /*!
        \qmlproperty Component StatusAppLayout::headerBackground
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
        \qmlproperty string StatusSectionLayout::backButtonName
        This property holds a reference to the backButtonName property of the
        header component.
    */
    property string backButtonName

    /*!
        \qmlproperty Item StatusSectionLayout::headerContent
        This property holds a reference to the custom header content of
        the header component.
    */
    property Item headerContent
    /*!
        \qmlproperty color StatusSectionLayout::backgroundColor
        This property holds color of the centeral component of
        the section
    */
    property color backgroundColor: Theme.palette.statusAppLayout.rightPanelBackgroundColor
    /*!
        \qmlproperty bool StatusSectionLayout::invertedLayout
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

    signal swiped(int previousIndex, int currentIndex)

    /*!
        \qmlmethod StatusSectionLayout::goToNextPanel()
        This method is used to focus the panel that needs to be active.
    */
    function goToNextPanel() {
        if (portraitView.visible)
            portraitView.incrementCurrentIndex()
    }

    function goToPreviousPanel() {
        if (portraitView.visible)
            portraitView.decrementCurrentIndex()
    }

    criteria: [
        root.height > root.width && root.width < root.implicitWidth, // Portrait mode
        true // Defaults to landscape mode
    ]

    layoutChoices: [
        portraitView,
        landscapeView
    ]

    StatusSectionLayoutLandscape {
        id: landscapeView
        anchors.fill: parent
        handle: root.handle
        leftPanel: root.leftPanel
        centerPanel: root.centerPanel
        rightPanel: root.rightPanel
        navBar: root.navBar
        footer: root.footer
        headerBackground: root.headerBackground
        showRightPanel: root.showRightPanel
        rightPanelWidth: root.rightPanelWidth
        showHeader: root.showHeader
        headerPadding: root.headerPadding
        showFooter: root.showFooter
        backButtonName: root.backButtonName
        headerContent: root.headerContent
        backgroundColor: root.backgroundColor

        onBackButtonClicked: root.backButtonClicked()
    }

    StatusSectionLayoutPortrait {
        id: portraitView
        anchors.fill: parent
        leftPanel: root.leftPanel
        centerPanel: root.centerPanel
        rightPanel: root.rightPanel
        navBar: root.navBar
        footer: root.footer
        headerBackground: root.headerBackground
        showRightPanel: root.showRightPanel
        rightPanelWidth: root.rightPanelWidth
        showHeader: root.showHeader
        headerPadding: root.headerPadding
        showFooter: root.showFooter
        backButtonName: root.backButtonName
        headerContent: root.headerContent
        backgroundColor: root.backgroundColor
        invertedLayout: root.invertedLayout

        property int currentIndexCache

        onCurrentIndexChanged: {
            root.swiped(currentIndexCache, currentIndex)
            currentIndexCache = currentIndex
        }

        onBackButtonClicked: root.backButtonClicked()

        Component.onCompleted: currentIndexCache = currentIndex
    }
}
