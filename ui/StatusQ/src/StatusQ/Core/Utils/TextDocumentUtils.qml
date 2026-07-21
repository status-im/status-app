pragma Singleton

import QtQuick

import StatusQ.Internal as Internal

QtObject {
    // Returns the character ranges ({ start, end }) of every block quote in the
    // given text document. See TextDocumentUtilsInternal::blockquoteRanges.
    function blockquoteRanges(textDocument) {
        return Internal.TextDocumentUtils.blockquoteRanges(textDocument)
    }

    // Returns the text of [start, end) with inline emoji image objects converted back to their
    // Unicode emoji (so copy matches font mode). See TextDocumentUtilsInternal::selectionText.
    function selectionText(textDocument, start, end) {
        return Internal.TextDocumentUtils.selectionText(textDocument, start, end)
    }
}
