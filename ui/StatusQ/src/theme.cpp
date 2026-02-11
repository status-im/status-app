#include "StatusQ/theme.h"

#include <QMetaObject>
#include <QPointer>
#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QQuickItem>

namespace {

constexpr qreal s_defaultPadding = 16;
constexpr qreal s_xlPaddingFactor = 2.0;
constexpr qreal s_bigPaddingFactor = 1.5;
constexpr qreal s_halfPaddingFactor = 0.5;
constexpr qreal s_smallPaddingFactor = 0.625;

constexpr int s_secondaryAdditionalTextBaseSize = 17;
constexpr int s_primaryTextFontBaseSize = 15;
constexpr int s_secondaryTextFontBaseSize = 14;
constexpr int s_additionalTextBaseSize = 13;
constexpr int s_tertiaryTextFontBaseSize = 12;
constexpr int s_asideTextFontBaseSize = 10;

const std::unique_ptr<ThemePalette> s_paletteDark = createDarkThemePalette();
const std::unique_ptr<ThemePalette> s_paletteLight = createLightThemePalette();

} // unnamed namespace

Theme::Theme(QObject *parent)
    : QQuickAttachedPropertyPropagator(parent), m_padding(s_defaultPadding)
{
    initialize();
}

qreal Theme::defaultPadding() const {
    return s_defaultPadding;
}

qreal Theme::defaultXlPadding() const {
    return s_defaultPadding * s_xlPaddingFactor;
}

qreal Theme::defaultBigPadding() const {
    return s_defaultPadding * s_bigPaddingFactor;
}

qreal Theme::defaultHalfPadding() const {
    return s_defaultPadding * s_halfPaddingFactor;
}

qreal Theme::defaultSmallPadding() const {
    return s_defaultPadding * s_smallPaddingFactor;
}

qreal Theme::padding() const {
    return m_padding;
}

qreal Theme::xlPadding() const {
    return m_padding * s_xlPaddingFactor;
}

qreal Theme::bigPadding() const {
    return m_padding * s_bigPaddingFactor;
}

qreal Theme::halfPadding() const {
    return m_padding * s_halfPaddingFactor;
}

qreal Theme::smallPadding() const {
    return m_padding * s_smallPaddingFactor;
}

qreal Theme::radius() const {
    return s_defaultPadding * s_halfPaddingFactor;
}

void Theme::setPadding(qreal padding)
{
    auto explicitPaddingOld = m_explicitPadding;
    m_explicitPadding = true;

    if (qFuzzyCompare(m_padding, padding)) {
        if (!explicitPaddingOld)
            emit explicitPaddingChanged();

        return;
    }

    m_padding = padding;
    propagatePadding();
    emit paddingChanged();

    if (!explicitPaddingOld)
        emit explicitPaddingChanged();
}

void Theme::resetPadding()
{
    if (!m_explicitPadding)
        return;

    m_explicitPadding = false;
    auto theme = qobject_cast<Theme*>(attachedParent());

    inheritPadding(theme ? theme->padding() : 0);

    emit explicitPaddingChanged();
}

bool Theme::explicitPadding() const {
    return m_explicitPadding;
}

Theme::Style Theme::style() const
{
    return m_style;
}

const ThemePalette* Theme::palette() const
{
    return m_style == Style::Light ? s_paletteLight.get()
                                   : s_paletteDark.get();
}

void Theme::setStyle(Style style)
{
    auto explicitStyleOld = m_explicitStyle;
    m_explicitStyle = true;

    if (m_style == style) {
        if (!explicitStyleOld)
            emit explicitStyleChanged();

        return;
    }

    m_style = style;

    propagateStyle();
    emit styleChanged();

    if (!explicitStyleOld)
        emit explicitStyleChanged();
}

void Theme::resetStyle()
{
    if (!m_explicitStyle)
        return;

    m_explicitStyle = false;
    auto theme = qobject_cast<Theme*>(attachedParent());

    inheritStyle(theme ? theme->style() : Style::Light);

    emit explicitStyleChanged();
}

bool Theme::explicitStyle() const {
    return m_explicitStyle;
}

int Theme::fontSizeOffset() const
{
    return m_fontSizeOffset;
}

int Theme::secondaryAdditionalTextSize() const
{
    return s_secondaryAdditionalTextBaseSize + m_fontSizeOffset;
}

int Theme::primaryTextFontSize() const
{
    return s_primaryTextFontBaseSize + m_fontSizeOffset;
}

int Theme::secondaryTextFontSize() const
{
    return s_secondaryTextFontBaseSize + m_fontSizeOffset;
}

int Theme::additionalTextSize() const
{
    return s_additionalTextBaseSize + m_fontSizeOffset;
}

int Theme::tertiaryTextFontSize() const
{
    return s_tertiaryTextFontBaseSize + m_fontSizeOffset;
}

int Theme::asideTextFontSize() const
{
    return s_asideTextFontBaseSize + m_fontSizeOffset;
}

QJSValue Theme::fontSize() const
{
    if (!m_fontSizeFn.isCallable()) {
        QQmlEngine *engine = qmlEngine(parent());
        if (engine) {
            auto str = QStringLiteral("value => value + %1").arg(m_fontSizeOffset);
            m_fontSizeFn = engine->evaluate(str);
        }
    }
    return m_fontSizeFn;
}

void Theme::setFontSizeOffset(int fontSizeOffset)
{
    auto explicitFontSizeOffsetOld = m_explicitFontSizeOffset;
    m_explicitFontSizeOffset = true;

    if (m_fontSizeOffset == fontSizeOffset) {
        if (!explicitFontSizeOffsetOld)
            emit explicitFontSizeOffsetChanged();

        return;
    }

    m_fontSizeOffset = fontSizeOffset;
    propagateFontSizeOffset();
    m_fontSizeFn = QJSValue();
    emit fontSizeOffsetChanged();

    if (!explicitFontSizeOffsetOld)
        emit explicitFontSizeOffsetChanged();
}

void Theme::resetFontSizeOffset()
{
    if (!m_explicitFontSizeOffset)
        return;

    m_explicitFontSizeOffset = false;
    auto theme = qobject_cast<Theme*>(attachedParent());

    inheritFontSizeOffset(theme ? theme->fontSizeOffset() : 0);

    emit explicitFontSizeOffsetChanged();
}

bool Theme::explicitFontSizeOffset() const
{
    return m_explicitFontSizeOffset;
}

Theme *Theme::rootTheme()
{
    auto theme = qobject_cast<Theme*>(attachedParent());

    if (!theme)
        return this;

    while (true) {
        auto next = qobject_cast<Theme*>(theme->attachedParent());

        if (!next || qobject_cast<QQmlApplicationEngine*>(next->parent()))
            return theme;
        else
            theme = next;
    }
}

Theme* Theme::qmlAttachedProperties(QObject *object)
{
    return new Theme(object);
}

void Theme::inheritPadding(qreal padding)
{
    if (m_explicitPadding || qFuzzyCompare(m_padding, padding))
        return;

    m_padding = padding;
    propagatePadding();
    emit paddingChanged();
}

void Theme::propagatePadding()
{
    const auto children = attachedChildren();
    QList<QPointer<QQuickAttachedPropertyPropagator>> childrenSnapshot;
    childrenSnapshot.reserve(children.size());
    for (QQuickAttachedPropertyPropagator *child : children)
        childrenSnapshot.push_back(QPointer<QQuickAttachedPropertyPropagator>(child));

    for (const QPointer<QQuickAttachedPropertyPropagator> &childGuard : childrenSnapshot) {
        if (!childGuard)
            continue;

        auto theme = qobject_cast<Theme*>(childGuard.data());
        if (theme)
            theme->inheritPadding(m_padding);
    }
}

void Theme::inheritStyle(Style style)
{
    if (m_explicitStyle || m_style == style)
        return;

    m_style = style;
    propagateStyle();
    emit styleChanged();
}

void Theme::propagateStyle()
{
    const auto children = attachedChildren();
    QList<QPointer<QQuickAttachedPropertyPropagator>> childrenSnapshot;
    childrenSnapshot.reserve(children.size());
    for (QQuickAttachedPropertyPropagator *child : children)
        childrenSnapshot.push_back(QPointer<QQuickAttachedPropertyPropagator>(child));

    for (const QPointer<QQuickAttachedPropertyPropagator> &childGuard : childrenSnapshot) {
        if (!childGuard)
            continue;

        auto theme = qobject_cast<Theme*>(childGuard.data());
        if (theme)
            theme->inheritStyle(m_style);
    }
}

void Theme::inheritFontSizeOffset(int fontSizeOffset)
{
    if (m_explicitFontSizeOffset || m_fontSizeOffset == fontSizeOffset)
        return;

    m_fontSizeOffset = fontSizeOffset;
    propagateFontSizeOffset();
    m_fontSizeFn = QJSValue();
    emit fontSizeOffsetChanged();
}

void Theme::propagateFontSizeOffset()
{
    const auto children = attachedChildren();
    QList<QPointer<QQuickAttachedPropertyPropagator>> childrenSnapshot;
    childrenSnapshot.reserve(children.size());
    for (QQuickAttachedPropertyPropagator *child : children)
        childrenSnapshot.push_back(QPointer<QQuickAttachedPropertyPropagator>(child));

    for (const QPointer<QQuickAttachedPropertyPropagator> &childGuard : childrenSnapshot) {
        if (!childGuard)
            continue;

        auto theme = qobject_cast<Theme*>(childGuard.data());
        if (theme)
            theme->inheritFontSizeOffset(m_fontSizeOffset);
    }
}

void Theme::attachedParentChange(QQuickAttachedPropertyPropagator* newParent,
                                 QQuickAttachedPropertyPropagator* oldParent)
{
    Q_UNUSED(oldParent);
    auto attachedParentTheme = qobject_cast<Theme*>(newParent);
    if (attachedParentTheme) {
        const QPointer<Theme> expectedParent = attachedParentTheme;

        // Defer inherited theme propagation to avoid re-entrant geometry/binding
        // updates while the item is being reparented. Read inherited values from
        // the current attached parent when the callback runs to avoid stale state
        // if another reparent happens before the queued callback executes.
        QMetaObject::invokeMethod(this,
                                  [this, expectedParent]() {
            auto currentParentTheme = qobject_cast<Theme*>(attachedParent());
            if (!currentParentTheme || currentParentTheme != expectedParent.data())
                return;

            auto itemParent = qobject_cast<QQuickItem*>(parent());
            if (itemParent && !itemParent->window())
                return;

            inheritPadding(currentParentTheme->padding());
            inheritStyle(currentParentTheme->style());
            inheritFontSizeOffset(currentParentTheme->fontSizeOffset());
        }, Qt::QueuedConnection);
    }
}
