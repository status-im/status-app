#pragma once

#include <QObject>

class AudioUtils : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isSilent READ isSilent NOTIFY isSilentChanged FINAL)

public:
    explicit AudioUtils(QObject *parent = nullptr);
    ~AudioUtils() override;

    Q_INVOKABLE qreal convertLogarithmicToLinearVolumeScale(qreal volume) const;

    // Tracks Android Silent/Vibrate modes; iOS uses the native Ambient audio policy instead.
    bool isSilent() const;
    void updateSilentMode(bool silent);

signals:
    void isSilentChanged();

private:
    bool m_isSilent{false};
};
