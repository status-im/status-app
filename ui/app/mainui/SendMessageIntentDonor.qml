import QtQuick

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import utils

/**
  * Non-visual worker behind the iOS share-sheet contact suggestions: after
  * each successful send (AppMain forwards rootStore.messageSentToChat into
  * donateForChat), it looks the destination up in the recent postable
  * destinations model (see RecentPostableDestinationsAdaptor — the single
  * identity/recency source the destination picker uses, no duplicated logic),
  * renders its avatar the same way the picker does, and emits
  * donationRequested with the conversation id, display name and rendered
  * avatar path. Event-driven only: no donation without a send.
  *
  * Emits an intent signal out; the high-level consumer (AppMain) forwards it
  * to the platform donation call (MobileUI.donateSendMessageInteraction).
  */
Item {
    id: root

    /* Postable destinations; expected roles: chatId, name, color, colorId,
       icon, emoji (as rendered by the destination picker delegate) */
    required property var model

    /* Directory the rendered avatars are written to; when empty, donations
       are emitted without an avatar */
    property string iconDirectory

    /* iconPath is "" when no avatar could be rendered — a donation without
       an avatar still works (best effort, like the shortcut publisher) */
    signal donationRequested(string conversationId, string name, string iconPath)

    /* A send to chatId just succeeded: donate it as a suggestion. Ids not in
       the model are skipped — a destination that is no longer postable is
       never donated. Safe to call in bursts: donations are processed one
       avatar grab at a time, and a chat already waiting is not re-queued. */
    function donateForChat(chatId) {
        if (d.queue.includes(chatId))
            return
        d.queue.push(chatId)
        d.processNext()
    }

    // The avatar is render-only input for grabToImage: clipped away visually
    // (grabbing renders the item itself, so the clip does not affect the
    // result), but it must stay visible — invisible items have no
    // scene-graph content to grab.
    width: 0
    height: 0
    clip: true

    QtObject {
        id: d

        readonly property int iconSize: 128

        // Sends awaiting donation, processed one at a time (the avatar item
        // is single and a grab is in flight while busy).
        property var queue: []
        property bool busy: false

        property string currentName
        property string currentColor
        property string currentColorId
        property string currentIcon
        property string currentEmoji

        // Guarded lookup: between donations (and for a destination without
        // a colorId) there is nothing to look up, and colorForColorId("")
        // would produce undefined — not assignable to a color.
        function currentAssetColor() {
            if (currentColor)
                return currentColor
            if (currentColorId === "")
                return "transparent"
            return Utils.colorForColorId(Theme.palette, currentColorId)
        }

        function processNext() {
            if (busy || queue.length === 0)
                return

            const chatId = queue.shift()
            const destination = SQUtils.ModelUtils.getByKey(root.model, "chatId", chatId)
            if (!destination) {
                processNext()
                return
            }

            const name = destination.name
            if (root.iconDirectory === "") {
                root.donationRequested(chatId, name, "")
                processNext()
                return
            }

            busy = true
            currentName = name
            currentColor = String(destination.color ?? "")
            currentColorId = String(destination.colorId ?? "")
            currentIcon = String(destination.icon ?? "")
            currentEmoji = String(destination.emoji ?? "")

            // One file per conversation: a later donation for the same chat
            // overwrites its previous avatar instead of accumulating files.
            const path = "%1/donation-%2.png".arg(root.iconDirectory).arg(Qt.md5(chatId))
            const grabbing = avatar.grabToImage(result => {
                const saved = result.saveToFile(path)
                d.finish(chatId, name, saved ? path : "")
            })
            if (!grabbing)
                finish(chatId, name, "")
        }

        function finish(chatId, name, iconPath) {
            busy = false
            root.donationRequested(chatId, name, iconPath)
            processNext()
        }
    }

    // Mirrors the destination picker delegate's avatar (StatusListItem
    // asset), so the share-sheet suggestion shows the destination exactly as
    // the picker does.
    StatusSmartIdenticon {
        id: avatar

        width: d.iconSize
        height: d.iconSize
        name: d.currentName
        asset.width: d.iconSize
        asset.height: d.iconSize
        asset.color: d.currentAssetColor()
        asset.name: d.currentIcon
        asset.emoji: d.currentEmoji
        asset.charactersLen: 2
    }
}
