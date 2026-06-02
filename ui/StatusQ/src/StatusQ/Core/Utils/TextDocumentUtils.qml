pragma Singleton

import QtQuick

import StatusQ.Internal as Internal

QtObject {
    // Returns the character ranges ({ start, end }) of every block quote in the
    // given text document. See TextDocumentUtilsInternal::blockquoteRanges.
    function blockquoteRanges(textDocument) {
        return Internal.TextDocumentUtils.blockquoteRanges(textDocument)
    }
}
