import QtQuick
import QtQuick.Layouts
import QtTest

import StatusQ.Core
import StatusQ.Controls

Item {
    id: root

    width: 600
    height: 400

    ListModel { id: emptyModel }

    // Same shape as ChatMessagesView's sendContactRequestComponent; implicit width
    Component {
        id: headerComponentButton

        StatusButton {
            objectName: "headerComponent"
            text: "Send Contact Request"
        }
    }

    // banner component, no implicit width
    Component {
        id: headerComponentRectangle

        Rectangle {
            objectName: "headerComponent"
            implicitHeight: 40
            color: "#2f3d5c"

            Text {
                anchors.centerIn: parent

                color: "white"
                text: "header - the start of the layout direction"
            }
        }
    }

    Component {
        id: viewComponent

        WindowedView {
            anchors.fill: parent
            model: emptyModel
            keyRole: "messageId"
            verticalLayoutDirection: WindowedView.VerticalLayoutDirection.BottomToTop
            acquireDelegate: function() { return null }
            releaseDelegate: function(item) {}
        }
    }

    TestCase {
        name: "WindowedViewHeaderWidth"
        when: windowShown

        function test_headerButtonKeepsNaturalWidth_data() {
            return [ {tag: "implicit", comp: headerComponentButton},
                    {tag: "explicit", comp: headerComponentRectangle},
                    ]
        }

        function test_headerButtonKeepsNaturalWidth(data) {
            const view = createTemporaryObject(viewComponent, root)
            verify(view)
            view.header = data.comp
            const slot = findChild(view, "bottomSlot")
            verify(slot, "bottomSlot exists")

            const headerItem = findChild(slot, "headerComponent")
            verify(!!headerItem)
            verify(headerItem.visible)

            if (data.tag === "implicit") {
                verify(headerItem.implicitWidth > 0 && headerItem.implicitWidth < view.width - 100,
                       "button natural width is narrower than the view")
                compare(headerItem.width, headerItem.implicitWidth,
                        "header button keeps its natural width (ListView header semantics)")
            } else {
                compare(slot.width, headerItem.width, "item w/o implicitWidth should stretch the width")
            }
        }
    }
}
