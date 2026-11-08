#pragma once

#include <QObject>
#include <QPointer>
#include <QQmlComponent>
#include <QSet>

class MessageHeaderItem;
class QQuickItem;
Q_MOC_INCLUDE("StatusQ/messageheaderitem.h")

// One instance per view, shared by its headers. Owns no message values.
class MessageHeaderServices : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QQmlComponent* resendDelegate READ resendDelegate WRITE setResendDelegate NOTIFY resendDelegateChanged)
    Q_PROPERTY(MessageHeaderItem* tooltipTarget READ tooltipTarget NOTIFY tooltipTargetChanged)
    Q_PROPERTY(int tooltipPart READ tooltipPart NOTIFY tooltipTargetChanged)
    Q_PROPERTY(int clockSubscriberCount READ clockSubscriberCount NOTIFY clockSubscriberCountChanged)
public:
    explicit MessageHeaderServices(QObject* parent = nullptr);
    ~MessageHeaderServices() override;
    QQmlComponent* resendDelegate() const { return m_resendDelegate; }
    void setResendDelegate(QQmlComponent* value);
    MessageHeaderItem* tooltipTarget() const;
    int tooltipPart() const { return m_tooltipPart; }
    int clockSubscriberCount() const { return m_clock.size(); }
    Q_INVOKABLE void tick();
    void attach(MessageHeaderItem* header);
    void detach(MessageHeaderItem* header);
    void synchronize(MessageHeaderItem* header);
    void requestTooltip(MessageHeaderItem* header, int part);
    void dismissTooltip(MessageHeaderItem* header);
    QQuickItem* createResendItem(MessageHeaderItem* header);
signals:
    void resendDelegateChanged();
    void tooltipTargetChanged();
    void tooltipRequested();
    void tooltipDismissed();
    void clockSubscriberCountChanged();
private:
    QPointer<QQmlComponent> m_resendDelegate;
    QPointer<MessageHeaderItem> m_tooltipTarget;
    int m_tooltipPart = 0;
    QSet<MessageHeaderItem*> m_headers;
    QSet<MessageHeaderItem*> m_clock;
};
