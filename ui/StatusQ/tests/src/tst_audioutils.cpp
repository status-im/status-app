#include <StatusQ/audioutils.h>

#include <QAudioDevice>
#include <QDataStream>
#include <QMediaDevices>
#include <QRegularExpression>
#include <QSignalSpy>
#include <QTemporaryFile>
#include <QTest>

namespace {
bool writeSilentWave(QTemporaryFile &file)
{
    if (!file.open())
        return false;

    const QByteArray samples(48000 * 2, '\0');
    QDataStream stream(&file);
    stream.setByteOrder(QDataStream::LittleEndian);
    stream.writeRawData("RIFF", 4);
    stream << quint32(36 + samples.size());
    stream.writeRawData("WAVEfmt ", 8);
    stream << quint32(16) << quint16(1) << quint16(1)
           << quint32(48000) << quint32(96000) << quint16(2) << quint16(16);
    stream.writeRawData("data", 4);
    stream << quint32(samples.size());
    stream.writeRawData(samples.constData(), samples.size());
    return stream.status() == QDataStream::Ok && file.flush();
}
}

class TestAudioUtils : public QObject
{
    Q_OBJECT

private slots:
    void firstPlayWaitsForReadyAndCachedPlayStartsImmediately()
    {
        if (QMediaDevices::audioOutputs().isEmpty())
            QSKIP("No audio output device available");

        QTemporaryFile sound;
        QVERIFY(writeSilentWave(sound));
        AudioUtils utils;
        utils.updateSilentMode(false);
        auto *effect = utils.findChild<QSoundEffect *>();
        QVERIFY(effect);
        bool playedBeforeReady = false;
        connect(effect, &QSoundEffect::playingChanged, this, [&] {
            if (effect->isPlaying() && effect->status() != QSoundEffect::Ready)
                playedBeforeReady = true;
        });

        const auto source = QUrl::fromLocalFile(sound.fileName());
        utils.play(source);
        QCOMPARE(effect->status(), QSoundEffect::Loading);
        QVERIFY(!effect->isPlaying());
        QTRY_VERIFY(effect->isPlaying());
        QVERIFY(!playedBeforeReady);

        utils.stop();
        QVERIFY(!effect->isPlaying());
        utils.play(source);
        QVERIFY(effect->isPlaying());
    }

    void stopCancelsPlaybackWhileLoading()
    {
        if (QMediaDevices::audioOutputs().isEmpty())
            QSKIP("No audio output device available");

        QTemporaryFile sound;
        QTemporaryFile queuedSound;
        QVERIFY(writeSilentWave(sound));
        QVERIFY(writeSilentWave(queuedSound));
        AudioUtils utils;
        utils.updateSilentMode(false);
        auto *effect = utils.findChild<QSoundEffect *>();
        QVERIFY(effect);
        QSignalSpy playingSpy(effect, &QSoundEffect::playingChanged);

        utils.play(QUrl::fromLocalFile(sound.fileName()));
        QCOMPARE(effect->status(), QSoundEffect::Loading);
        utils.play(QUrl::fromLocalFile(queuedSound.fileName()));
        utils.stop();
        QTRY_COMPARE(effect->status(), QSoundEffect::Ready);
        QVERIFY(!effect->isPlaying());
        QCOMPARE(playingSpy.count(), 0);

        utils.play(QUrl::fromLocalFile(sound.fileName()));
        QVERIFY(effect->isPlaying());
        QTRY_VERIFY(!effect->isPlaying());
        QCOMPARE(effect->source(), QUrl::fromLocalFile(sound.fileName()));
        QCOMPARE(playingSpy.count(), 2);
    }

    void requestsWhileLoadingArePlayedInOrder()
    {
        if (QMediaDevices::audioOutputs().isEmpty())
            QSKIP("No audio output device available");

        QTemporaryFile firstSound;
        QTemporaryFile secondSound;
        QVERIFY(writeSilentWave(firstSound));
        QVERIFY(writeSilentWave(secondSound));
        AudioUtils utils;
        utils.updateSilentMode(false);
        auto *effect = utils.findChild<QSoundEffect *>();
        QVERIFY(effect);
        QList<QUrl> playedSources;
        connect(effect, &QSoundEffect::playingChanged, this, [&] {
            if (effect->isPlaying())
                playedSources.append(effect->source());
        });

        const auto firstSource = QUrl::fromLocalFile(firstSound.fileName());
        const auto secondSource = QUrl::fromLocalFile(secondSound.fileName());
        utils.play(firstSource);
        utils.play(secondSource);
        utils.play(secondSource);
        QCOMPARE(effect->source(), firstSource);
        QCOMPARE(effect->status(), QSoundEffect::Loading);

        const QList<QUrl> expectedSources {firstSource, secondSource, secondSource};
        QTRY_COMPARE(playedSources, expectedSources);
        QTRY_VERIFY(!effect->isPlaying());
    }

    void newSourceDoesNotInterruptCurrentPlayback()
    {
        if (QMediaDevices::audioOutputs().isEmpty())
            QSKIP("No audio output device available");

        QTemporaryFile firstSound;
        QTemporaryFile secondSound;
        QVERIFY(writeSilentWave(firstSound));
        QVERIFY(writeSilentWave(secondSound));
        AudioUtils utils;
        utils.updateSilentMode(false);
        auto *effect = utils.findChild<QSoundEffect *>();
        QVERIFY(effect);
        QSignalSpy playingSpy(effect, &QSoundEffect::playingChanged);
        const auto firstSource = QUrl::fromLocalFile(firstSound.fileName());
        const auto secondSource = QUrl::fromLocalFile(secondSound.fileName());

        utils.play(firstSource);
        QTRY_VERIFY(effect->isPlaying());
        utils.play(secondSource);
        QCOMPARE(effect->source(), firstSource);
        QVERIFY(effect->isPlaying());
        QCOMPARE(playingSpy.count(), 1);

        QTRY_COMPARE(effect->source(), secondSource);
        QTRY_VERIFY(effect->isPlaying());
        QCOMPARE(playingSpy.count(), 3);
        QTRY_VERIFY(!effect->isPlaying());
    }

    void stopClearsQueuedPlayback()
    {
        if (QMediaDevices::audioOutputs().isEmpty())
            QSKIP("No audio output device available");

        QTemporaryFile firstSound;
        QTemporaryFile secondSound;
        QVERIFY(writeSilentWave(firstSound));
        QVERIFY(writeSilentWave(secondSound));
        AudioUtils utils;
        utils.updateSilentMode(false);
        auto *effect = utils.findChild<QSoundEffect *>();
        QVERIFY(effect);
        QList<QUrl> playedSources;
        connect(effect, &QSoundEffect::playingChanged, this, [&] {
            if (effect->isPlaying())
                playedSources.append(effect->source());
        });
        const auto firstSource = QUrl::fromLocalFile(firstSound.fileName());

        utils.play(firstSource);
        QTRY_VERIFY(effect->isPlaying());
        utils.play(QUrl::fromLocalFile(secondSound.fileName()));
        utils.stop();
        QVERIFY(!effect->isPlaying());

        utils.play(firstSource);
        QVERIFY(effect->isPlaying());
        QCOMPARE(effect->source(), firstSource);
        QTRY_VERIFY(!effect->isPlaying());
        const QList<QUrl> expectedSources {firstSource, firstSource};
        QCOMPARE(playedSources, expectedSources);
    }

    void failedQueuedSoundDoesNotBlockFollowingPlayback()
    {
        if (QMediaDevices::audioOutputs().isEmpty())
            QSKIP("No audio output device available");

        QTemporaryFile firstSound;
        QTemporaryFile secondSound;
        QVERIFY(writeSilentWave(firstSound));
        QVERIFY(writeSilentWave(secondSound));
        AudioUtils utils;
        utils.updateSilentMode(false);
        auto *effect = utils.findChild<QSoundEffect *>();
        QVERIFY(effect);
        QList<QUrl> playedSources;
        connect(effect, &QSoundEffect::playingChanged, this, [&] {
            if (effect->isPlaying())
                playedSources.append(effect->source());
        });
        const auto firstSource = QUrl::fromLocalFile(firstSound.fileName());
        const auto secondSource = QUrl::fromLocalFile(secondSound.fileName());

        utils.play(firstSource);
        QTRY_VERIFY(effect->isPlaying());
        QTest::ignoreMessage(QtWarningMsg,
                             QRegularExpression(QStringLiteral("^AudioUtils: Cannot load sound:.*")));
        utils.play(QUrl::fromLocalFile(firstSound.fileName() + QStringLiteral(".missing")));
        utils.play(secondSource);

        const QList<QUrl> expectedSources {firstSource, secondSource};
        QTRY_COMPARE(playedSources, expectedSources);
        QTRY_VERIFY(!effect->isPlaying());
    }

    void silentModeEmitsOnlyOnChanges()
    {
        AudioUtils utils;
        utils.updateSilentMode(false);
        QSignalSpy spy(&utils, &AudioUtils::isSilentChanged);

        utils.updateSilentMode(false);
        QCOMPARE(spy.count(), 0);

        utils.updateSilentMode(true);
        QCOMPARE(utils.property("isSilent").toBool(), true);
        QCOMPARE(spy.count(), 1);
        utils.updateSilentMode(true);
        QCOMPARE(spy.count(), 1);

        utils.updateSilentMode(false);
        QCOMPARE(utils.property("isSilent").toBool(), false);
        QCOMPARE(spy.count(), 2);
        utils.updateSilentMode(false);
        QCOMPARE(spy.count(), 2);
    }

    void mutedOrSilentSuppressesPlayback()
    {
        if (QMediaDevices::audioOutputs().isEmpty())
            QSKIP("No audio output device available");
        QTemporaryFile sound;
        QVERIFY(writeSilentWave(sound));
        AudioUtils utils;
        utils.updateSilentMode(false);
        auto *effect = utils.findChild<QSoundEffect *>();
        QVERIFY(effect);
        QSignalSpy playingSpy(effect, &QSoundEffect::playingChanged);
        const auto source = QUrl::fromLocalFile(sound.fileName());
        utils.setMuted(true);
        utils.play(source);
        QCOMPARE(effect->status(), QSoundEffect::Null);
        QCOMPARE(playingSpy.count(), 0);
        utils.setMuted(false);
        utils.updateSilentMode(true);
        utils.play(source);
        QCOMPARE(effect->status(), QSoundEffect::Null);
        QCOMPARE(playingSpy.count(), 0);
        utils.updateSilentMode(false);
        utils.play(source);
        QTRY_VERIFY(effect->isPlaying());
    }
};

QTEST_MAIN(TestAudioUtils)
#include "tst_audioutils.moc"
