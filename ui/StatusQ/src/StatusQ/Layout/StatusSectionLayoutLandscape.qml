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
     \brief Displays a three column layout with a header in the central panel.
     Inherits \l{https://doc.qt.io/qt-6/qml-qtquick-controls2-splitview.html}{SplitView}.

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

SplitView {
    id: root
    implicitWidth: 822
    implicitHeight: 600

    handle: Item { }

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
        \qmlproperty alias StatusSectionLayout::headerContent
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

    Control {
        id: navBarControl
        SplitView.preferredWidth: (!!navBar) ? navBar.implicitWidth : 0
        SplitView.fillHeight: (!!navBar)
        background: Rectangle {
            color: Theme.palette.baseColor4
        }
        contentItem: LayoutItemProxy {
            target: root.navBar
        }
    }

    Control {
        SplitView.minimumWidth: (!!leftPanel) ? 304 : 0
        SplitView.preferredWidth: (!!leftPanel) ? 304 : 0
        SplitView.fillHeight: (!!leftPanel)
        background: Rectangle {
            color: Theme.palette.baseColor4
        }
        contentItem: LayoutItemProxy {
            target: root.leftPanel
        }
    }

    Control {
        SplitView.minimumWidth: (!!centerPanel) ? 300 : 0
        SplitView.fillWidth: (!!centerPanel)
        SplitView.fillHeight: (!!centerPanel)
        background: Rectangle {
            color: root.backgroundColor
        }
        contentItem: Item {
            LayoutItemProxy {
                id: headerBackgroundSlot
                anchors.top: parent.top
                // Needed cause I see a gap otherwise
                anchors.topMargin: -3
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
                headerContent: LayoutItemProxy {
                    id: headerContentProxy
                    target: root.headerContent
                }
                onBackButtonClicked: {
                    root.backButtonClicked();
                }
            }
            LayoutItemProxy {
                id: centerPanelProxy
                width: parent.width
                anchors.top: statusToolBar.bottom
                anchors.bottom: footerSlot.top
                anchors.bottomMargin: footerSlot.visible ? 8 : 0
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
        }
    }
}
