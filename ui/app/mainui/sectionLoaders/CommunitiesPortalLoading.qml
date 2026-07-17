import QtQuick
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core.Theme

Item {
    id: root

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillHeight: true
            Layout.minimumWidth: 250
            Layout.preferredWidth: 290
            Layout.maximumWidth: 340
            color: Theme.palette.secondaryMenuBackground

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.padding
                spacing: Theme.padding

                LoadingComponent {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 8
                }

                Repeater {
                    model: 7

                    delegate: LoadingComponent {
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredHeight: index === 0 ? 84 : 42
                        radius: 8
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.palette.statusAppLayout.backgroundColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.padding * 2
                spacing: Theme.padding

                LoadingComponent {
                    Layout.preferredWidth: 220
                    Layout.preferredHeight: 32
                    radius: 6
                }

                Repeater {
                    model: 4

                    delegate: RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 92
                        spacing: Theme.padding

                        LoadingComponent {
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 64
                            radius: 32
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.halfPadding

                            LoadingComponent {
                                Layout.preferredWidth: 180
                                Layout.preferredHeight: 18
                                radius: 4
                            }

                            LoadingComponent {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 14
                                radius: 4
                            }

                            LoadingComponent {
                                Layout.preferredWidth: 120
                                Layout.preferredHeight: 14
                                radius: 4
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}