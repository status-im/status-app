## HTML utilities that require seaqt Qt types.
## Kept separate from utils.nim to avoid QObject ambiguity with nimqml.

import seaqt/qtextdocumentfragment

proc plain_text*(htmlString: string): string =
  ## Convert HTML to plain text using Qt's QTextDocumentFragment.
  QTextDocumentFragment.fromHtml(htmlString).toPlainText()
