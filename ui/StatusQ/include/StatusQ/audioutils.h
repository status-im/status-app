#pragma once

#include <QObject>
#include <QQueue>
#include <QSoundEffect>
#include <QUrl>

class AudioUtils final: public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool muted READ muted WRITE setMuted NOTIFY mutedChanged FINAL)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged FINAL)
    Q_PROPERTY(bool isSilent READ isSilent NOTIFY isSilentChanged FINAL)

public:
    explicit AudioUtils(QObject *parent = nullptr);
    ~AudioUtils() override;

    // Playback is FIFO, including while loading; stop() cancels current and queued playback.
    Q_INVOKABLE void play(const QUrl& source);
    Q_INVOKABLE void stop();

    Q_INVOKABLE qreal convertLogarithmicToLinearVolumeScale(qreal volume) const;

    bool muted() const;
    void setMuted(bool newMuted);

    qreal volume() const;
    void setVolume(qreal newVolume);

    // Tracks Android Silent/Vibrate modes; iOS uses the native Ambient audio policy instead.
    bool isSilent() const;
    void updateSilentMode(bool silent);

signals:
    void mutedChanged();
    void volumeChanged();
    void isSilentChanged();

private:
    void playNext();
    void onSoundStatusChanged();

    QSoundEffect m_soundEffect;
    QQueue<QUrl> m_soundQueue;
    bool m_playPending{false};

    bool m_muted{false};
    qreal m_volume{0.5};
    bool m_isSilent{false};
};
