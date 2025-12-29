#pragma once

#include <QQuickItem>
#include <QUrl>

class NativeIndicatorItem : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)

public:
    explicit NativeIndicatorItem(QQuickItem *parent = nullptr);
    ~NativeIndicatorItem() override = default;

    QUrl source() const { return m_source; }
    void setSource(const QUrl &source);

signals:
    void sourceChanged();

protected:
    virtual void syncToNative();

private:
    QUrl m_source;
};
