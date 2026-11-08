#include "messageheadertext.h"

namespace {
constexpr qreal UnboundedWidth = 1e6;
constexpr size_t RecentCapacity = 256;
}

MessageHeaderShapedText::MessageHeaderShapedText(const QString& text, const QFont& font)
    : layout(text, font)
{
    layout.setCacheEnabled(true);
    QTextOption option;
    option.setWrapMode(QTextOption::NoWrap);
    option.setAlignment(Qt::AlignLeft | Qt::AlignAbsolute);
    layout.setTextOption(option);
    layout.beginLayout();
    QTextLine line = layout.createLine();
    line.setLineWidth(UnboundedWidth);
    line.setPosition(QPointF(0, 0));
    layout.endLayout();
    naturalWidth = line.naturalTextWidth();
    height = line.height();
}

std::shared_ptr<const MessageHeaderShapedText> MessageHeaderTextCache::get(const QString& text,
                                                                           const QFont& font,
                                                                           const void* owner,
                                                                           quint64 fontKey)
{
    Key key{text, owner, fontKey};
    auto it = m_entries.find(key);
    if (it != m_entries.end()) {
        if (auto shared = it->lock())
            return shared;
    }
    auto shaped = std::make_shared<const MessageHeaderShapedText>(text, font);
    m_entries.insert(std::move(key), shaped);
    if (m_recent.size() < RecentCapacity) {
        m_recent.push_back(shaped);
    } else {
        m_recent[m_recentNext] = shaped;
        m_recentNext = (m_recentNext + 1) % RecentCapacity;
    }
    if (m_entries.size() >= m_pruneAt)
        prune();
    return shaped;
}

void MessageHeaderTextCache::prune()
{
    m_entries.removeIf([](const auto& entry) { return entry.value().expired(); });
    // Amortised: the next prune waits until the table doubles again.
    m_pruneAt = qMax<qsizetype>(512, m_entries.size() * 2);
}
