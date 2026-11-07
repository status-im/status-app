#include <StatusQ/openedfileintake.h>

#include <QObject>
#include <QTest>
#include <QUrl>
#include <QVariantMap>

using namespace Status;

class TestOpenedFileIntake : public QObject
{
    Q_OBJECT

private slots:
    void anUndescribedFileHasNoDescription()
    {
        QVERIFY(OpenedFileIntake::description("content://com.example.files/doc/1").isEmpty());
    }

    void aDescribedFileKeepsWhatThePlatformSaid()
    {
        const QString url = "content://com.example.files/doc/2";
        OpenedFileIntake::describe(url, "report.pdf", "application/pdf", true);

        const QVariantMap description = OpenedFileIntake::description(url);
        QCOMPARE(description.value("name").toString(), QString("report.pdf"));
        QCOMPARE(description.value("mimeType").toString(), QString("application/pdf"));
        QCOMPARE(description.value("readable").toBool(), true);
        OpenedFileIntake::forget(url);
    }

    void anUnreadableFileIsDescribedAsSuch()
    {
        const QString url = "content://com.example.files/doc/3";
        OpenedFileIntake::describe(url, "notes.txt", "text/plain", false);

        const QVariantMap description = OpenedFileIntake::description(url);
        QVERIFY(!description.isEmpty());
        QCOMPARE(description.value("readable").toBool(), false);
        OpenedFileIntake::forget(url);
    }

    void theUrlAsQUrlPrintsItFindsTheSameDescription()
    {
        const QString url = "content://com.Example.Files/doc/a%20b";
        OpenedFileIntake::describe(url, "a b.txt", "text/plain", true);

        const QString printed = QUrl(url).toString();
        QCOMPARE(OpenedFileIntake::description(printed).value("name").toString(), QString("a b.txt"));
        OpenedFileIntake::forget(printed);
        QVERIFY(OpenedFileIntake::description(url).isEmpty());
    }

    void aForgottenFileHasNoDescription()
    {
        const QString url = "content://com.example.files/doc/4";
        OpenedFileIntake::describe(url, "song.mp3", "audio/mpeg", true);
        OpenedFileIntake::forget(url);

        QVERIFY(OpenedFileIntake::description(url).isEmpty());
    }
};

QTEST_GUILESS_MAIN(TestOpenedFileIntake)
#include "tst_openedfileintake.moc"
