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
};
