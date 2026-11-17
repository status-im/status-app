#include <StatusQ/audioutils.h>

#include <QSignalSpy>
#include <QTest>

class TestAudioUtils : public QObject
{
    Q_OBJECT

private slots:
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
};

QTEST_MAIN(TestAudioUtils)
#include "tst_audioutils.moc"
