import QtQuick
import QtTest

import QtQuick.Controls
import StatusQ.Layout

// A section may hand the chrome a Loader as a panel, so the panel can incubate
// asynchronously. A Loader reports its item's implicit size as its own, so a
// panel whose content is wider than the section would push the chrome's layout
// past the screen edge unless the loader's geometry is bound.
//
// The wallet hit this: the center panel is a StackView whose content is wider
// than a phone, and wrapping it in an unbound Loader overflowed to the right.
Item {
    id: root

    width: 390
    height: 700

    Component {
        id: layoutComponent

        StatusSectionLayoutPortrait {
            anchors.fill: parent
        }
    }

    // Content deliberately wider than the section, as a StackView holding a
    // desktop-width page is.
    Component {
        id: wideContent
        Rectangle { implicitWidth: 5000; implicitHeight: 2000 }
    }

    // What the wallet did first: no geometry of its own.
    Component {
        id: unboundLoader
        Loader { sourceComponent: wideContent }
    }

    // What it does now: bound to the chrome for the unparented phase.
    Component {
        id: boundLoader
        Loader {
            width: root.width
            height: root.height
            sourceComponent: wideContent
        }
    }

    // What the wallet's center panel actually is: a StackView that fills its
    // parent with side margins, wrapped in a Loader.
    Component {
        id: walletShapedLoader
        Loader {
            sourceComponent: Component {
                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 48
                    anchors.rightMargin: 48
                    implicitWidth: 5000
                    implicitHeight: 2000
                }
            }
        }
    }

    // Host Item absorbs the loader's sizing; the StackView anchors inside it,
    // so the margins resolve against a real parent instead of the loader.
    Component {
        id: hostedStackLoader
        Loader {
            sourceComponent: Component {
                Item {
                    StackView {
                        anchors.fill: parent
                        anchors.leftMargin: 48
                        anchors.rightMargin: 48
                        initialItem: Rectangle { implicitWidth: 5000; implicitHeight: 2000 }
                    }
                }
            }
        }
    }

    // Control padding on the stack itself, which does NOT inset the page:
    // StackView sizes currentItem to the whole view. Kept as the evidence for
    // why the wallet's inset lives on the page (RightTabBaseView) instead.
    Component {
        id: paddedStackLoader
        Loader {
            sourceComponent: Component {
                StackView {
                    leftPadding: 48
                    rightPadding: 48
                    initialItem: Rectangle { implicitWidth: 5000; implicitHeight: 2000 }
                }
            }
        }
    }

    TestCase {
        name: "SectionPanelLoaderGeometry"
        when: windowShown

        property var layout: null

        function init() {
            layout = createTemporaryObject(layoutComponent, root)
            verify(!!layout)
        }

        function test_boundLoaderPanelDoesNotOverflowTheSection() {
            layout.centerPanel = createTemporaryObject(boundLoader, root)
            waitForRendering(layout)

            const panel = layout.centerPanel
            verify(panel.width > 0, "panel should have been given a width")
            compare(panel.width <= root.width, true,
                    `center panel is ${panel.width}px wide in a ${root.width}px section`)
        }

        // The decisive case: is the binding load-bearing at all? ChatView runs
        // this same pattern with no geometry on its center panel loader.
        function test_unboundLoaderAsPanelDoesNotOverflowEither() {
            layout.centerPanel = createTemporaryObject(unboundLoader, root)
            waitForRendering(layout)

            const panel = layout.centerPanel
            console.info("UNBOUND panel width=", panel.width, "implicitWidth=", panel.implicitWidth,
                         "section width=", root.width)
            compare(panel.width <= root.width, true,
                    `unbound center panel is ${panel.width}px in a ${root.width}px section`)
        }

        function test_walletShapedPanelDoesNotOverflow() {
            layout.centerPanel = createTemporaryObject(walletShapedLoader, root)
            waitForRendering(layout)

            const panel = layout.centerPanel
            const inner = panel.item
            console.info("WALLETSHAPE loader w=", panel.width, "x=", panel.x,
                         "| inner w=", inner ? inner.width : -1, "x=", inner ? inner.x : -1,
                         "| section w=", root.width)
            compare(panel.width <= root.width, true, `loader ${panel.width}px in ${root.width}px`)
            verify(!!inner)
            compare(inner.width <= root.width, true, `inner ${inner.width}px in ${root.width}px`)
        }

        function test_hostedStackViewInsetsWithoutOverflowing() {
            layout.centerPanel = createTemporaryObject(hostedStackLoader, root)
            waitForRendering(layout)

            const host = layout.centerPanel.item
            const stack = host.children[0]
            console.info("HOSTED host w=", host.width, "| stack w=", stack.width, "x=", stack.x,
                         "| section w=", root.width)
            compare(host.width <= root.width, true, `host ${host.width}px in ${root.width}px`)
            compare(stack.width, root.width - 96, "stack should be inset by both margins")
            compare(stack.x, 48, "stack should start after the left margin")
        }

        // The stack itself does not overflow - but its padding buys nothing:
        // StackView sizes currentItem to the view, padding and all. Anything
        // that needs an inset has to carry it on the page.
        function test_paddedStackViewIgnoresItsOwnPadding() {
            layout.centerPanel = createTemporaryObject(paddedStackLoader, root)
            waitForRendering(layout)

            const panel = layout.centerPanel
            const stack = panel.item
            const content = stack.currentItem
            console.info("PADDED stack w=", stack.width, "| content w=", content.width,
                         "x=", content.x, "| section w=", root.width)
            compare(stack.width <= root.width, true, `stack ${stack.width}px in ${root.width}px`)
            compare(content.width, stack.width,
                    "StackView sizes currentItem to itself, ignoring its padding")
            compare(content.x, 0, "...and positions it at the origin")
        }

        // Guards the reason the binding exists: without it the loader adopts
        // the content's implicit width. If this ever stops overflowing, the
        // binding above is no longer load-bearing and the test should be
        // revisited rather than deleted.
        function test_unboundLoaderAdoptsItsContentWidth() {
            const loader = createTemporaryObject(unboundLoader, root)
            waitForRendering(loader)

            compare(loader.implicitWidth, 5000,
                    "a Loader reports its item's implicit width as its own")
        }
    }
}
