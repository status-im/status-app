pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Controls

// Adaptive dialog wrapper for StackView-based wizard flows.
//
// This is not a drop-in replacement for the previous indexed stack modal. It intentionally
// covers flows that already use, or can naturally use, StackView push/pop
// navigation. Use it when the wizard owns a linear stack of full-page steps and
// each active step can describe its title and primary action.
//
// Supported step contract:
// - title
// - stackTitleText (legacy alias for title)
// - nextButtonObjectName
// - nextButtonText
// - nextButtonImplicitHeight
// - canGoNext
// - nextAction()
// - backAction()
// - rightButtons, only when the step is loaded as replaceItem
//
// Supported dialog surface:
// - StackView access through stack/currentItem/depth/currentIndex
// - resetStack(), back(), push() through root.stack
// - replaceItem and replace() for temporary full-page panels
// - subHeaderItem/subHeaderPadding for persistent stack context
// - customFooterLeftButtons/customFooterRightButtons for owner-provided actions
// - adaptive header title from the active step
// - standard back and primary footer actions
// - hardware back button pop handling
//
// Non-goals:
// - StatusAnimatedStack currentIndex animation semantics
// - arbitrary per-step footer button models loaded directly from stack pages
//
// StatusAdaptiveDialog owns sizing, safe areas, close policy and presentation
// mode. Step content should stay focused on wizard state and layout.
StatusAdaptiveDialog {
    id: root

    property Component initialItem
    property Component replaceItem
    property Component subHeaderItem
    property int subHeaderPadding: 0
    property int stackContentImplicitHeight: 0
    property bool showStackFooter: true
    property bool showStackBackButton: !!replaceItem || depth > 1
    property ObjectModel customFooterLeftButtons
    property ObjectModel customFooterRightButtons
    property string defaultNextButtonText: qsTr("Next")
    property string defaultTitle: ""

    readonly property var stack: d.stackObject
    readonly property var replaceLoader: d.replaceLoaderObject
    readonly property var replaceObject: d.replaceObject
    readonly property var currentItem: stack ? stack.currentItem : null
    readonly property var activeItem: replaceObject || currentItem
    readonly property int depth: stack ? stack.depth : 0
    readonly property int currentIndex: depth > 0 ? depth - 1 : -1

    function back() {
        if (replaceItem) {
            replaceItem = null
            return
        }

        if (!stack || stack.depth <= 1)
            return

        if (currentItem && typeof(currentItem.backAction) === "function")
            currentItem.backAction()

        if (stack.depth > 1)
            stack.popCurrentItem()
    }

    function resetStack(operation) {
        d.maxObservedStackContentImplicitHeight = 0
        if (stack)
            stack.popToIndex(0, operation ?? StackView.Immediate)
    }

    function replace(item) {
        replaceItem = item || null
    }

    title: activeItem && typeof(activeItem.title) !== "undefined" ? activeItem.title
           : activeItem && typeof(activeItem.stackTitleText) !== "undefined" ? activeItem.stackTitleText
           : defaultTitle
    footerLeftButtons: showStackFooter
                       ? customFooterLeftButtons || stackFooterLeftButtonsModel
                       : null
    footerRightButtons: showStackFooter
                        ? customFooterRightButtons
                          || (d.replaceRightButton
                              ? replaceFooterRightButtonsModel
                              : replaceItem ? null : stackFooterRightButtonsModel)
                        : null

    QtObject {
        id: d

        property var stackObject
        property var replaceLoaderObject
        property var replaceObject
        property real maxObservedStackContentImplicitHeight: 0
        readonly property var replaceRightButton: replaceObject && typeof(replaceObject.rightButtons) !== "undefined"
                                                  ? replaceObject.rightButtons : null

        function rememberStackContentImplicitHeight(height) {
            maxObservedStackContentImplicitHeight = Math.max(maxObservedStackContentImplicitHeight, height)
        }
    }

    contentComponent: Component {
        Item {
            id: contentRoot

            readonly property bool subHeaderVisible: !!subHeaderLoader.item && subHeaderLoader.item.visible
            readonly property var statusAdaptiveDialogContentVerticalScrollBar: root.activeItem
                                                                                 && root.activeItem.statusAdaptiveDialogContentVerticalScrollBar
                                                                                 ? root.activeItem.statusAdaptiveDialogContentVerticalScrollBar
                                                                                 : null
            readonly property real activeContentImplicitHeight: Math.max(root.currentItem ? root.currentItem.implicitHeight : 0,
                                                                         root.replaceObject ? root.replaceObject.implicitHeight : 0)
                                                                + (contentRoot.subHeaderVisible
                                                                   ? subHeaderLoader.implicitHeight + root.subHeaderPadding : 0)

            implicitHeight: root.stackContentImplicitHeight > 0
                            ? root.stackContentImplicitHeight
                            : Math.max(contentRoot.activeContentImplicitHeight,
                                       d.maxObservedStackContentImplicitHeight)

            onActiveContentImplicitHeightChanged: d.rememberStackContentImplicitHeight(activeContentImplicitHeight)

            Loader {
                id: subHeaderLoader

                anchors.top: parent.top
                width: parent.width
                clip: true
                sourceComponent: root.subHeaderItem
            }

            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: subHeaderLoader.bottom
                anchors.topMargin: contentRoot.subHeaderVisible ? root.subHeaderPadding : 0
                anchors.bottom: parent.bottom
                clip: true

                StackView {
                    id: stack

                    anchors.fill: parent
                    clip: true
                    visible: !root.replaceItem
                    initialItem: root.initialItem
                    onCurrentItemChanged: {
                        if (!currentItem)
                            return

                        currentItem.width = Qt.binding(() => stack.width)
                        currentItem.height = Qt.binding(() => stack.height)
                    }
                }

                Loader {
                    id: replaceLoader

                    anchors.fill: parent
                    active: !!root.replaceItem
                    sourceComponent: root.replaceItem
                    visible: !!item
                    clip: true
                    onItemChanged: {
                        d.replaceObject = item
                        if (!item)
                            return

                        item.width = Qt.binding(() => replaceLoader.width)
                        item.height = Qt.binding(() => replaceLoader.height)
                    }
                    Component.onCompleted: d.replaceLoaderObject = replaceLoader
                    Component.onDestruction: if (d.replaceLoaderObject === replaceLoader)
                        d.replaceLoaderObject = null
                }
            }

            Component.onCompleted: d.stackObject = stack
            Component.onDestruction: if (d.stackObject === stack)
                d.stackObject = null

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.BackButton
                enabled: root.showStackBackButton
                cursorShape: undefined // fall thru
                onClicked: root.back()
            }
        }
    }

    ObjectModel {
        id: stackFooterLeftButtonsModel

        StatusBackButton {
            visible: root.showStackBackButton
            onClicked: root.back()
        }
    }

    ObjectModel {
        id: stackFooterRightButtonsModel

        StatusButton {
            objectName: root.currentItem && typeof(root.currentItem.nextButtonObjectName) !== "undefined"
                        ? root.currentItem.nextButtonObjectName : ""
            text: root.currentItem && typeof(root.currentItem.nextButtonText) !== "undefined"
                  ? root.currentItem.nextButtonText : root.defaultNextButtonText
            Layout.preferredHeight: root.currentItem && typeof(root.currentItem.nextButtonImplicitHeight) !== "undefined"
                                    ? root.currentItem.nextButtonImplicitHeight : implicitHeight
            enabled: !root.currentItem
                     || typeof(root.currentItem.canGoNext) === "undefined"
                     || root.currentItem.canGoNext
            onClicked: {
                if (root.currentItem && typeof(root.currentItem.nextAction) === "function")
                    root.currentItem.nextAction()
            }
        }
    }

    ObjectModel {
        id: replaceFooterRightButtonsModel

        Item {
            id: replaceRightButtonHost

            Layout.preferredWidth: d.replaceRightButton ? d.replaceRightButton.implicitWidth : 0
            Layout.preferredHeight: d.replaceRightButton ? d.replaceRightButton.implicitHeight : 0

            function hostReplaceRightButton() {
                if (!d.replaceRightButton)
                    return

                d.replaceRightButton.parent = replaceRightButtonHost
                d.replaceRightButton.anchors.fill = replaceRightButtonHost
            }

            Component.onCompleted: hostReplaceRightButton()

            Connections {
                target: d

                function onReplaceRightButtonChanged() {
                    replaceRightButtonHost.hostReplaceRightButton()
                }
            }
        }
    }
}
