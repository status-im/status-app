#include "StatusQ/messageheaderitem.h"

#include <QCache>
#include <QDateTime>
#include <QLocale>
#include <QRegularExpression>
#include <QTimeZone>
#include <QFontMetricsF>
#include <QHoverEvent>
#include <QPointingDevice>
#include <QImageReader>
#include <QMouseEvent>
#include <QPainter>
#include <QQuickWindow>
#include <QSGSimpleTextureNode>
#include <QSGTextNode>
#include <QTextLayout>
#include <QUrl>
#include <algorithm>
#include <cmath>
#include <tuple>
#include <utility>

namespace {
// Software scene-graph updates recover inherited transform/clip state from
// the immediate parent. Keep these persistent parents as transform nodes so
// replacing a text subtree preserves the item's position and scrolling clip.
struct RootNode : QSGTransformNode { };
struct PartNode : QSGTransformNode {
    quint64 revision = 0;
    QPointF position;
};

// Image data is shared across headers. Textures belong to the render thread
// and their nodes; no window or scene-graph resources are kept in this cache.
QImage iconImage(const QUrl& url, int size, qreal dpr, const QColor& color)
{
    static QCache<QString, QImage> cache(1024); // cost is KiB
    const QString key = url.toString() + QString::number(size) + QLatin1Char('/')
            + QString::number(dpr) + (color.isValid() ? color.name(QColor::HexArgb) : QStringLiteral("original"));
    if (const auto* image = cache.object(key))
        return *image;
    const QString path = url.scheme() == QStringLiteral("qrc") ? QLatin1Char(':') + url.path()
                                                              : url.toLocalFile();
    QImageReader reader(path);
    reader.setScaledSize(QSize(qCeil(size * dpr), qCeil(size * dpr)));
    QImage image = reader.read().convertToFormat(QImage::Format_ARGB32_Premultiplied);
    if (!image.isNull()) {
        if (color.isValid()) {
            QPainter painter(&image);
            painter.setCompositionMode(QPainter::CompositionMode_SourceIn);
            painter.fillRect(image.rect(), color);
        }
        image.setDevicePixelRatio(dpr);
        cache.insert(key, new QImage(image), qMax(1, int(image.sizeInBytes() / 1024)));
    }
    return image;
}

QString timePattern(QString pattern, bool defaults, bool use24Hours)
{
    if (defaults) return pattern;
    if (use24Hours) {
        static const QRegularExpression ampm(QStringLiteral("\\ba\\b|\\bap\\b"), QRegularExpression::CaseInsensitiveOption);
        pattern.remove(ampm);
        return pattern.replace(QLatin1Char('h'), QLatin1Char('H'));
    }
    pattern.replace(QLatin1Char('H'), QLatin1Char('h'));
    // Match LocaleUtils' supported AM/PM tokens.
    if (!pattern.contains(QStringLiteral("AP")) && !pattern.contains(QStringLiteral("ap"))
            && !pattern.contains(QLatin1Char('A')) && !pattern.contains(QLatin1Char('a')))
        pattern += QStringLiteral(" ap");
    return pattern;
}

QString fullTimestamp(qint64 timestamp, const QLocale& locale, bool defaults, bool use24Hours,
                      QLocale::FormatType format = QLocale::LongFormat)
{
    QString pattern = timePattern(locale.dateTimeFormat(format), defaults, use24Hours);
    if (format == QLocale::ShortFormat && !pattern.contains(QStringLiteral("yyyy")))
        pattern.replace(QStringLiteral("yy"), QStringLiteral("yyyy"));
    return locale.toString(QDateTime::fromMSecsSinceEpoch(timestamp), pattern);
}

QString relativeTimestamp(qint64 timestamp, const QDate& today, const QLocale& locale,
                          bool defaults, bool use24Hours, const QStringList& formats)
{
    const auto value = QDateTime::fromMSecsSinceEpoch(timestamp);
    const auto date = value.date();
    const QString time = locale.toString(value.time(), timePattern(locale.timeFormat(QLocale::ShortFormat), defaults, use24Hours));
    const auto days = qAbs(date.daysTo(today));
    if (days < 1)
        return formats.at(0).arg(time);
    if (days < 2)
        return formats.at(1).arg(time);
    if (days < 7) {
        // QML uses Sunday=0; QLocale uses Sunday=7. QDate already uses
        // QLocale's numbering, so no JS-style conversion is needed.
        return formats.at(2)
                .arg(locale.standaloneDayName(date.dayOfWeek(), QLocale::ShortFormat), time);
    }
    if (date.year() == today.year()) {
        const QString longTime = locale.timeFormat(QLocale::LongFormat);
        const bool default24Hours = !longTime.contains(QStringLiteral("AP")) && !longTime.contains(QStringLiteral("ap"))
                && !longTime.contains(QLatin1Char('A')) && !longTime.contains(QLatin1Char('a'));
        return locale.toString(date, default24Hours ? QStringLiteral("d MMM") : QStringLiteral("MMM d"))
                + QLatin1Char(' ') + time;
    }
    return fullTimestamp(timestamp, locale, defaults, use24Hours, QLocale::ShortFormat);
}

}

struct MessageHeaderItem::Part {
    QString text;
    QFont font;
    QColor color;
    std::unique_ptr<QTextLayout> layout;
    QImage image;
    QPointF position;
    QSizeF size;
    int role = None;
    PartKey key = PartKey::Name;
    quint64 revision = 0;
    qreal lineWidth = -1;
    qreal naturalWidth = 0;
};

struct MessageHeaderItem::TimestampCache {
    bool initialized = false;
    qint64 timestamp = 0;
    bool full = false, defaults = true, use24Hours = false;
    QLocale locale;
    QString language;
    QStringList formats;
    QDate today;
    QByteArray zone;
    int utcOffset = 0;
    QString text;
};

QString MessageHeaderItem::timestampText() const
{
    return m_timestampCache ? m_timestampCache->text : QString();
}

QString MessageHeaderItem::fullTimestampText() const
{
    if (!m_timestampCache || !m_timestampCache->initialized) return {};
    const auto& cache = *m_timestampCache;
    return fullTimestamp(cache.timestamp, cache.locale, cache.defaults, cache.use24Hours);
}

void MessageHeaderItem::setServices(MessageHeaderServices* value)
{
    if (m_services == value) return;
    if (m_services) m_services->detach(this);
    clearResendItem();
    m_services = value;
    if (m_services) m_services->attach(this);
    if (isComponentComplete()) syncResendItem();
    scheduleLayout(GeometryDirty);
    emit servicesChanged();
}

void MessageHeaderItem::clearResendItem()
{
    if (!m_resendItem) return;
    auto* item = m_resendItem.data();
    m_resendItem = nullptr;
    setTrailingItem(nullptr);
    item->setVisible(false);
    item->setEnabled(false);
    item->deleteLater();
}

void MessageHeaderItem::syncResendItem()
{
    const bool required = m_services && (m_showOutgoingStatusLabel || m_isMobile) && expired();
    if (!required) { clearResendItem(); return; }
    if (!m_resendItem) {
        m_resendItem = m_services->createResendItem(this);
        if (m_resendItem) setTrailingItem(m_resendItem);
    }
}

void MessageHeaderItem::setTrailingItem(QQuickItem* item)
{
    if (item == m_trailingItem) return;
    if (m_trailingItem) disconnect(m_trailingItem, nullptr, this, nullptr);
    m_trailingItem = item;
    if (item) {
        const auto relayout = [this] { scheduleLayout(GeometryDirty); };
        connect(item, &QQuickItem::implicitWidthChanged, this, relayout);
        connect(item, &QQuickItem::implicitHeightChanged, this, relayout);
        connect(item, &QObject::destroyed, this, [this] {
            m_trailingItem = nullptr;
            scheduleLayout(GeometryDirty);
            emit trailingItemChanged();
        });
    }
    scheduleLayout(GeometryDirty);
    emit trailingItemChanged();
}

void MessageHeaderItem::setHeaderData(const MessageHeaderData& value)
{
    if (m_headerData == value) return;
    m_tooltipDirty = true;
    if (m_services) m_services->dismissTooltip(this);
    const bool timestampChanged = m_headerData.timestamp() != value.timestamp();
    m_headerData = value;
    m_timestampDirty |= timestampChanged;
    m_pressed = false;
    if (isComponentComplete()) syncResendItem();
    scheduleLayout(ContentDirty | (timestampChanged ? ClockDirty : 0));
    if (m_services) m_services->synchronize(this);
    emit headerDataChanged();
}

QString MessageHeaderItem::accessibleText() const
{
    QStringList parts;
    for (const auto& text : {m_prepared.name, m_prepared.origin, m_prepared.secondary, m_prepared.tertiary}) {
        if (!text.isEmpty()) parts.append(text);
    }
    if (!timestampText().isEmpty()) parts.append(timestampText());
    if (!m_prepared.statusText.isEmpty()) parts.append(m_prepared.statusText);
    return parts.join(QLatin1Char(' '));
}

QVariantMap MessageHeaderItem::displayData() const
{
    // Diagnostic view only: rendering and accessibility use typed fields.
    QVariantList icons;
    icons.reserve(m_prepared.verificationIcons.size());
    for (const auto& icon : m_prepared.verificationIcons) icons.append(icon);
    return {{QStringLiteral("name"), m_prepared.name},
            {QStringLiteral("senderId"), m_prepared.senderId},
            {QStringLiteral("origin"), m_prepared.origin},
            {QStringLiteral("secondary"), m_prepared.secondary},
            {QStringLiteral("tertiary"), m_prepared.tertiary},
            {QStringLiteral("verificationIcons"), icons},
            {QStringLiteral("verificationSize"), m_prepared.verificationSize},
            {QStringLiteral("separator"), true},
            {QStringLiteral("statusIcon"), m_prepared.statusIcon},
            {QStringLiteral("statusText"), m_prepared.statusText},
            {QStringLiteral("warning"), m_prepared.warning}};
}

void MessageHeaderItem::prepareDisplayData()
{
    const auto& data = m_headerData;
    const bool own = data.amISender();
    const auto asset = [&](const QString& name) {
        return m_appearance->iconBaseUrl().resolved(QUrl(name + QStringLiteral(".svg")));
    };
    QList<QUrl> icons;
    if (!own) {
        if ((data.isContact() && data.trustIndicator() == MessageHeaderData::Verified)
                || data.trustIndicator() == MessageHeaderData::Untrustworthy)
            icons.append(asset(data.trustIndicator() == MessageHeaderData::Verified
                               ? QStringLiteral("trustedContact") : QStringLiteral("untrustworthyContact")));
        if (data.isContact() && data.trustIndicator() != MessageHeaderData::Verified)
            icons.append(asset(QStringLiteral("justContact")));
    }
    QString tertiary;
    if (!own && data.messageOriginInfo().isEmpty()) {
        const auto detail = data.tertiaryDetail();
        // Match Utils.elideText(..., 3, 6), including JS substr's negative start.
        qsizetype from = detail.size() - 6;
        if (from < 0) from = qMax(qsizetype(0), detail.size() + from);
        tertiary = detail.left(3) + QChar(0x2026) + detail.mid(from);
    }
    m_prepared.name = own ? m_appearance->youText() : data.displayName();
    m_prepared.senderId = data.senderId();
    m_prepared.origin = data.messageOriginInfo();
    m_prepared.secondary = !own && !data.secondaryName().isEmpty()
            ? QLatin1Char('(') + data.secondaryName() + QLatin1Char(')') : QString();
    m_prepared.tertiary = tertiary;
    m_prepared.verificationIcons = std::move(icons);
    m_prepared.verificationSize = m_appearance->verificationSize();
    prepareStatusData();
}

void MessageHeaderItem::prepareStatusData()
{
    const auto& data = m_headerData;
    const bool expired = data.outgoingStatus() == MessageHeaderData::Expired;
    const bool delivery = data.amISender() && data.outgoingStatus() != MessageHeaderData::Unknown;
    const auto asset = [&](const QString& name) {
        return m_appearance->iconBaseUrl().resolved(QUrl(name + QStringLiteral(".svg")));
    };
    QUrl statusIcon;
    if (delivery) {
        if (!data.resendError().isEmpty() || expired) statusIcon = asset(QStringLiteral("tiny/tiny-exclamation"));
        else if (data.outgoingStatus() == MessageHeaderData::Delivered) statusIcon = asset(QStringLiteral("tiny/message/delivered"));
        else if (data.outgoingStatus() == MessageHeaderData::Sent) statusIcon = asset(QStringLiteral("tiny/message/sent"));
        else if (data.outgoingStatus() == MessageHeaderData::Sending) statusIcon = asset(QStringLiteral("tiny/pending"));
    }
    QString statusText;
    if (delivery && (m_showOutgoingStatusLabel
                     || (m_isMobile && (expired || !data.resendError().isEmpty())))) {
        if (!data.resendError().isEmpty())
            statusText = m_appearance->resendErrorFormat().arg(data.resendError());
        else {
            const auto& labels = m_appearance->deliveryTexts();
            if (data.outgoingStatus() >= 0 && data.outgoingStatus() < labels.size())
                statusText = labels.at(data.outgoingStatus());
        }
    }
    m_prepared.statusIcon = statusIcon;
    m_prepared.statusText = statusText;
    m_prepared.warning = expired;
}

bool MessageHeaderItem::updateTimestamp()
{
    if (!m_timestampCache) m_timestampCache = std::make_unique<TimestampCache>();
    auto& cache = *m_timestampCache;
    const double raw = double(m_headerData.timestamp());
    // JS Date timestamps are integral milliseconds within +/- 8.64e15.
    const qint64 timestamp = std::isfinite(raw) && qAbs(raw) <= 8640000000000000.0 ? qint64(raw) : 0;
    const bool full = m_showFullTimestamp;
    const bool defaults = m_appearance->timeFormatUsesDefaults();
    const bool use24Hours = m_appearance->timeFormatUses24Hours();
    // Qt.locale() without arguments uses the default QLocale as well. Read
    // it natively so a runtime locale change is seen by the shared-clock check.
    const QLocale locale;
    const QString language = m_appearance->language();
    QStringList formats = m_appearance->timestampFormats();
    if (formats.size() != 3)
        formats = {QStringLiteral("Today %1"), QStringLiteral("Yesterday %1"), QStringLiteral("%1 %2")};
    const auto now = QDateTime::currentDateTime();
    const auto zone = QTimeZone::systemTimeZoneId();
    if (cache.initialized && cache.timestamp == timestamp && cache.full == full && cache.defaults == defaults
            && cache.use24Hours == use24Hours && cache.locale == locale && cache.language == language && cache.formats == formats
            && cache.today == now.date() && cache.zone == zone && cache.utcOffset == now.offsetFromUtc()) return false;
    cache.initialized = true;
    cache.timestamp = timestamp; cache.full = full; cache.defaults = defaults; cache.use24Hours = use24Hours;
    cache.locale = locale; cache.language = language; cache.formats = formats; cache.today = now.date(); cache.zone = zone; cache.utcOffset = now.offsetFromUtc();
    const QString text = full ? fullTimestamp(timestamp, locale, defaults, use24Hours)
                              : relativeTimestamp(timestamp, now.date(), locale, defaults, use24Hours, formats);
    if (cache.text == text) return false;
    cache.text = text;
    emit timestampTextChanged();
    return true;
}

void MessageHeaderItem::refreshTimestamp()
{
    // The shared QML clock also ticks on application resume. A tick checks
    // the calendar/locale cache; it does not reformat unchanged timestamps.
    if (m_appearancePending || m_timestampDirty) return; // polish will consume the newest inputs
    if (updateTimestamp()) {
        m_accessibilityPending = true;
        m_tooltipDirty = true;
        if (m_services) m_services->dismissTooltip(this);
        scheduleLayout(PartsDirty | GeometryDirty);
    }
}

MessageHeaderItem::MessageHeaderItem(QQuickItem* parent) : QQuickItem(parent)
{
    connectAppearance();
    setFlag(ItemHasContents);
    setAcceptHoverEvents(true);
    setAcceptedMouseButtons(Qt::LeftButton);
}
MessageHeaderItem::~MessageHeaderItem()
{
    if (m_services) m_services->detach(this);
    if (m_trailingItem) disconnect(m_trailingItem, nullptr, this, nullptr);
    disconnect(m_appearance, nullptr, this, nullptr);
}

void MessageHeaderItem::connectAppearance()
{
    connect(m_appearance, &MessageHeaderAppearance::changed, this, [this](int changes) {
        int dirty = 0;
        if (changes & MessageHeaderAppearance::Content) dirty |= ContentDirty;
        if (changes & MessageHeaderAppearance::Metrics) dirty |= PartsDirty | GeometryDirty;
        if (changes & MessageHeaderAppearance::Colors) dirty |= PartsDirty;
        if (changes & MessageHeaderAppearance::Time) {
            m_tooltipDirty = true;
            if (m_services) m_services->dismissTooltip(this);
            m_timestampDirty = true;
            dirty |= ClockDirty;
        }
        scheduleLayout(dirty);
    });
    connect(m_appearance, &QObject::destroyed, this, [this] {
        m_tooltipDirty = true;
        if (m_services) m_services->dismissTooltip(this);
        m_appearance = MessageHeaderAppearance::defaults();
        connectAppearance();
        m_appearancePending = true;
        QMetaObject::invokeMethod(this, [this] {
            scheduleLayout();
            emit appearanceChanged();
        }, Qt::QueuedConnection);
    });
}

void MessageHeaderItem::setAppearance(MessageHeaderAppearance* value)
{
    if (!value) value = MessageHeaderAppearance::defaults();
    if (value == m_appearance) return;
    m_tooltipDirty = true;
    if (m_services) m_services->dismissTooltip(this);
    disconnect(m_appearance, nullptr, this, nullptr);
    m_appearance = value;
    connectAppearance();
    m_appearancePending = true;
    scheduleLayout();
    emit appearanceChanged();
}

void MessageHeaderItem::setDisplayNameClickable(bool value)
{
    if (value == m_clickable) return;
    m_clickable = value;
    m_pressed = false;
    setCursor(m_hoveredPart == Name && value ? Qt::PointingHandCursor : Qt::ArrowCursor);
    if (m_hoveredPart == Name) scheduleLayout(GeometryDirty);
    emit displayNameClickableChanged();
}

void MessageHeaderItem::setShowOutgoingStatusLabel(bool value)
{
    if (value == m_showOutgoingStatusLabel) return;
    m_showOutgoingStatusLabel = value;
    if (isComponentComplete()) syncResendItem();
    if (m_headerData.amISender() && m_headerData.outgoingStatus() != MessageHeaderData::Unknown)
        scheduleLayout(StatusDirty);
    emit showOutgoingStatusLabelChanged();
}

void MessageHeaderItem::setShowFullTimestamp(bool value)
{
    if (value == m_showFullTimestamp) return;
    m_showFullTimestamp = value;
    m_timestampDirty = true;
    scheduleLayout(ClockDirty);
    if (m_services) {
        m_services->synchronize(this);
        m_services->dismissTooltip(this);
    }
    emit showFullTimestampChanged();
}

void MessageHeaderItem::setIsMobile(bool value)
{
    if (value == m_isMobile) return;
    m_isMobile = value;
    if (isComponentComplete()) syncResendItem();
    if (m_headerData.amISender() && m_headerData.outgoingStatus() != MessageHeaderData::Unknown
            && (expired() || !m_headerData.resendError().isEmpty())) scheduleLayout(StatusDirty);
    emit isMobileChanged();
}

void MessageHeaderItem::scheduleLayout(int dirty)
{
    m_dirty |= dirty;
    if (isComponentComplete()) polish();
}
void MessageHeaderItem::componentComplete()
{
    QQuickItem::componentComplete();
    syncResendItem();
    scheduleLayout();
}
void MessageHeaderItem::geometryChange(const QRectF& now, const QRectF& before)
{
    QQuickItem::geometryChange(now, before);
    if (now.size() != before.size()) scheduleLayout(GeometryDirty);
}

void MessageHeaderItem::itemChange(ItemChange change, const ItemChangeData& value)
{
    QQuickItem::itemChange(change, value);
    if (change == ItemSceneChange || change == ItemDevicePixelRatioHasChanged)
        scheduleLayout(PartsDirty);
    if (change == ItemSceneChange || change == ItemVisibleHasChanged || change == ItemEnabledHasChanged) {
        if (change == ItemSceneChange || !value.boolValue) {
            m_pointerHovered = false;
            m_pressed = false;
            setHoveredPart(None);
            if (m_services) m_services->dismissTooltip(this);
        }
        if (m_services) m_services->synchronize(this);
        if (change == ItemVisibleHasChanged && value.boolValue) refreshTimestamp();
    }
}

void MessageHeaderItem::updatePolish()
{
    if (!m_dirty) return;
    syncResendItem();
    int dirty = std::exchange(m_dirty, 0);
    const bool inputsChanged = m_appearancePending || m_timestampDirty;
    m_appearancePending = false;
    m_timestampDirty = false;
    bool accessibilityChanged = std::exchange(m_accessibilityPending, false);
    if (inputsChanged && updateTimestamp()) {
        dirty |= PartsDirty | GeometryDirty;
        accessibilityChanged = true;
    }
    bool displayChanged = false;
    if (dirty & (ContentDirty | StatusDirty)) {
        const auto previous = m_prepared;
        if (dirty & ContentDirty) prepareDisplayData();
        else prepareStatusData();
        const auto texts = [](const PreparedHeader& value) {
            return std::tie(value.name, value.origin, value.secondary, value.tertiary, value.statusText);
        };
        const bool textsChanged = texts(previous) != texts(m_prepared);
        displayChanged = textsChanged || previous.senderId != m_prepared.senderId
                || previous.verificationIcons != m_prepared.verificationIcons
                || previous.verificationSize != m_prepared.verificationSize
                || previous.statusIcon != m_prepared.statusIcon || previous.warning != m_prepared.warning;
        accessibilityChanged |= textsChanged;
        if (displayChanged) dirty |= PartsDirty | GeometryDirty;
    }
    bool paintChanged = false;
    if (dirty & PartsDirty) paintChanged = updateParts();
    if (dirty & GeometryDirty) paintChanged |= layoutParts();
    if (displayChanged) emit displayDataChanged();
    if (accessibilityChanged) emit accessibleTextChanged();
    if (paintChanged) update();
    m_tooltipDirty = false;
    if (m_pointerHovered && m_services) m_services->requestTooltip(this, m_hoveredPart);
}

bool MessageHeaderItem::updateParts()
{
    struct Spec { PartKey key; QString text; QUrl icon; qreal iconSize = 0; int role = None; QColor color; };
    std::vector<Spec> specs;
    specs.push_back({PartKey::Name, m_prepared.name, {}, 0, Name, m_appearance->nameColor()});
    const auto text = [&](PartKey key, const QString& value, int role = None, bool warning = false) {
        if (!value.isEmpty()) specs.push_back({key, value, {}, 0, role, warning ? m_appearance->warningColor() : m_appearance->detailColor()});
    };
    const auto dot = [&](PartKey key) { specs.push_back({key, QString(QChar(0x2022)), {}, 0, None, m_appearance->detailColor()}); };
    text(PartKey::Origin, m_prepared.origin);
    const auto& icons = m_prepared.verificationIcons;
    for (qsizetype i = 0; i < icons.size(); ++i)
        specs.push_back({i == 0 ? PartKey::VerificationFirst : PartKey::VerificationSecond,
                         {}, icons[i], qreal(m_prepared.verificationSize), Verification, {}});
    text(PartKey::Secondary, m_prepared.secondary);
    if (!m_prepared.secondary.isEmpty() && !m_prepared.tertiary.isEmpty()) dot(PartKey::DetailSeparator);
    text(PartKey::Tertiary, m_prepared.tertiary);
    dot(PartKey::TimestampSeparator);
    if (!timestampText().isEmpty())
        specs.push_back({PartKey::Timestamp, timestampText(), {}, 0, Timestamp, m_appearance->detailColor()});
    const bool warning = m_prepared.warning;
    const QUrl statusIcon = m_prepared.statusIcon;
    if (!statusIcon.isEmpty()) specs.push_back({PartKey::StatusIcon, {}, statusIcon, 16, None, warning ? m_appearance->warningColor() : m_appearance->detailColor()});
    text(PartKey::StatusText, m_prepared.statusText, None, warning);

    bool changed = m_parts.size() != specs.size();
    for (size_t i = 0; i < specs.size(); ++i) {
        const auto& spec = specs[i];
        if (i == m_parts.size() || m_parts[i]->key != spec.key) {
            // At most eleven active parts: a short search preserves layouts
            // when optional metadata shifts their positions. Drop inactive
            // parts below rather than retaining a per-header cache of variants.
            const auto first = m_parts.begin() + i;
            const auto found = std::find_if(first, m_parts.end(), [&](const auto& part) {
                return part->key == spec.key;
            });
            if (found != m_parts.end()) std::iter_swap(first, found);
            else {
                auto part = std::make_unique<Part>();
                part->key = spec.key;
                part->revision = ++m_partRevision;
                m_parts.insert(first, std::move(part));
            }
            changed = true;
        }
        auto& part = *m_parts[i];
        const auto revision = part.revision;
        const QFont font = i == 0 ? m_appearance->nameFont() : m_appearance->detailFont();
        if (!spec.icon.isEmpty()) {
            const QImage image = iconImage(spec.icon, qRound(spec.iconSize), window() ? window()->effectiveDevicePixelRatio() : 1, spec.color);
            if (part.image.cacheKey() != image.cacheKey() || part.layout) {
                part.image = image; part.layout.reset(); part.revision = ++m_partRevision;
            }
            part.size = QSizeF(spec.iconSize, spec.iconSize);
        } else {
            // The tail is measured first. The name is shaped below once its
            // available width is known, preserving line wrapping on resize.
            if (i > 0 && (!part.layout || part.text != spec.text || part.font != font)) {
                part.layout = std::make_unique<QTextLayout>(spec.text, font);
                part.layout->setCacheEnabled(true);
                part.layout->beginLayout();
                auto line = part.layout->createLine();
                line.setLineWidth(1000000);
                part.layout->endLayout();
                part.size = QSizeF(line.naturalTextWidth(), line.height());
                part.lineWidth = -1;
                part.revision = ++m_partRevision;
            }
            part.image = {};
        }
        if (part.color != spec.color) { part.color = spec.color; part.revision = ++m_partRevision; }
        part.role = spec.role;
        // Keep old name keys until its layout comparison below.
        if (i > 0) { part.text = spec.text; part.font = font; }
        changed |= revision != part.revision;
    }
    m_parts.resize(specs.size());
    return changed;
}

bool MessageHeaderItem::layoutParts()
{
    if (m_parts.empty()) return false;
    bool changed = false;
    qreal tailWidth = 0, height = 0;
    constexpr qreal spacing = 4;
    for (size_t i = 1; i < m_parts.size(); ++i) {
        tailWidth += m_parts[i]->size.width() + spacing;
        height = qMax(height, m_parts[i]->size.height());
    }
    auto& name = *m_parts.front();
    QFont nameFont = m_appearance->nameFont();
    nameFont.setUnderline(m_clickable && m_hoveredPart == Name);
    const qreal trailingWidth = m_trailingItem ? m_trailingItem->implicitWidth() : 0;
    const qreal trailingHeight = m_trailingItem ? m_trailingItem->implicitHeight() : 0;
    const qreal reserved = m_trailingItem ? trailingWidth + spacing : 0;
    const qreal available = qMax(qreal(1), width() - reserved - tailWidth);
    if (!name.layout || name.text != m_prepared.name || name.font != nameFont || name.lineWidth != available) {
        if (name.text != m_prepared.name || name.font != nameFont)
            name.naturalWidth = QFontMetricsF(nameFont).horizontalAdvance(m_prepared.name);
        name.layout = std::make_unique<QTextLayout>(m_prepared.name, nameFont);
        name.layout->setCacheEnabled(true);
        QTextOption option;
        option.setWrapMode(QTextOption::WordWrap);
        name.layout->setTextOption(option);
        name.layout->beginLayout();
        qreal y = 0, widest = 0;
        while (true) {
            auto line = name.layout->createLine();
            if (!line.isValid()) break;
            line.setLineWidth(available);
            line.setPosition(QPointF(0, y));
            y += line.height();
            widest = qMax(widest, line.naturalTextWidth());
        }
        name.layout->endLayout();
        name.size = QSizeF(widest, y);
        name.text = m_prepared.name; name.font = nameFont; name.lineWidth = available;
        name.revision = ++m_partRevision;
        changed = true;
    }
    height = qMax(height, name.size.height() + 2);
    setImplicitWidth(name.naturalWidth + tailWidth + reserved);
    setImplicitHeight(qMax(height, trailingHeight));
    const qreal offset = (this->height() - height) / 2;
    qreal x = 0;
    for (size_t i = 0; i < m_parts.size(); ++i) {
        auto& part = *m_parts[i];
        const QPointF position(x, offset + (height - part.size.height() - (i == 0 ? 2 : 0)) / 2);
        changed |= position != part.position;
        part.position = position;
        x += part.size.width() + spacing;
    }
    const QRectF nameRect(name.position, name.size);
    const qreal contentWidth = qMax(qreal(0), x - spacing);
    const QRectF textRect(0, offset, qMax(qreal(0), width() - reserved), height);
    const bool geometryChanged = m_nameRect != nameRect || m_contentWidth != contentWidth || m_textRect != textRect;
    m_textRect = textRect;
    m_nameRect = nameRect;
    m_contentWidth = contentWidth;
    if (m_trailingItem) {
        m_trailingItem->setSize(QSizeF(trailingWidth, trailingHeight));
        m_trailingItem->setPosition(QPointF(contentWidth + spacing, (this->height() - trailingHeight) / 2));
    }
    if (geometryChanged) emit layoutChanged();
    if (m_pointerHovered) {
        setHoveredPart(partAt(m_hoverPosition));
    }
    return changed;
}

QSGNode* MessageHeaderItem::updatePaintNode(QSGNode* old, UpdatePaintNodeData*)
{
    auto* root = old ? static_cast<RootNode*>(old) : new RootNode;
    // No QQuickItems or QObjects per text/icon: only render-thread nodes.
    while (root->childCount() > int(m_parts.size())) {
        auto* node = root->lastChild(); root->removeChildNode(node); delete node;
    }
    while (root->childCount() < int(m_parts.size())) root->appendChildNode(new PartNode);
    auto* child = root->firstChild();
    for (const auto& stored : m_parts) {
        const auto& part = *stored;
        auto* node = static_cast<PartNode*>(child);
        if (node->revision != part.revision || node->position != part.position) {
            while (node->firstChild()) { auto* n = node->firstChild(); node->removeChildNode(n); delete n; }
            if (part.layout) {
                auto* text = window()->createTextNode();
                text->setColor(part.color);
                text->addTextLayout(part.position, part.layout.get());
                node->appendChildNode(text);
            } else if (!part.image.isNull()) {
                auto* image = new QSGSimpleTextureNode;
                image->setTexture(window()->createTextureFromImage(part.image));
                image->setOwnsTexture(true);
                image->setRect(QRectF(part.position, part.size));
                node->appendChildNode(image);
            }
            node->revision = part.revision; node->position = part.position;
        }
        child = child->nextSibling();
    }
    return root;
}

QRectF MessageHeaderItem::partRect(int role) const
{
    QRectF rect;
    for (const auto& part : m_parts)
        if (part->role == role) rect = rect.united(QRectF(part->position, part->size));
    return rect;
}

int MessageHeaderItem::partAt(const QPointF& point) const
{
    for (const auto& part : m_parts)
        if (part->role != None && QRectF(part->position, part->size).contains(point)) return part->role;
    return None;
}
void MessageHeaderItem::setHoveredPart(int value)
{
    if (m_hoveredPart == value) return;
    const bool underlineChanged = (m_hoveredPart == Name) != (value == Name);
    m_hoveredPart = value;
    setCursor(value == Name && m_clickable ? Qt::PointingHandCursor : Qt::ArrowCursor);
    if (underlineChanged && m_clickable) scheduleLayout(GeometryDirty);
    emit hoveredPartChanged();
}
void MessageHeaderItem::hoverMoveEvent(QHoverEvent* event)
{
    // As with StatusLazyToolTip, touch must never open a pointer tooltip.
    m_pointerHovered = event->pointingDevice()->type() != QInputDevice::DeviceType::TouchScreen;
    m_hoverPosition = event->position();
    setHoveredPart(partAt(m_hoverPosition));
    if (m_services && m_pointerHovered) m_services->requestTooltip(this, m_hoveredPart);
}
void MessageHeaderItem::hoverEnterEvent(QHoverEvent* event) { hoverMoveEvent(event); }
void MessageHeaderItem::hoverLeaveEvent(QHoverEvent*)
{
    m_pointerHovered = false;
    setHoveredPart(None);
    if (m_services) m_services->dismissTooltip(this);
}
void MessageHeaderItem::mousePressEvent(QMouseEvent* event)
{
    m_pressed = m_clickable && m_nameRect.contains(event->position());
    event->setAccepted(m_pressed);
}
void MessageHeaderItem::mouseReleaseEvent(QMouseEvent* event)
{
    const bool clicked = m_pressed && m_clickable && m_nameRect.contains(event->position());
    m_pressed = false;
    event->setAccepted(clicked);
    if (clicked) emit nameClicked();
}
