import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Layout

Page {
    id: root

    header: ToolBar {
        id: toolbar
        width: parent.width
        Flow {
            anchors.fill: parent
            spacing: 5
            ComboBox {
                id: layoutChooser
                model: ["landscape", "portrait"]
                currentIndex: 0
            }
            CheckBox {
                id: leftPanelCheckBox
                text: "Show Left Panel"
                checked: true
            }
            CheckBox {
                id: centerPanelCheckBox
                text: "Show Center Panel"
                checked: true
            }
            CheckBox {
                id: rightPanelCheckBox
                text: "Show Right Panel"
                checked: true
            }
            CheckBox {
                id: inverted
                text: "Inverted"
                checked: true
            }
            Button {
                text: "Next Panel"
                onClicked: sectionLayout.goToNextPanel()
            }
        }
    }

    Page {
        id: leftPanel
        objectName: "leftPanel"
        title: "Left Panel"
        implicitWidth: 200
        implicitHeight: 400
        Rectangle {
            color: "red"
            anchors.fill: parent
        }
        Label {
            text: "This is the left panel"
            anchors.centerIn: parent
        }
    }

    Page {
        id: centerPanel
        objectName: "centerPanel"
        title: "Center Panel"
        implicitWidth: 400
        implicitHeight: 400
        Rectangle {
            color: "blue"
            anchors.fill: parent
        }
        Label {
            text: "This is the center panel"
            anchors.centerIn: parent
        }
    }
    Page {
        id: rightPanel
        title: "Right Panel"
        implicitWidth: 200
        implicitHeight: 400
        Rectangle {
            color: "green"
            anchors.fill: parent
        }
        Label {
            text: "This is the right panel"
            anchors.centerIn: parent
        }
    }

    Page {
        id: navBarItem
        implicitWidth: 78
        Rectangle {
            color: "yellow"
            anchors.fill: parent
            Label {
                text: "NavBar"
                anchors.centerIn: parent
            }
        }
    }

    Page {
        id: footerItem
        implicitWidth: 400
        implicitHeight: 50
        Rectangle {
            color: "gray"
            anchors.fill: parent
            Label {
                text: "Footer Content"
                anchors.centerIn: parent
            }
        }
    }

    ToolBar {
        id: headerContent
        RowLayout {
            anchors.fill: parent
            spacing: 5
            Button { text: "Action 1" }
            Button { text: "Action 2" }
        }
    }

    Frame {
        id: wrapper
        width: layoutChooser.currentValue === "portrait" ? 400 : 800
        height: layoutChooser.currentValue === "portrait" ? 800 : 400
        anchors.centerIn: parent
        contentItem: StatusSectionLayout {
            id: sectionLayout
            clip: true
            implicitWidth: 800
            implicitHeight: 400
            invertedLayout: inverted.checked
            leftPanel: leftPanelCheckBox.checked ? leftPanel : null
            centerPanel: centerPanelCheckBox.checked ? centerPanel : null
            rightPanel: rightPanel
            showRightPanel: rightPanelCheckBox.checked
            footer: footerItem
            headerContent: headerContent
            headerBackground: Control {
                implicitHeight: 115

                contentItem: Loader {
                    sourceComponent: Rectangle {
                                id: headerBackground
                                color: "yellow"
                                width: 300
                                height: 50
                                onHeightChanged: console.trace()
                        }
                    }
                }
            }
        }
    }
