import QtQuick
import QtQuick.Layouts

import AppLayouts.Chat.views
import StatusQ.Components
import StatusQ.Core.Theme
import shared

Item {
    id: root

    property bool showMembersPanel: false

    QtObject {
        id: d

        readonly property bool isPortrait: d.windowWidth < d.windowHeight
        readonly property bool showLeftPanel: !d.isPortrait
        readonly property bool showMembersPanel: root.showMembersPanel && !d.isPortrait
        readonly property int panelPadding: root.Theme.padding
        readonly property int sectionInset: root.Theme.padding + root.Theme.halfPadding
        readonly property int sectionSpacing: root.Theme.padding
        readonly property int compactSpacing: root.Theme.halfPadding
        readonly property int windowWidth: root.parent?.Window?.width ?? Screen.width
        readonly property int windowHeight: root.parent?.Window?.height ?? Screen.height
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Chat list panel
        Rectangle {
            visible: d.showLeftPanel
            Layout.fillHeight: true
            Layout.minimumWidth: d.showLeftPanel ? 250 : 0
            Layout.preferredWidth: d.showLeftPanel ? 290 : 0
            Layout.maximumWidth: d.showLeftPanel ? 340 : 0
            color: Theme.palette.secondaryMenuBackground

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: d.panelPadding
                spacing: d.sectionSpacing

                // Chat list header
                LoadingComponent {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    radius: 8
                }

                // Chat list items
                Repeater {
                    model: 14
                    delegate: RowLayout {
                        spacing: d.compactSpacing

                        LoadingComponent {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 15
                        }

                        LoadingComponent {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            radius: 6
                        }
                    }
                }
            }
        }

        // Chat content panel
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.palette.statusAppLayout.backgroundColor

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Chat header
                LoadingComponent {
                    Layout.preferredWidth: 270
                    Layout.preferredHeight: 35
                    Layout.alignment: Qt.AlignVCenter
                    radius: 6
                    Layout.leftMargin: d.sectionInset
                    Layout.topMargin: d.compactSpacing
                }

                // Chat Content
                MessagesLoadingView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: d.sectionInset
                    Layout.topMargin: d.compactSpacing
                }

                // ChatInput
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: fakeInput.height + Theme.smallPadding * 2

                    LoadingComponent {
                        id: fakeInput
                        anchors.centerIn: parent
                        width: parent.width - (2 * d.sectionInset)
                        height: 35
                        radius: 17
                    }
                }
            }
        }

        // Members Panel
        Rectangle {
            visible: d.showMembersPanel
            Layout.fillHeight: true
            Layout.minimumWidth: d.showMembersPanel ? 250 : 0
            Layout.preferredWidth: d.showMembersPanel ? 280 : 0
            Layout.maximumWidth: d.showMembersPanel ? 330 : 0
            color: Theme.palette.secondaryMenuBackground

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: d.panelPadding
                spacing: d.sectionSpacing

                // Members Header
                LoadingComponent {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: 6
                }

                // Members list
                Repeater {
                    model: 12
                    delegate: RowLayout {
                        spacing: d.compactSpacing

                        LoadingComponent {
                            width: 34
                            height: 34
                            radius: 17
                        }

                        LoadingComponent {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: 8

                            LoadingComponent {
                                width: parent.width - (2 * d.compactSpacing)
                                height: 12
                                anchors.centerIn: parent
                                radius: 4
                            }
                        }
                    }
                }
            }
        }
    }
}
