#pragma once

#include <QObject>
#include <QFont>
#include <qqmlintegration.h>

class Fonts: public QObject {
    Q_OBJECT
    QML_SINGLETON

    Q_PROPERTY(QFont baseFont READ baseFont CONSTANT FINAL)
    // monoFont shares baseFont's family; QML must also bind font.features.
    Q_PROPERTY(QFont monoFont READ monoFont CONSTANT FINAL)
    Q_PROPERTY(QFont codeFont READ codeFont CONSTANT FINAL)
    // The bundled emoji font. Text that is only ever an emoji should use this
    // family, so its line box - and therefore vertical centering - comes from the
    // emoji font rather than from whatever family the item inherited.
    Q_PROPERTY(QFont emojiFont READ emojiFont CONSTANT FINAL)
    // Height of the emoji artwork relative to the font size, measured from the
    // bundled emoji font. To fill a box of N pixels: pixelSize = N / emojiArtRatio.
    Q_PROPERTY(qreal emojiArtRatio READ emojiArtRatio CONSTANT FINAL)

public:
    explicit Fonts(QObject *parent = nullptr);

private:
    void initFonts();

    QFont m_baseFont;
    QFont baseFont() const { return m_baseFont; }

    QFont m_monoFont;
    QFont monoFont() const { return m_monoFont; }

    QFont m_codeFont;
    QFont codeFont() const { return m_codeFont; }

    QFont m_emojiFont;
    QFont emojiFont() const { return m_emojiFont; }

    qreal m_emojiArtRatio = 1.0;
    qreal emojiArtRatio() const { return m_emojiArtRatio; }
};
