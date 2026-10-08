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
            return -1;
        }
        font = QFont(families);
    }
    return id;
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
    // Inter (baseFont & monoFont) styles
    const auto baseFontId = loadAndAssignFont("InterVariable.ttf"_L1, m_baseFont);
    loadFont("InterVariable-Italic.ttf"_L1);

    // Roboto Mono (codeFont)
    loadAndAssignFont("RobotoMono-VariableFont_wght.ttf"_L1, m_codeFont);
    loadFont("RobotoMono-Italic-VariableFont_wght.ttf"_L1);

    // monoFont fine tuning (https://rsms.me/inter/#features)
    if (baseFontId != -1) {
        m_monoFont = m_baseFont;
        for (auto tag: {"tnum", "ss02"}) {
            const auto feature = QFont::Tag::fromString(tag);
            if (feature)
                m_monoFont.setFeature(*feature, true);
        }
    }

#ifdef QT_DEBUG
    qInfo()
        << "!!! ADDING FONTS TOOK" << t.nsecsElapsed() / 1'000'000.f << "ms";
#endif
}
