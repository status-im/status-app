pragma Singleton

import QtQuick

import StatusQ.Internal as Internal

QtObject {
    function escapeHtml(unsafe) {
        return Internal.StringUtils.escapeHtml(unsafe)
    }

    function readTextFile(file) {
        return Internal.StringUtils.readTextFile(file)
    }

    function writeTextFile(filePath, data) {
        return Internal.StringUtils.writeTextFile(filePath, data)
    }

    function extractDomainFromLink(link) {
        return Internal.StringUtils.extractDomainFromLink(link)
    }

    function plainText(htmlFragment) {
        return Internal.StringUtils.plainText(htmlFragment)
    }

    function shortcutToText(shortcut) {
        return Internal.StringUtils.shortcutToText(shortcut)
    }

    // Builds the small, dimmed "(edited)" HTML marker (with a leading space) appended after chat
    // text in the static renderers. `color` and `fontSize` (px) style the span.
    function editedMarker(color, fontSize) {
        return ` <span style="color:${color}; font-size:${fontSize}px">` + qsTr("(edited)") + `</span>`
    }

    // Expands the chat ASCII-emoticon slash-commands ("/shrug", "/tableflip") into their
    // kaomoji, returning any other text unchanged.
    function expandAsciiEmoticonShortcuts(text) {
        if (text.startsWith("/shrug"))
            return text.replace("/shrug", "") + " ¯\\\\\\_(ツ)\\_/¯"

        if (text.startsWith("/tableflip"))
            return text.replace("/tableflip", "") + " (╯°□°）╯︵ ┻━┻"

        return text
    }
}
