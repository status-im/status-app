#pragma once

#include "StatusQ/themepalette.h"

#include <QJSValue>
#include <QMetaObject>
#include <QQmlEngine>
#include <QQuickAttachedPropertyPropagator>

class QQuickItem;

class Theme : public QQuickAttachedPropertyPropagator
{
    Q_OBJECT

    Q_PROPERTY(qreal defaultPadding READ defaultPadding CONSTANT)

    Q_PROPERTY(qreal defaultXlPadding READ defaultXlPadding CONSTANT)
    Q_PROPERTY(qreal defaultBigPadding READ defaultBigPadding CONSTANT)
    Q_PROPERTY(qreal defaultHalfPadding READ defaultHalfPadding CONSTANT)
    Q_PROPERTY(qreal defaultSmallPadding READ defaultSmallPadding CONSTANT)

    Q_PROPERTY(qreal padding READ padding WRITE setPadding
                   RESET resetPadding NOTIFY paddingChanged)
    Q_PROPERTY(qreal xlPadding READ xlPadding NOTIFY paddingChanged)
    Q_PROPERTY(qreal bigPadding READ bigPadding NOTIFY paddingChanged)
    Q_PROPERTY(qreal halfPadding READ halfPadding NOTIFY paddingChanged)
    Q_PROPERTY(qreal smallPadding READ smallPadding NOTIFY paddingChanged)
    Q_PROPERTY(qreal radius READ radius CONSTANT)

    Q_PROPERTY(bool explicitPadding READ explicitPadding
                   NOTIFY explicitPaddingChanged)

    Q_PROPERTY(Style style READ style WRITE setStyle RESET resetStyle
                   NOTIFY styleChanged)
    Q_PROPERTY(const ThemePalette* palette READ palette
                   NOTIFY styleChanged)

    Q_PROPERTY(bool explicitStyle READ explicitStyle
                   NOTIFY explicitStyleChanged)

    Q_PROPERTY(int fontSizeOffset READ fontSizeOffset WRITE setFontSizeOffset
                   RESET resetFontSizeOffset NOTIFY fontSizeOffsetChanged)

    Q_PROPERTY(int secondaryAdditionalTextSize
                   READ secondaryAdditionalTextSize
                   NOTIFY fontSizeOffsetChanged)
    Q_PROPERTY(int primaryTextFontSize READ primaryTextFontSize
                   NOTIFY fontSizeOffsetChanged)
    Q_PROPERTY(int secondaryTextFontSize READ secondaryTextFontSize
                   NOTIFY fontSizeOffsetChanged)
    Q_PROPERTY(int additionalTextSize READ additionalTextSize
                   NOTIFY fontSizeOffsetChanged)
    Q_PROPERTY(int tertiaryTextFontSize READ tertiaryTextFontSize
                   NOTIFY fontSizeOffsetChanged)
    Q_PROPERTY(int asideTextFontSize READ asideTextFontSize
                   NOTIFY fontSizeOffsetChanged)

    Q_PROPERTY(bool explicitFontSizeOffset READ explicitFontSizeOffset
                   NOTIFY explicitFontSizeOffsetChanged)

    Q_PROPERTY(QJSValue fontSize READ fontSize NOTIFY fontSizeOffsetChanged)

    enum class Style {
        Light,
        Dark
    };

    Q_ENUM(Style)

public:
    explicit Theme(QObject *parent = nullptr);

    // paddings
    qreal defaultPadding() const;
    qreal defaultXlPadding() const;
    qreal defaultBigPadding() const;
    qreal defaultHalfPadding() const;
    qreal defaultSmallPadding() const;

    qreal padding() const;
    qreal xlPadding() const;
    qreal bigPadding() const;
    qreal halfPadding() const;
    qreal smallPadding() const;
    qreal radius() const;

    void setPadding(qreal padding);
    void resetPadding();
    bool explicitPadding() const;

    // light/dark style
    Style style() const;
    const ThemePalette* palette() const;

    void setStyle(Style style);
    void resetStyle();
    bool explicitStyle() const;

    // font size
    int fontSizeOffset() const;
    int secondaryAdditionalTextSize() const;
    int primaryTextFontSize() const;
    int secondaryTextFontSize() const;
    int additionalTextSize() const;
    int tertiaryTextFontSize() const;
    int asideTextFontSize() const;

    QJSValue fontSize() const;

    void setFontSizeOffset(int fontSizeOffset);
    void resetFontSizeOffset();
    bool explicitFontSizeOffset() const;

    // top level object access
    Q_INVOKABLE Theme* rootTheme();

    // attached object instantiation
    static Theme *qmlAttachedProperties(QObject *object);

signals:
    void paddingChanged();
    void explicitPaddingChanged();

    void styleChanged();
    void explicitStyleChanged();

    void fontSizeOffsetChanged();
    void explicitFontSizeOffsetChanged();

protected:
    void inheritPadding(qreal padding);
    void propagatePadding();

    void inheritStyle(Style style);
    void propagateStyle();

    void inheritFontSizeOffset(int fontSizeOffset);
    void propagateFontSizeOffset();

    void attachedParentChange(
        QQuickAttachedPropertyPropagator *newParent,
        QQuickAttachedPropertyPropagator *oldParent) override;

private:
    void attachWindowReadySync(QQuickItem *itemParent);

    bool m_explicitPadding = false;
    qreal m_padding = 0.0;

    bool m_explicitStyle = false;
    Style m_style = Style::Light;

    bool m_explicitFontSizeOffset = false;
    int m_fontSizeOffset = 0;
    mutable QJSValue m_fontSizeFn;

    QMetaObject::Connection m_windowChangedConnection;
};

QML_DECLARE_TYPEINFO(Theme, QML_HAS_ATTACHED_PROPERTIES)
