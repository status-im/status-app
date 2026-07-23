#pragma once

#include <QInputMethodEvent>
#include <QObject>
#include <QQuickItem>

// Wrapper exposed to QML for a single QInputMethodEvent. Reused per event — do
// not store a reference across the signal handler boundary.
class InputMethodEvent : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString commitString      READ commitString      CONSTANT)
    Q_PROPERTY(QString preeditString     READ preeditString     CONSTANT)
    Q_PROPERTY(int     replacementStart  READ replacementStart  CONSTANT)
    Q_PROPERTY(int     replacementLength READ replacementLength CONSTANT)

public:
    explicit InputMethodEvent(QObject* parent = nullptr);

    void bind(QInputMethodEvent* src);
    bool accepted() const;

    QString commitString() const;
    QString preeditString() const;
    int replacementStart() const;
    int replacementLength() const;

    Q_INVOKABLE void accept();
    Q_INVOKABLE void ignore();

private:
    QInputMethodEvent* m_src = nullptr;
    bool m_accepted = false;
};

// QML-instantiable event filter. Set `target` to a TextArea/TextEdit item;
// the filter intercepts QInputMethodEvent before the item processes it and
// emits inputMethodEventReceived so QML can inspect properties and call
// accept() to consume the event (preventing the default IME text insertion).
class InputMethodEventFilter : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QQuickItem* target READ target WRITE setTarget NOTIFY targetChanged)

public:
    explicit InputMethodEventFilter(QObject* parent = nullptr);
    ~InputMethodEventFilter() override;

    QQuickItem* target() const;
    void setTarget(QQuickItem* target);

    Q_SIGNAL void targetChanged();
    Q_SIGNAL void inputMethodEventReceived(InputMethodEvent* event);

protected:
    bool eventFilter(QObject* watched, QEvent* event) override;

private:
    QQuickItem* m_target = nullptr;
    InputMethodEvent m_event;
};
