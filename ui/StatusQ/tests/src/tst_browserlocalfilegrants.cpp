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

    // What the interceptor does before it asks.
    static bool covered(const BrowserLocalFileGrants &grants, const QString &path)
    {
        return grants.covers(BrowserLocalFileGrants::canonicalPath(path));
    }

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

        QVERIFY(covered(grants, a));
        QVERIFY(!covered(grants, b));
        QVERIFY(!covered(grants, m_dir.path()));
    }

    void aDirectoryGrantCoversWhatItHolds()
    {
        BrowserLocalFileGrants grants;
        QObject view;
        QVERIFY(QDir(m_dir.path()).mkpath("docs/inner"));
        QVERIFY(QDir(m_dir.path()).mkpath("docs-evil"));

        grants.grant(&view, m_dir.filePath("docs"));

        QVERIFY(covered(grants, m_dir.filePath("docs/inner/x.txt")));
        QVERIFY(!covered(grants, m_dir.filePath("docs-evil/x.txt")));
        QVERIFY(!covered(grants, m_dir.filePath("docs/../other.txt")));
    }

    void aGrantEndsWithItsView()
    {
        BrowserLocalFileGrants grants;
        const QString a = touch("ends.txt");
        auto *view = new QObject;

        grants.grant(view, a);
        QVERIFY(covered(grants, a));

        delete view;
        QVERIFY(!covered(grants, a));
    }

    void aLaterGrantReplacesTheViewsEarlierOne()
    {
        BrowserLocalFileGrants grants;
        QObject view;
        const QString first = touch("first.txt");
        const QString second = touch("second.txt");

        grants.grant(&view, first);
        grants.grant(&view, second);

        QVERIFY(!covered(grants, first));
        QVERIFY(covered(grants, second));
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

        QVERIFY(covered(grants, a));
        QVERIFY(!covered(grants, b));
    }

    void aSymlinkedPathMatchesItsTarget()
    {
        BrowserLocalFileGrants grants;
        QObject view;
        const QString real = touch("real.txt");
        const QString link = m_dir.filePath("link.txt");
        QVERIFY(QFile::link(real, link));

        grants.grant(&view, link);

        QVERIFY(covered(grants, real));
    }

    void aCheckTakesItsPathAsGiven()
    {
        BrowserLocalFileGrants grants;
        QObject view;
        const QString real = touch("given.txt");
        const QString link = m_dir.filePath("given-link.txt");
        QVERIFY(QFile::link(real, link));

        grants.grant(&view, real);

        QVERIFY(grants.covers(BrowserLocalFileGrants::canonicalPath(real)));
        QVERIFY(!grants.covers(link));
    }
};

QTEST_GUILESS_MAIN(TestBrowserLocalFileGrants)
#include "tst_browserlocalfilegrants.moc"
