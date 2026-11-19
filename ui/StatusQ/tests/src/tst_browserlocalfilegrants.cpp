#include <StatusQ/browserlocalfilegrants.h>

#include <QDir>
#include <QFile>
#include <QObject>
#include <QTemporaryDir>
#include <QTest>

class TestBrowserLocalFileGrants : public QObject
{
    Q_OBJECT

private:
    QTemporaryDir m_dir;

    QString touch(const QString &name)
    {
        const QString path = m_dir.filePath(name);
        QFile file(path);
        file.open(QIODevice::WriteOnly);
        return path;
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
    }

    void aFileGrantCoversThatFileOnly()
    {
        BrowserLocalFileGrants grants;
        QObject view;
        const QString a = touch("a b.pdf");
        const QString b = touch("b.pdf");

        grants.grant(&view, a);

        QVERIFY(grants.covers(a));
        QVERIFY(!grants.covers(b));
        QVERIFY(!grants.covers(m_dir.path()));
    }

    void aDirectoryGrantCoversWhatItHolds()
    {
        BrowserLocalFileGrants grants;
        QObject view;
        QVERIFY(QDir(m_dir.path()).mkpath("docs/inner"));
        QVERIFY(QDir(m_dir.path()).mkpath("docs-evil"));

        grants.grant(&view, m_dir.filePath("docs"));

        QVERIFY(grants.covers(m_dir.filePath("docs/inner/x.txt")));
        QVERIFY(!grants.covers(m_dir.filePath("docs-evil/x.txt")));
        QVERIFY(!grants.covers(m_dir.filePath("docs/../other.txt")));
    }

    void aGrantEndsWithItsView()
    {
        BrowserLocalFileGrants grants;
        const QString a = touch("ends.txt");
        auto *view = new QObject;

        grants.grant(view, a);
        QVERIFY(grants.covers(a));

        delete view;
        QVERIFY(!grants.covers(a));
    }

    void aLaterGrantReplacesTheViewsEarlierOne()
    {
        BrowserLocalFileGrants grants;
        QObject view;
        const QString first = touch("first.txt");
        const QString second = touch("second.txt");

        grants.grant(&view, first);
        grants.grant(&view, second);

        QVERIFY(!grants.covers(first));
        QVERIFY(grants.covers(second));
    }

    void eachViewKeepsItsOwnGrant()
    {
        BrowserLocalFileGrants grants;
        QObject kept;
        const QString a = touch("kept.txt");
        const QString b = touch("closed.txt");
        {
            QObject closed;
            grants.grant(&kept, a);
            grants.grant(&closed, b);
        }

        QVERIFY(grants.covers(a));
        QVERIFY(!grants.covers(b));
    }

    void aSymlinkedPathMatchesItsTarget()
    {
        BrowserLocalFileGrants grants;
        QObject view;
        const QString real = touch("real.txt");
        const QString link = m_dir.filePath("link.txt");
        QVERIFY(QFile::link(real, link));

        grants.grant(&view, link);

        QVERIFY(grants.covers(real));
    }
};

QTEST_GUILESS_MAIN(TestBrowserLocalFileGrants)
#include "tst_browserlocalfilegrants.moc"
