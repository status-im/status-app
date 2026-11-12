#pragma once

#include <QFont>
#include <QHash>
#include <QString>
#include <QTextLayout>

#include <memory>
#include <vector>

// One single-line text shaped once and shared, read-only, by every header of
// a view that shows it: dots, a sender's name and id on consecutive messages,
// repeated timestamps. Only the GUI thread creates them; the render thread
// reads them during sync, while the GUI thread is blocked.
struct MessageHeaderShapedText
{
    QTextLayout layout;
    qreal naturalWidth = 0;
    qreal height = 0;

    MessageHeaderShapedText(const QString& text, const QFont& font);
};

class MessageHeaderTextCache
{
public:
    // `fontKey` identifies the font (appearance, revision and role), so a
    // lookup never builds QFont::key().
    std::shared_ptr<const MessageHeaderShapedText> get(const QString& text, const QFont& font,
                                                       const void* owner, quint64 fontKey);
    qsizetype size() const { return m_entries.size(); }

private:
    struct Key
    {
        QString text;
        const void* owner;
        quint64 font;
        friend bool operator==(const Key& a, const Key& b)
        {
            return a.font == b.font && a.owner == b.owner && a.text == b.text;
        }
        friend size_t qHash(const Key& key, size_t seed = 0)
        {
            return qHashMulti(seed, key.text, quintptr(key.owner), key.font);
        }
    };
    void prune();

    QHash<Key, std::weak_ptr<const MessageHeaderShapedText>> m_entries;
    // Recently used texts stay alive while no header shows them, so pooled
    // rows rebinding to them do not shape again.
    std::vector<std::shared_ptr<const MessageHeaderShapedText>> m_recent;
    size_t m_recentNext = 0;
    qsizetype m_pruneAt = 512;
};
