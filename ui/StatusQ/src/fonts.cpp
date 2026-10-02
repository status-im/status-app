#include "StatusQ/fonts.h"

#include <QFontDatabase>
#include <QDebug>
#include <QElapsedTimer>
#include <QResource>

using namespace Qt::Literals::StringLiterals;

namespace {
constexpr auto qrcPrefix = ":/assets/fonts/"_L1;

constexpr auto loadFont = [](QLatin1StringView fontRelPath) {
    const auto fontPath = qrcPrefix + fontRelPath;
    const QResource resource(fontPath);
    if (!resource.isValid() || resource.size() == 0) {
        qWarning() << "!!! MISSING OR EMPTY FONT RESOURCE:" << fontPath;
        return -1;
    }
    if (resource.compressionAlgorithm() != QResource::NoCompression) {
        qWarning() << "!!! FONT RESOURCE MUST BE UNCOMPRESSED:" << fontPath;
        return -1;
    }

    // fonts.qrc is compiled into StatusQ and outlives the font database. Keep a
    // non-owning view to avoid Qt's resource readAll() copy; platform font
    // backends may still make their own copies
    // (currently all platforms respect that, except Window GDI backend)
    const auto data = QByteArray::fromRawData(
        reinterpret_cast<const char *>(resource.data()), resource.size());
    const auto id = QFontDatabase::addApplicationFontFromData(data);
    if (id == -1)
        qWarning() << "!!! COULDN'T LOAD FONT FROM:" << fontPath;
    return id;
};

constexpr auto loadAndAssignFont = [](QLatin1StringView fontRelPath, QFont& font) {
    const auto id = loadFont(fontRelPath);
    if (id != -1) {
        const auto families = QFontDatabase::applicationFontFamilies(id);
        if (families.isEmpty()) {
            qWarning() << "!!! EMPTY FONT ???" << fontRelPath;
            return;
        }
        font = QFont(families);
    }
};
}

Fonts::Fonts(QObject *parent)
    : QObject(parent)
{
    initFonts();
}

void Fonts::initFonts()
{
#ifdef QT_DEBUG
    QElapsedTimer t;
    t.start();
#endif
    // main fonts
    loadAndAssignFont("Inter/Inter-Regular.otf"_L1, m_baseFont);
    loadAndAssignFont("InterStatus/InterStatus-Regular.otf"_L1, m_monoFont);
    loadAndAssignFont("RobotoMono/RobotoMono-Regular.ttf"_L1, m_codeFont);

    // Inter (baseFont) styles
    loadFont("Inter/Inter-Thin.otf"_L1);
    loadFont("Inter/Inter-ExtraLight.otf"_L1);
    loadFont("Inter/Inter-Light.otf"_L1);
    loadFont("Inter/Inter-Medium.otf"_L1);
    loadFont("Inter/Inter-Bold.otf"_L1);
    loadFont("Inter/Inter-ExtraBold.otf"_L1);
    loadFont("Inter/Inter-Black.otf"_L1);

    // Inter Status (monoFont) styles
    loadFont("InterStatus/InterStatus-Thin.otf"_L1);
    loadFont("InterStatus/InterStatus-ExtraLight.otf"_L1);
    loadFont("InterStatus/InterStatus-Light.otf"_L1);
    loadFont("InterStatus/InterStatus-Medium.otf"_L1);
    loadFont("InterStatus/InterStatus-Bold.otf"_L1);
    loadFont("InterStatus/InterStatus-ExtraBold.otf"_L1);
    loadFont("InterStatus/InterStatus-ExtraBoldItalic.otf"_L1);
    loadFont("InterStatus/InterStatus-Black.otf"_L1);

    // Roboto Mono (codeFont) styles
    loadFont("RobotoMono/RobotoMono-Thin.ttf"_L1);
    loadFont("RobotoMono/RobotoMono-ExtraLight.ttf"_L1);
    loadFont("RobotoMono/RobotoMono-Light.ttf"_L1);
    loadFont("RobotoMono/RobotoMono-Medium.ttf"_L1);
    loadFont("RobotoMono/RobotoMono-Bold.ttf"_L1);

#ifdef QT_DEBUG
    qInfo()
        << "!!! ADDING FONTS TOOK" << t.nsecsElapsed() / 1'000'000.f << "ms";
#endif
}
