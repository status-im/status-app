#include <StatusQ/systemutilsinternal.h>

#include <QGuiApplication>
#include <QSignalSpy>
#include <QTest>

class TestKeyboardState : public QObject
{
    Q_OBJECT

private slots:
    void androidInitialState()
    {
        SystemUtilsInternal utils;

        QCOMPARE(utils.androidKeyboardHeight(), 0);
        QCOMPARE(utils.androidKeyboardVisible(), false);
    }

    void androidHeightImpliesVisible()
    {
        SystemUtilsInternal utils;
        QSignalSpy heightSpy(&utils, &SystemUtilsInternal::androidKeyboardHeightChanged);
        QSignalSpy visibleSpy(&utils, &SystemUtilsInternal::androidKeyboardVisibleChanged);

        utils.updateAndroidKeyboard(840);

        QCOMPARE(utils.androidKeyboardHeight(), 840);
        QCOMPARE(utils.androidKeyboardVisible(), true);
        QCOMPARE(heightSpy.count(), 1);
        QCOMPARE(visibleSpy.count(), 1);

        utils.updateAndroidKeyboard(0);

        QCOMPARE(utils.androidKeyboardHeight(), 0);
        QCOMPARE(utils.androidKeyboardVisible(), false);
        QCOMPARE(heightSpy.count(), 2);
        QCOMPARE(visibleSpy.count(), 2);
    }

    void androidSameValueDoesNotEmit()
    {
        SystemUtilsInternal utils;
        utils.updateAndroidKeyboard(840);

        QSignalSpy heightSpy(&utils, &SystemUtilsInternal::androidKeyboardHeightChanged);
        QSignalSpy visibleSpy(&utils, &SystemUtilsInternal::androidKeyboardVisibleChanged);

        utils.updateAndroidKeyboard(840);
        utils.updateAndroidKeyboard(840);

        QCOMPARE(heightSpy.count(), 0);
        QCOMPARE(visibleSpy.count(), 0);

        utils.updateAndroidKeyboard(0);
        utils.updateAndroidKeyboard(0);

        QCOMPARE(heightSpy.count(), 1);
        QCOMPARE(visibleSpy.count(), 1);
    }

    void androidHeightChangeWhileVisibleEmitsHeightOnly()
    {
        SystemUtilsInternal utils;
        utils.updateAndroidKeyboard(840);

        QSignalSpy heightSpy(&utils, &SystemUtilsInternal::androidKeyboardHeightChanged);
        QSignalSpy visibleSpy(&utils, &SystemUtilsInternal::androidKeyboardVisibleChanged);

        utils.updateAndroidKeyboard(960);

        QCOMPARE(utils.androidKeyboardHeight(), 960);
        QCOMPARE(heightSpy.count(), 1);
        QCOMPARE(visibleSpy.count(), 0);
    }

    void iosEmitsOncePerChange()
    {
        SystemUtilsInternal utils;
        QSignalSpy heightSpy(&utils, &SystemUtilsInternal::iosKeyboardHeightChanged);
        QSignalSpy visibleSpy(&utils, &SystemUtilsInternal::iosKeyboardVisibleChanged);

        utils.updateIOSKeyboard(1000, true);
        utils.updateIOSKeyboard(1000, true);

        QCOMPARE(utils.iosKeyboardHeight(), 1000);
        QCOMPARE(utils.iosKeyboardVisible(), true);
        QCOMPARE(heightSpy.count(), 1);
        QCOMPARE(visibleSpy.count(), 1);

        utils.updateIOSKeyboard(0, false);
        utils.updateIOSKeyboard(0, false);

        QCOMPARE(utils.iosKeyboardHeight(), 0);
        QCOMPARE(utils.iosKeyboardVisible(), false);
        QCOMPARE(heightSpy.count(), 2);
        QCOMPARE(visibleSpy.count(), 2);
    }
};

QTEST_MAIN(TestKeyboardState)
#include "tst_keyboardstate.moc"
