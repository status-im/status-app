#include <QNetworkRequest>
#include <QTest>
#include <QUrl>

#include <StatusQ/networkaccessfactory.h>


namespace {

constexpr auto expectedAccept = "image/webp,image/png,image/jpeg";

QNetworkRequest requestFor(const QString& url)
{
    return QNetworkRequest(QUrl(url));
}

} // namespace

class tst_NetworkAccessFactory : public QObject
{
    Q_OBJECT

private slots:
    void withAcceptedImageFormats_data()
    {
        QTest::addColumn<QString>("url");
        QTest::addColumn<bool>("hinted");

        QTest::newRow("cloudinary image delivery")
            << "https://res.cloudinary.com/alchemyapi/image/upload/w_300,c_limit,f_auto,q_auto/"
               "https%3A%2F%2Fexample.com%2Fnft.png"
            << true;

        QTest::newRow("cloudinary image delivery, untransformed")
            << "https://res.cloudinary.com/alchemyapi/image/upload/convert-png/nft" << true;

        // The header is a claim about this client's decoders, so it does not
        // depend on the transformation the URL happens to carry.
        QTest::newRow("cloudinary image delivery, no f_auto")
            << "https://res.cloudinary.com/alchemyapi/image/upload/w_300,c_limit/nft" << true;

        // The still frame of an animated collectible — the most expensive thing the
        // CDN hands us, and it carries f_auto just like /image/upload/ does.
        QTest::newRow("cloudinary video fetch")
            << "https://res.cloudinary.com/alchemyapi/video/fetch/w_300,c_limit,f_auto,q_auto/"
               "f_png,so_0/https%3A%2F%2Fexample.com%2Fnft.mp4"
            << true;

        QTest::newRow("cloudinary video fetch, untransformed")
            << "https://res.cloudinary.com/alchemyapi/video/fetch/f_png,so_0/"
               "https%3A%2F%2Fexample.com%2Fnft.mp4"
            << true;

        QTest::newRow("cloudinary, other path")
            << "https://res.cloudinary.com/alchemyapi/raw/upload/blob" << false;

        // Same manager serves status-go, XHR and everything else the QML layer
        // fetches; none of it is Cloudinary and none of it gets the header.
        QTest::newRow("other host, cloudinary-shaped path")
            << "https://cdn.example.com/alchemyapi/image/upload/f_auto/nft" << false;

        QTest::newRow("local status-go media server")
            << "http://localhost:52286/collectibles?uid=1" << false;

        QTest::newRow("no host") << "qrc:/assets/img/icons/nft.svg" << false;
    }

    void withAcceptedImageFormats()
    {
        QFETCH(QString, url);
        QFETCH(bool, hinted);

        const QNetworkRequest result = Status::withAcceptedImageFormats(requestFor(url));

        QCOMPARE(result.rawHeader("Accept"), hinted ? QByteArray(expectedAccept) : QByteArray());
        QCOMPARE(result.url(), QUrl(url));
    }

    void withAcceptedImageFormats_keepsCallerAccept()
    {
        QNetworkRequest request = requestFor(
            "https://res.cloudinary.com/alchemyapi/image/upload/f_auto/nft");
        request.setRawHeader("Accept", "image/svg+xml");

        const QNetworkRequest result = Status::withAcceptedImageFormats(request);

        QCOMPARE(result.rawHeader("Accept"), QByteArray("image/svg+xml"));
    }

    void withAcceptedImageFormats_keepsEverythingElse()
    {
        QNetworkRequest request = requestFor(
            "https://res.cloudinary.com/alchemyapi/image/upload/f_auto/nft");
        request.setRawHeader("User-Agent", "StatusDesktop");
        request.setAttribute(QNetworkRequest::CacheLoadControlAttribute,
                             QNetworkRequest::PreferCache);

        const QNetworkRequest result = Status::withAcceptedImageFormats(request);

        QCOMPARE(result.rawHeader("Accept"), QByteArray(expectedAccept));
        QCOMPARE(result.rawHeader("User-Agent"), QByteArray("StatusDesktop"));
        QCOMPARE(result.attribute(QNetworkRequest::CacheLoadControlAttribute).toInt(),
                 int(QNetworkRequest::PreferCache));
    }
};

QTEST_MAIN(tst_NetworkAccessFactory)
#include "tst_networkaccessfactory.moc"
