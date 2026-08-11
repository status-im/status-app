import QtQuick
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core.Theme

// Loading placeholder mimicking the wallet center panel, proportions extracted
// from WalletAccountHeader (compact mode), the wallet tab bar and TokenDelegate:
// - header: title + balance (19px text, 26px line height) with a 38x38 reload
//   button, then dApps button and the 38px-tall network filter pill
// - tab bar row with the filter button
// - token list
ColumnLayout {
    id: root

    spacing: Theme.padding

    LoadingSkeletonGroup {
        Layout.fillWidth: true
        implicitHeight: headerLayout.implicitHeight

        ColumnLayout {
            id: headerLayout
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: Theme.padding

            // account name + balance, reload button to the right
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.padding

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    LoadingSkeletonTile {
                        implicitWidth: 110
                        implicitHeight: 18
                    }
                    LoadingSkeletonTile {
                        implicitWidth: 170
                        implicitHeight: 22
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                LoadingSkeletonTile {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: 38
                    implicitHeight: 38
                    radius: Theme.radius
                }
            }

            // dApps button + network filter pill
            RowLayout {
                Layout.fillWidth: true

                LoadingSkeletonTile {
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: width / 2
                }
                Item { Layout.fillWidth: true }
                LoadingSkeletonTile {
                    implicitWidth: 130
                    implicitHeight: 38
                    radius: Theme.radius
                }
            }
        }
    }

    // tab bar: Assets / Collectibles / History + filter button
    LoadingSkeletonGroup {
        Layout.fillWidth: true
        Layout.topMargin: Theme.padding
        implicitHeight: tabsLayout.implicitHeight

        RowLayout {
            id: tabsLayout
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: Theme.padding

            LoadingSkeletonTile {
                implicitWidth: 48
                implicitHeight: 16
            }
            LoadingSkeletonTile {
                implicitWidth: 84
                implicitHeight: 16
            }
            LoadingSkeletonTile {
                implicitWidth: 52
                implicitHeight: 16
            }
            Item { Layout.fillWidth: true }
            LoadingSkeletonTile {
                implicitWidth: 20
                implicitHeight: 20
                radius: width / 2
            }
        }
    }

    LoadingSkeletonGroup {
        Layout.fillWidth: true
        Layout.topMargin: Theme.padding
        implicitHeight: cardsLayout.implicitHeight

        RowLayout {
            id: cardsLayout
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: Theme.padding

            LoadingSkeletonTile {
                Layout.fillWidth: true
                implicitWidth: 400
                implicitHeight: 70
                radius: Theme.radius
            }
            LoadingSkeletonTile {
                Layout.fillWidth: true
                implicitWidth: 400
                implicitHeight: 70
                radius: Theme.radius
            }
        }
    }

    WalletAssetListSkeleton {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: Theme.padding
        clip: true
    }

    // footer action bar (WalletFooter: 61px, centered icon buttons)
    LoadingSkeletonGroup {
        Layout.fillWidth: true
        implicitHeight: 61

        LoadingSkeletonTile {
            anchors.centerIn: parent
            implicitWidth: parent.width * 0.6
            implicitHeight: 24
            radius: width / 2
        }
    }
}
