#pragma once

#include <QQuickImageProvider>

// Serves image://walletmock/<id>. Every id yields a distinct procedural tile, so
// N generated assets/collectibles cost N decodes and N pixmap-cache entries —
// the image pressure a real wallet produces. A recycled data-URI pool would be
// cached by source URL and cost exactly one.
class MockImageProvider : public QQuickImageProvider
{
public:
    static constexpr auto providerId = "walletmock";

    MockImageProvider();

    QImage requestImage(const QString& id, QSize* size, const QSize& requestedSize) override;
};
