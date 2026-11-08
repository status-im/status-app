#pragma once

#include <QDate>
#include <QElapsedTimer>
#include <QObject>
#include <QPointer>
#include <QRectF>
#include <QSet>

#include <memory>

class MessageHeaderAppearance;
class MessageHeaderItem;
struct MessageHeaderTimeFormats;
struct MessageHeaderShapedText;
class MessageHeaderTextCache;
class QFont;
class QQmlComponent;
class QQuickItem;

// Runtime coordination shared by the message headers of a view: one clock
// subscription, one tooltip and the definition of the resend control.
// StatusMessageHeaderServices supplies the QML parts; create it once per view.
class MessageHeaderServices : public QObject
{
    Q_OBJECT
    // Instantiated with a required `header` property, only for headers that
    // currently show a resend control.
    Q_PROPERTY(QQmlComponent* resendButton READ resendButton WRITE setResendButton
               NOTIFY resendButtonChanged)
    // Positioned over the hovered region of the header that owns the tooltip.
    Q_PROPERTY(QQuickItem* tooltipAnchor READ tooltipAnchor WRITE setTooltipAnchor
               NOTIFY tooltipAnchorChanged)
    Q_PROPERTY(bool tooltipVisible READ tooltipVisible NOTIFY tooltipChanged)
    Q_PROPERTY(QString tooltipText READ tooltipText NOTIFY tooltipChanged)
    Q_PROPERTY(int tooltipMaxWidth READ tooltipMaxWidth NOTIFY tooltipChanged)
    Q_PROPERTY(QString tooltipObjectName READ tooltipObjectName NOTIFY tooltipChanged)
    Q_PROPERTY(QQuickItem* tooltipHeader READ tooltipHeader NOTIFY tooltipChanged)
    Q_PROPERTY(int clockSubscriberCount READ clockSubscriberCount NOTIFY clockSubscriberCountChanged)
public:
    explicit MessageHeaderServices(QObject* parent = nullptr);
    ~MessageHeaderServices() override;

    QQmlComponent* resendButton() const { return m_resendButton; }
    void setResendButton(QQmlComponent* component);
    QQuickItem* tooltipAnchor() const { return m_anchor; }
    void setTooltipAnchor(QQuickItem* anchor);
    bool tooltipVisible() const { return m_tooltipVisible; }
    QString tooltipText() const { return m_tooltipText; }
    int tooltipMaxWidth() const { return m_tooltipMaxWidth; }
    QString tooltipObjectName() const { return m_tooltipObjectName; }
    QQuickItem* tooltipHeader() const;
    int clockSubscriberCount() const { return int(m_subscribers.size()); }

    // The calendar environment relative timestamps depend on. Its revision
    // changes only when one of the inputs does, so a once-a-second tick
    // reaches no header on almost every second.
    struct Clock
    {
        QDate today;
        int utcOffset = 0;
        QString localeName;
        quint64 revision = 0;
    };
    const Clock& clock();
    // Locale formats and names for the current clock and preferences, shared
    // by every header of the view.
    const MessageHeaderTimeFormats& timeFormats(const MessageHeaderAppearance* appearance);

    // A shaped single line of `text`, shared by the headers that show it.
    std::shared_ptr<const MessageHeaderShapedText> shapedText(const QString& text, const QFont& font,
                                                              const void* owner, quint64 fontKey);
    qsizetype shapedTextCount() const;

    // Called once a second by the QML adapter's single timer connection.
    Q_INVOKABLE void tick();

    void subscribe(MessageHeaderItem* header);
    void unsubscribe(MessageHeaderItem* header);

    void showTooltip(MessageHeaderItem* header, const QRectF& region, const QString& text,
                     int maxWidth, const QString& objectName);
    // Hides only a tooltip that `header` owns.
    void hideTooltip(MessageHeaderItem* header);

    // A resend control parented to `header`, or nullptr without a definition.
    QQuickItem* createResendButton(MessageHeaderItem* header);

signals:
    void resendButtonChanged();
    void tooltipAnchorChanged();
    void tooltipChanged();
    void clockSubscriberCountChanged();

private:
    bool refreshClock();
    void releaseAnchor();

    QPointer<QQmlComponent> m_resendButton;
    QPointer<QQuickItem> m_anchor;
    QPointer<MessageHeaderItem> m_tooltipOwner;
    bool m_tooltipVisible = false;
    QString m_tooltipText;
    int m_tooltipMaxWidth = -1;
    QString m_tooltipObjectName;
    QSet<MessageHeaderItem*> m_subscribers;
    Clock m_clock;
    std::unique_ptr<MessageHeaderTimeFormats> m_timeFormats;
    std::unique_ptr<MessageHeaderTextCache> m_textCache;
    QElapsedTimer m_clockAge;
};
