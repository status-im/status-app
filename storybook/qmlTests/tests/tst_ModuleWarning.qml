import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtTest

import StatusQ.Core.Theme

import shared.panels

Item {
    id: root
    width: 800
    height: 600

    Component {
        id: warningComponent

        ModuleWarning {
            width: 600
            delay: false
            active: true
            text: "Warning"
        }
    }

    Component {
        id: actionsComponent

        Row {
            ModuleWarningButton {
                objectName: "sampleAction"
                text: "Set password"
            }
        }
    }

    Component {
        id: stackComponent

        Item {
            anchors.fill: parent

            readonly property alias stack: stack
            readonly property alias first: first
            readonly property alias second: second
            readonly property alias third: third
            readonly property alias underneath: underneath

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                ModuleWarningStack {
                    id: stack
                    Layout.fillWidth: true

                    ModuleWarning {
                        id: first
                        Layout.fillWidth: true
                        delay: false
                        active: true
                        collapsible: true
                        text: "First"
                    }
                    ModuleWarning {
                        id: second
                        Layout.fillWidth: true
                        delay: false
                        active: true
                        collapsible: true
                        text: "Second"
                    }
                    ModuleWarning {
                        id: third
                        Layout.fillWidth: true
                        delay: false
                        active: true
                        collapsible: true
                        text: "Third"
                    }
                }

                MouseArea {
                    id: underneath
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    property int clicks: 0
                    onClicked: clicks++
                }
            }
        }
    }

    Component {
        id: wideActionsComponent

        Rectangle {
            implicitWidth: 200
            implicitHeight: 20
        }
    }

    Component {
        id: hostedStackComponent

        Item {
            anchors.fill: parent

            readonly property alias stack: stack
            readonly property alias customHost: customHost
            readonly property alias preset: preset
            readonly property alias wrapped: wrapped
            readonly property alias direct: direct

            Item {
                id: customHost
                y: 400
                width: 100
                height: 50
            }

            ModuleWarningStack {
                id: stack
                width: parent.width

                ModuleWarning {
                    id: preset
                    Layout.fillWidth: true
                    delay: false
                    active: true
                    collapsible: true
                    text: "Preset"
                    collapsedButtonParent: customHost
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: wrapped.implicitHeight

                    ModuleWarning {
                        id: wrapped
                        width: parent.width
                        delay: false
                        active: true
                        collapsible: true
                        text: "Wrapped"
                        collapsedButtonParent: stack.collapsedButtonsParent
                    }
                }

                ModuleWarning {
                    id: direct
                    Layout.fillWidth: true
                    delay: false
                    active: true
                    collapsible: true
                    text: "Direct"
                }
            }
        }
    }

    TextInput {
        id: focusHolder
        width: 100
        height: 20
        y: 500
    }

    SignalSpy {
        id: closeClickedSpy
        signalName: "closeClicked"
    }

    TestCase {
        name: "ModuleWarning"
        when: windowShown

        readonly property int bannerHeight: 32

        function init() {
            closeClickedSpy.clear()
            closeClickedSpy.target = null
        }

        function createWarning(props) {
            const warning = createTemporaryObject(warningComponent, root, props)
            verify(!!warning)
            closeClickedSpy.target = warning
            tryCompare(warning, "implicitHeight", bannerHeight)
            return warning
        }

        function closeButton(warning) {
            const button = findChild(warning, "closeButton")
            verify(!!button)
            return button
        }

        function expandButton(warning) {
            const button = findChild(warning, "expandButton")
            verify(!!button)
            return button
        }

        function collapseByClick(warning) {
            mouseClick(closeButton(warning))
            verify(warning.collapsed)
            tryCompare(warning, "implicitHeight", 0)
            tryCompare(expandButton(warning), "visible", true)
        }

        function expandByClick(warning) {
            mouseClick(expandButton(warning))
            verify(!warning.collapsed)
            compare(expandButton(warning).visible, false)
            tryCompare(warning, "implicitHeight", bannerHeight)
        }

        function test_collapse_keeps_warning_active() {
            const warning = createWarning({ collapsible: true })

            compare(warning.collapsed, false)
            compare(warning.collapsedIconName, "caution")
            compare(expandButton(warning).visible, false)

            collapseByClick(warning)

            compare(warning.active, true)
            compare(closeClickedSpy.count, 0)
            const button = expandButton(warning)
            compare(button.width, 40)
            compare(button.height, 40)
            compare(button.y, warning.height + 4)
            compare(button.x, (warning.width - button.width) / 2)
        }

        function test_repeated_collapse_expand() {
            const warning = createWarning({ collapsible: true })

            for (let i = 0; i < 3; ++i) {
                collapseByClick(warning)
                expandByClick(warning)
            }

            compare(warning.active, true)
            compare(closeClickedSpy.count, 0)
        }

        function test_actions_clickable_after_expand() {
            const warning = createWarning({ collapsible: true, actions: actionsComponent })

            const bannerText = findChild(warning, "bannerText")
            compare(bannerText.visible, false)

            collapseByClick(warning)
            expandByClick(warning)

            const action = findChild(warning, "sampleAction")
            verify(!!action)
            verify(action.visible)
            const clickedSpy = signalSpyComponent.createObject(this, { target: action, signalName: "clicked" })
            mouseClick(action)
            compare(clickedSpy.count, 1)
            clickedSpy.destroy()
        }

        Component {
            id: signalSpyComponent
            SignalSpy {}
        }

        function test_expiry_while_collapsed() {
            const warning = createWarning({ collapsible: true })

            warning.showFor(1000)
            collapseByClick(warning)

            tryCompare(warning, "active", false, 3000)
            compare(warning.collapsed, false)
            compare(expandButton(warning).visible, false)
            compare(closeClickedSpy.count, 0)

            warning.show()
            compare(warning.collapsed, false)
            tryCompare(warning, "implicitHeight", bannerHeight)
        }

        function test_reactivation_starts_expanded() {
            const warning = createWarning({ collapsible: true })

            collapseByClick(warning)
            warning.active = false
            warning.show()

            compare(warning.collapsed, false)
            tryCompare(warning, "implicitHeight", bannerHeight)
        }

        function test_changes_while_collapsed_keep_collapsed() {
            const warning = createWarning({ collapsible: true, type: ModuleWarning.Danger })

            collapseByClick(warning)

            const background = expandButton(warning).background
            tryCompare(background, "color", Theme.palette.dangerColor1)

            warning.text = "Changed"
            warning.type = ModuleWarning.Warning
            warning.progressValue = 50

            compare(warning.collapsed, true)
            compare(warning.implicitHeight, 0)
            tryCompare(background, "color", Theme.palette.warningColor1)
        }

        function test_not_collapsible_closes() {
            const warning = createWarning()

            const button = closeButton(warning)
            verify(button.visible)
            compare(button.Accessible.name, "Close warning")

            mouseClick(button)
            compare(closeClickedSpy.count, 1)
            compare(warning.collapsed, false)
            compare(expandButton(warning).visible, false)

            warning.collapse()
            compare(warning.collapsed, false)
        }

        function test_not_collapsible_close_hidden() {
            const warning = createWarning({ closeBtnVisible: false })
            compare(closeButton(warning).visible, false)
        }

        function test_collapsible_ignores_close_hidden() {
            const warning = createWarning({ collapsible: true, closeBtnVisible: false })

            const button = closeButton(warning)
            verify(button.visible)
            compare(button.Accessible.name, "Collapse warning")

            collapseByClick(warning)
            compare(closeClickedSpy.count, 0)
        }

        function test_keyboard_data() {
            return [
                { tag: "space", key: Qt.Key_Space },
                { tag: "return", key: Qt.Key_Return },
                { tag: "enter", key: Qt.Key_Enter },
            ]
        }

        function test_keyboard(data) {
            const warning = createWarning({ collapsible: true })

            const close = closeButton(warning)
            const expand = expandButton(warning)
            compare(expand.Accessible.name, "Expand warning")
            compare(expand.Accessible.description, "Warning")

            close.forceActiveFocus(Qt.TabFocusReason)
            verify(close.activeFocus)

            keyClick(data.key)
            verify(warning.collapsed)
            tryCompare(expand, "visible", true)
            tryVerify(() => expand.activeFocus)

            keyClick(data.key)
            verify(!warning.collapsed)
            tryVerify(() => close.activeFocus)
            tryCompare(warning, "implicitHeight", bannerHeight)
        }

        function test_mouse_click_keeps_focus_data() {
            return [
                { tag: "close", collapsible: false },
                { tag: "collapse and expand", collapsible: true },
            ]
        }

        function test_mouse_click_keeps_focus(data) {
            const warning = createWarning({ collapsible: data.collapsible, actions: actionsComponent })

            focusHolder.forceActiveFocus()
            verify(focusHolder.activeFocus)

            mouseClick(findChild(warning, "sampleAction"))
            verify(focusHolder.activeFocus)

            if (data.collapsible) {
                collapseByClick(warning)
                verify(focusHolder.activeFocus)
                expandByClick(warning)
            } else {
                mouseClick(closeButton(warning))
                compare(closeClickedSpy.count, 1)
            }
            verify(focusHolder.activeFocus)
        }

        function test_collapse_during_show_animation() {
            const warning = createTemporaryObject(warningComponent, root,
                                                  { active: false, collapsible: true })
            verify(!!warning)
            tryCompare(warning, "implicitHeight", 0)

            warning.show()
            tryVerify(() => warning.implicitHeight > 0 && warning.implicitHeight < bannerHeight / 2)

            const heights = []
            const record = () => heights.push(warning.implicitHeight)
            warning.implicitHeightChanged.connect(record)
            record()

            warning.collapse()
            tryCompare(expandButton(warning), "visible", true)
            warning.implicitHeightChanged.disconnect(record)

            compare(warning.implicitHeight, 0)
            for (let i = 1; i < heights.length; ++i)
                verify(heights[i] <= heights[i - 1],
                       "height grew from %1 to %2 during collapse".arg(heights[i - 1]).arg(heights[i]))
        }

        function test_stack_keeps_caller_set_parent() {
            const item = createTemporaryObject(hostedStackComponent, root)
            verify(!!item)

            const row = item.stack.collapsedButtonsParent
            verify(!!row)
            compare(row, findChild(item.stack, "collapsedButtonsRow"))

            compare(item.preset.collapsedButtonParent, item.customHost)
            compare(item.wrapped.collapsedButtonParent, row)
            compare(item.direct.collapsedButtonParent, row)

            for (const warning of [item.preset, item.wrapped, item.direct]) {
                tryCompare(warning, "implicitHeight", bannerHeight)
                collapseByClick(warning)
            }

            compare(expandButton(item.preset).parent, item.customHost)

            // wrapper is stacked first
            const wrappedButton = expandButton(item.wrapped)
            const directButton = expandButton(item.direct)
            compare(wrappedButton.parent, row)
            compare(directButton.parent, row)
            tryVerify(() => directButton.x === wrappedButton.x + wrappedButton.width + 8,
                      1000, "wrapped at %1, direct at %2".arg(wrappedButton.x).arg(directButton.x))
        }

        function actionsGeometry(warning) {
            const loader = findChild(warning, "actionsLoader")
            verify(!!loader)
            tryVerify(() => loader.width > 0)

            const content = loader.parent
            const rightControls = ["progressText", "progressBar", "actionButton", "closeButton"]
                .map(name => findChild(warning, name))
                .filter(control => control.visible)
            const firstRightX = rightControls.length
                ? Math.min(...rightControls.map(control => control.mapToItem(content, 0, 0).x))
                : content.width
            return { loader, centredX: (content.width - loader.width) / 2, firstRightX }
        }

        function test_actions_centred_when_room() {
            const warning = createWarning({ actions: wideActionsComponent, extraInnerLeftMargin: 0 })
            const g = actionsGeometry(warning)
            compare(g.loader.x, g.centredX)
        }

        function test_actions_clamped_before_right_controls() {
            const warning = createWarning({ actions: wideActionsComponent, extraInnerLeftMargin: 0,
                                            width: 420, buttonText: "Action", progressValue: 50 })
            const g = actionsGeometry(warning)

            verify(g.loader.x < g.centredX, "expected the actions to be pushed left")
            verify(g.loader.x >= Theme.halfPadding)
            verify(g.loader.x + g.loader.width <= g.firstRightX,
                   "actions end at %1, right controls start at %2"
                   .arg(g.loader.x + g.loader.width).arg(g.firstRightX))
        }

        function test_actions_clamped_after_left_margin() {
            const warning = createWarning({ actions: wideActionsComponent, extraInnerLeftMargin: 60,
                                            width: 300, closeBtnVisible: false })
            const g = actionsGeometry(warning)

            verify(g.centredX < Theme.halfPadding + 60)
            compare(g.loader.x, Theme.halfPadding + 60)
        }

        function test_collapse_right_after_expand() {
            const warning = createWarning({ collapsible: true })

            collapseByClick(warning)
            warning.expand()
            warning.collapse()

            verify(warning.collapsed)
            tryCompare(warning, "implicitHeight", 0)
        }

        function test_collapse_ignored_before_shown() {
            const warning = createTemporaryObject(warningComponent, root,
                                                  { active: false, delay: true, collapsible: true })
            verify(!!warning)
            tryCompare(warning, "implicitHeight", 0)

            warning.show()
            warning.collapse()

            compare(warning.collapsed, false)
            compare(warning.implicitHeight, 0)
            compare(expandButton(warning).visible, false)
        }

        function test_keyboard_close_not_collapsible() {
            const warning = createWarning()

            const close = closeButton(warning)
            close.forceActiveFocus(Qt.TabFocusReason)
            keyClick(Qt.Key_Return)
            compare(closeClickedSpy.count, 1)
        }

        function test_stack_row() {
            const item = createTemporaryObject(stackComponent, root)
            verify(!!item)

            tryCompare(item.first, "implicitHeight", bannerHeight)
            tryCompare(item.second, "implicitHeight", bannerHeight)
            tryCompare(item.third, "implicitHeight", bannerHeight)

            const row = findChild(item.stack, "collapsedButtonsRow")
            verify(!!row)
            compare(item.first.collapsedButtonParent, row)
            compare(item.second.collapsedButtonParent, row)

            collapseByClick(item.first)
            collapseByClick(item.second)
            collapseByClick(item.third)

            tryCompare(item.stack, "height", 0)

            const firstButton = expandButton(item.first)
            const secondButton = expandButton(item.second)
            compare(firstButton.parent, row)
            compare(secondButton.parent, row)
            const thirdButton = expandButton(item.third)
            compare(thirdButton.parent, row)
            compare(secondButton.x, firstButton.x + firstButton.width + 8)
            compare(thirdButton.x, secondButton.x + secondButton.width + 8)
            compare(firstButton.y, 0)
            compare(secondButton.y, 0)
            compare(thirdButton.y, 0)

            const rowPos = row.mapToItem(item, 0, 0)
            compare(rowPos.y, 4)
            compare(firstButton.mapToItem(item, 0, 0).y, 4)
            fuzzyCompare(rowPos.x + row.width / 2, item.width / 2, 1)

            mouseClick(item, rowPos.x - 20, rowPos.y + 20)
            compare(item.underneath.clicks, 1)

            mouseClick(firstButton)
            compare(item.underneath.clicks, 1)
            verify(!item.first.collapsed)
            verify(item.second.collapsed)
            verify(item.third.collapsed)
        }
    }
}
