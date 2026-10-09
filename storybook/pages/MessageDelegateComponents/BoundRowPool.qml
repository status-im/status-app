import QtQuick

import StatusQ

/*
  The row pool for the page's second row source: a DelegatePool that builds
  MessageDelegates dressed by RowBinder rather than by hand.

  It lives in its own file, and deliberately without
  `pragma ComponentBehavior: Bound`, because DelegatePool incubates its
  delegate with no creation context - and a bound component refuses to be
  instantiated outside the context it was declared in. The app does the same
  thing for the same reason: its pool and delegate are declared in AppMain,
  not inside the view that uses them.
*/
DelegatePool {
    id: root

    // One kind is all a chat needs today; the keying is there for the day a
    // second row shape arrives.
    readonly property string kind: "row"

    // Grow-only in the pool, so lowering this does not shrink what it holds.
    property int target: 0

    DelegatePoolKind {
        kind: root.kind
        target: root.target

        delegate: Component {
            MessageDelegate {
                id: boundRow

                // What RowBinder writes: the model's role names. MessageDelegate's
                // own properties are named after what they show, so the two meet
                // here. (The app's alternative is to rename the roles upstream of
                // the view.)
                property string messageText
                property var messageImages
                property var messageDate
                property string messageAvatar

                // Also what tells the two kinds of row apart when one comes back:
                // releaseDelegate() is handed the item, not the shell, so the
                // binder has to be reachable from the item.
                readonly property RowBinder binder: rowBinder

                text: boundRow.messageText
                images: boundRow.messageImages ?? []
                date: boundRow.messageDate ?? new Date(0)
                avatar: boundRow.messageAvatar

                RowBinder {
                    id: rowBinder

                    target: boundRow
                }
            }
        }
    }
}
