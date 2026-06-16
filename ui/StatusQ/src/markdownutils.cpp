#include "StatusQ/markdownutils.h"

#include "StatusQ/markdownparser.h"

MarkdownUtils::MarkdownUtils(QObject* parent)
    : QObject(parent)
{
}

QString MarkdownUtils::dumpAst(const QString& text, bool multilineEmphasis,
                               bool formatUnclosedCodeFence, bool withRanges) const
{
    Markdown::Options opts;
    opts.multilineEmphasis = multilineEmphasis;
    opts.formatUnclosedCodeFence = formatUnclosedCodeFence;
    return Markdown::dump(Markdown::parse(text, opts), withRanges);
}
