import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml.Models
import Qt5Compat.GraphicalEffects

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

StatusDialogFooter {
    id: root

    /** property to set loading state **/
    property bool loading
    /** property to set estimated time **/
    property string estimatedTime
    /** property to set estimates fees in fiat **/
    property string estimatedFees
    /** property to set error state **/
    property bool error

    /** input property to blur the background of the footer **/
    property var blurSource: null
    /** input property to source size of the blur soruce **/
    property rect blurSourceRect: Qt.rect(0, 0, 0, 0)

    // Signal to propogate Send clicked
    signal reviewSendClicked()

    spacing: Theme.bigPadding
    color: Theme.palette.baseColor3
    dropShadowEnabled: true

    QtObject {
        id: d

        readonly property string emptyText: "--"
        readonly property string loadingText: "XXXXXXXXXX"
    }

    background: Item {
        Rectangle {
            objectName: "blurBackdropRect"
            anchors.fill: parent
            anchors.leftMargin: radius
            anchors.rightMargin: radius
            color: root.color
            visible: !!root.blurSource
            radius: 8

            layer.enabled: !!root.blurSource
            layer.effect: FastBlur {
                radius: 36
            }

            ShaderEffectSource {
                id: blurBackdropSource
                objectName: "blurBackdropSource"

                sourceItem: root.blurSource
                anchors.fill: parent
                anchors.leftMargin: Theme.xlPadding - parent.radius
                anchors.rightMargin: -Theme.xlPadding - parent.radius
                sourceRect: root.blurSourceRect

                // Capture the frosted backdrop statically instead of every frame.
                // With live:true the whole scene is re-blurred at 60fps whenever any
                // animation runs; here we re-capture only when the content behind the
                // footer actually moves or changes (see refreshRequested wiring below).
                live: false

                // Emitted whenever the backdrop is re-captured; exposes the
                // refresh-on-movement contract for testing.
                signal refreshRequested()
                function refreshBlur() {
                    refreshRequested()
                    scheduleUpdate()
                }

                // The content behind the footer is the scrollable form (a Flickable);
                // re-capture when it scrolls (user drag or programmatic reveal) or
                // when it grows/shrinks as async data arrives.
                Connections {
                    target: root.blurSource
                    ignoreUnknownSignals: true
                    function onContentYChanged() { blurBackdropSource.refreshBlur() }
                    function onContentHeightChanged() { blurBackdropSource.refreshBlur() }
                    function onContentWidthChanged() { blurBackdropSource.refreshBlur() }
                }

                // A theme switch recolors the content behind the footer without
                // moving it; re-capture so the static backdrop is not left stale.
                readonly property color themeProbe: root.color
                onThemeProbeChanged: refreshBlur()

                Component.onCompleted: scheduleUpdate()
            }
        }

        Item {
            anchors.fill: parent
            Rectangle {
                anchors.fill: parent
                color: !!root.blurSource ? StatusColors.alphaColor(root.color, 0.85) : root.color
                radius: 8

                // cover for the bottom rounded corners
                Rectangle {
                    width: parent.radius
                    height: parent.radius
                    anchors.top: parent.top
                    anchors.left: parent.left
                    color: parent.color
                }
                // cover for the bottom rounded corners
                Rectangle {
                    width: parent.radius
                    height: parent.radius
                    anchors.top: parent.top
                    anchors.right: parent.right
                    color: parent.color
                }
            }

            layer.enabled: root.dropShadowEnabled
            layer.effect: DropShadow {
                horizontalOffset: 0
                verticalOffset: -3
                samples: 24
                color: StatusColors.alphaColor(Theme.palette.dropShadow, 0.06)
            }

            StatusDialogDivider {
                anchors.top: parent.top
                width: parent.width
                visible: !root.dropShadowEnabled
            }
        }
    }

    leftButtons: ObjectModel {
        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: Theme.padding

            spacing: 0

            StatusBaseText {
                objectName: "estTimeLabel"

                font.weight: Font.Medium
                color: Theme.palette.directColor5
                text: qsTr("Est time")
            }
            StatusTextWithLoadingState {
                id: estimatedTime

                objectName: "estimatedTimeText"

                font.weight: Font.Medium
                customColor: !!root.estimatedTime ? Theme.palette.directColor1:
                                                   Theme.palette.directColor5
                loading: root.loading

                text: !!root.estimatedTime ? root.estimatedTime:
                      root.loading ? d.loadingText : d.emptyText
            }
        }
        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter

            spacing: 0

            StatusBaseText {
                objectName: "estFeesLabel"

                font.weight: Font.Medium
                color: Theme.palette.directColor5
                text: qsTr("Est fees")
            }
            StatusTextWithLoadingState {
                id: estimatedFees

                objectName: "estimatedFeesText"

                font.weight: Font.Medium
                customColor: root.error ? Theme.palette.dangerColor1:
                                          !!root.estimatedFees ?
                                              Theme.palette.directColor1:
                                              Theme.palette.directColor5

                loading: root.loading

                text: !!root.estimatedFees ? root.estimatedFees:
                      loading ? d.loadingText : d.emptyText
            }
        }
    }

    rightButtons: ObjectModel {
        StatusButton {
            objectName: "transactionModalFooterButton"

            Layout.rightMargin: Theme.padding
            Layout.maximumHeight: implicitHeight

            disabledColor: Theme.palette.directColor8
            enabled: !!root.estimatedTime &&
                     !!root.estimatedFees &&
                     !root.loading && !root.error

            text: qsTr("Review Send")

            onClicked: root.reviewSendClicked()
        }
    }
}
