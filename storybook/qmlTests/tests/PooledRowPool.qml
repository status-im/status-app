import QtQuick

import StatusQ

/*
  Fixture for the CppPool group: a DelegatePool whose rows RowBinder dresses.

  In its own file, and deliberately without `pragma ComponentBehavior: Bound`,
  because DelegatePool incubates its delegate with no creation context - and a
  bound component refuses to be instantiated outside the context it was
  declared in. For the same reason nothing inside the delegate refers to
  anything outside it.
*/
DelegatePool {
    id: root

    readonly property string kind: "row"

    // Grow-only in the pool, so lowering this does not shrink what it holds.
    property int target: 0

    DelegatePoolKind {
        kind: root.kind
        target: root.target

        delegate: Component {
            Item {
                id: pooledRow

                // The role RowBinder writes, by name. A parked row holds the
                // last one it was given; the next bind is the reset.
                property string messageText

                // How the owner reaches the binder from the item, which is all
                // releaseDelegate() is handed.
                readonly property RowBinder binder: rowBinder

                implicitHeight: rowText.implicitHeight + 16

                Text {
                    id: rowText

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 8

                    text: pooledRow.messageText
                    wrapMode: Text.Wrap
                }

                RowBinder {
                    id: rowBinder

                    target: pooledRow
                }
            }
        }
    }
}
