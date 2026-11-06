#pragma once

#include "StatusQ/chattextappearance.h"
#include "StatusQ/chattextsegment.h"

#include <QQuickItem>
#include <QTextLayout>

// Static formatted preview. Owns one visible layout, without a text document.
class ChatSingleLineTextItem : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(ChatTextAppearance* appearance READ appearance WRITE setAppearance NOTIFY appearanceChanged)
    Q_PROPERTY(QList<ChatTextSegment> segments READ segments WRITE setSegments NOTIFY segmentsChanged)
    Q_PROPERTY(bool edited READ edited WRITE setEdited NOTIFY editedChanged)
    // Full plain text, mentions resolved, with the edited suffix; also the accessible name.
    Q_PROPERTY(QString text READ text NOTIFY textChanged)
    Q_PROPERTY(QString displayedText READ displayedText NOTIFY displayedTextChanged)
    Q_PROPERTY(bool truncated READ truncated NOTIFY truncatedChanged)
    Q_PROPERTY(qreal contentHeight READ contentHeight NOTIFY contentHeightChanged)
public:
    explicit ChatSingleLineTextItem(QQuickItem* parent = nullptr);
    ~ChatSingleLineTextItem() override;

    ChatTextAppearance* appearance() const { return m_appearance; }
    void setAppearance(ChatTextAppearance* appearance);
    QList<ChatTextSegment> segments() const { return m_segments; }
    void setSegments(const QList<ChatTextSegment>& value);
    bool edited() const { return m_edited; }
    void setEdited(bool value);
    QString text() const;
    QString displayedText() const { return m_layout.text(); }
    bool truncated() const { return m_truncated; }
    qreal contentHeight() const { return implicitHeight(); }
signals:
    void appearanceChanged();
    void segmentsChanged();
    void editedChanged();
    void textChanged();
    void displayedTextChanged();
    void truncatedChanged();
    void contentHeightChanged();

protected:
    QSGNode* updatePaintNode(QSGNode*, UpdatePaintNodeData*) override;
    void geometryChange(const QRectF&, const QRectF&) override;
    void componentComplete() override;

private:
    void connectAppearance();
    void applyAppearance(ChatTextAppearance::Change change);
    ChatTextAppearance* m_appearance = ChatTextAppearance::defaults();
    void rebuild();
    void layout();
    // Set while properties arrive during creation: rebuilt once, when complete.
    bool m_rebuildPending = false;
    // Whether the layout holds the whole text, unelided, as last shaped.
    bool m_shapedFull = false;
    // Whether the text was cut at the preview length: then always elided.
    bool m_capped = false;
    qreal shape(int length, bool ellipsis);
    QList<ChatTextSegment> m_segments = {};
    bool m_edited = false;
    QString m_text;
    QList<QTextLayout::FormatRange> m_formats;
    QList<int> m_boundaries;
    QTextLayout m_layout;
    qreal m_naturalWidth = 0;
    qreal m_fitMinimum = -1;
    qreal m_fitMaximum = -1;
    int m_cutIndex = -1;
    qreal m_ellipsisWidth = 0;
    bool m_truncated = false;
    // Paragraph direction from the first strong character, as Text resolves it.
    bool m_rightToLeft = false;
    // Measured once per rebuild on the full text and the appearance's minimum
    // line, so resizing never changes the height or moves the baseline.
    qreal m_baseline = 0;
    qreal m_height = 0;
    quint64 m_revision = 0;
};
