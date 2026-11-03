#pragma once

#include <QList>
#include <QObject>
#include <QtQmlIntegration/qqmlintegration.h>

// One value representation shared by the parser, QML and the renderer.
class ChatTextSegment
{
    Q_GADGET
    QML_VALUE_TYPE(chatTextSegment)
    QML_STRUCTURED_VALUE
    Q_PROPERTY(QString text MEMBER text)
    Q_PROPERTY(QString href MEMBER href)
    Q_PROPERTY(int quoteLevel MEMBER quoteLevel)
    Q_PROPERTY(bool mention READ mention WRITE setMention)
    Q_PROPERTY(bool bold READ bold WRITE setBold)
    Q_PROPERTY(bool italic READ italic WRITE setItalic)
    Q_PROPERTY(bool strikethrough READ strikethrough WRITE setStrikethrough)
    Q_PROPERTY(bool underline READ underline WRITE setUnderline)
    Q_PROPERTY(bool code READ code WRITE setCode)
    Q_PROPERTY(bool codeBlock READ codeBlock WRITE setCodeBlock)
    Q_PROPERTY(bool newBlock READ newBlock WRITE setNewBlock)
    Q_PROPERTY(bool sourceIsOnlyEmoji READ sourceIsOnlyEmoji WRITE setSourceIsOnlyEmoji)
    Q_PROPERTY(bool hasSourceClassification READ hasSourceClassification WRITE setHasSourceClassification)
public:
    enum Flag : quint16 { Bold = 1, Italic = 2, Strikethrough = 4, Underline = 8,
                          Code = 16, CodeBlock = 32, NewBlock = 64, SourceIsOnlyEmoji = 128, Mention = 256 };
    Q_DECLARE_FLAGS(Flags, Flag)
    QString text;
    QString href;
    int quoteLevel = 0;
    Flags flags;
    Flags present;

    bool has(Flag flag) const { return flags.testFlag(flag); }
    void setFlag(Flag flag, bool enabled) {
        flags.setFlag(flag, enabled);
        present |= flag;
    }
    bool mention() const { return has(Mention); }
    void setMention(bool enabled) { setFlag(Mention, enabled); }
    bool bold() const { return has(Bold); }
    void setBold(bool enabled) { setFlag(Bold, enabled); }
    bool italic() const { return has(Italic); }
    void setItalic(bool enabled) { setFlag(Italic, enabled); }
    bool strikethrough() const { return has(Strikethrough); }
    void setStrikethrough(bool enabled) { setFlag(Strikethrough, enabled); }
    bool underline() const { return has(Underline); }
    void setUnderline(bool enabled) { setFlag(Underline, enabled); }
    bool code() const { return has(Code); }
    void setCode(bool enabled) { setFlag(Code, enabled); }
    bool codeBlock() const { return has(CodeBlock); }
    void setCodeBlock(bool enabled) { setFlag(CodeBlock, enabled); }
    bool newBlock() const { return has(NewBlock); }
    void setNewBlock(bool enabled) { setFlag(NewBlock, enabled); }
    bool sourceIsOnlyEmoji() const { return has(SourceIsOnlyEmoji); }
    void setSourceIsOnlyEmoji(bool enabled) { setFlag(SourceIsOnlyEmoji, enabled); }
    // Copies through QML must preserve unspecified versus explicitly false.
    bool hasSourceClassification() const { return present.testFlag(SourceIsOnlyEmoji); }
    void setHasSourceClassification(bool enabled) { present.setFlag(SourceIsOnlyEmoji, enabled); }
    bool sameContent(const ChatTextSegment& other) const {
        constexpr Flags structure = Flags(NewBlock) | CodeBlock;
        return text == other.text && href == other.href && quoteLevel == other.quoteLevel
                && (flags & structure) == (other.flags & structure);
    }
    bool operator==(const ChatTextSegment& other) const {
        return text == other.text && href == other.href && quoteLevel == other.quoteLevel
                && flags == other.flags && present == other.present;
    }
};
Q_DECLARE_OPERATORS_FOR_FLAGS(ChatTextSegment::Flags)
// Members are relocatable Qt values and scalars, with no self-references.
Q_DECLARE_TYPEINFO(ChatTextSegment, Q_RELOCATABLE_TYPE);
Q_DECLARE_METATYPE(ChatTextSegment)
