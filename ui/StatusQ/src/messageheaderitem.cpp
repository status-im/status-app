#include "StatusQ/messageheaderitem.h"
#include "StatusQ/messageheaderappearance.h"
#include "StatusQ/messageheaderservices.h"
#include "chattextaccessibility.h"
#include "messageheadertext.h"
#include "messageheadertime.h"

#include <QCache>
#include <QCursor>
#include <QDateTime>
#include <QFontMetricsF>
#include <QImageReader>
#include <QLocale>
#include <QMutex>
#include <QPainter>
#include <QQmlFile>
#include <QQuickWindow>
#include <QSGImageNode>
#include <QSGRectangleNode>
#include <QSGTextNode>
#include <QSGTransformNode>
#include <QVarLengthArray>
#include <QtMath>

#include <algorithm>

namespace {

using Key = MessageHeaderItem::Key;

constexpr qreal UnboundedWidth = 1e6;
const QString Dot = QStringLiteral("•");

// Groups are transform nodes: the software renderer keeps an inherited
// position and clip across a replaced subtree only under one.
class PartNode : public QSGTransformNode
{
public:
    quint64 revision = 0;
    QPointF position;
};

class RootNode : public QSGTransformNode
{
public:
    // Underline under the hovered name: a paint-only overlay, so hover never
    // reshapes the name.
    QSGTransformNode* underline = nullptr;
    quint64 underlineRevision = 0;
    QPointF underlinePosition;
    QColor underlineColor;
};

QMatrix4x4 translation(const QPointF& point)
{
    QMatrix4x4 matrix;
    matrix.translate(float(point.x()), float(point.y()));
    return matrix;
}

struct IconRaster
{
    QImage image;
    QSizeF size; // logical, fitted inside the requested box
};

// Icon rasters keyed by URL, box size, pixel ratio and tint, shared between
// headers. Textures stay per node. As StatusIcon (PreserveAspectFit), an icon
// keeps its aspect ratio inside the box.
IconRaster iconImage(const QUrl& url, qreal box, qreal dpr, const QColor& tint)
{
    static QMutex mutex;
    static QCache<QString, IconRaster> cache(1024 * 1024);
    const QString key = url.toString() + QLatin1Char('|') + QString::number(box) + QLatin1Char('|')
            + QString::number(dpr) + QLatin1Char('|')
            + QString::number(tint.isValid() ? tint.rgba() : 0, 16);
    QMutexLocker lock(&mutex);
    if (const IconRaster* raster = cache.object(key))
        return *raster;
    lock.unlock();

    QImageReader reader(QQmlFile::urlToLocalFileOrQrc(url));
    QSizeF natural = reader.size();
    if (natural.isEmpty())
        natural = QSizeF(box, box);
    const qreal scale = qMin(box / natural.width(), box / natural.height());
    IconRaster raster;
    raster.size = natural * scale;
    const QSize pixels(qMax(1, qRound(raster.size.width() * dpr)), qMax(1, qRound(raster.size.height() * dpr)));
    reader.setScaledSize(pixels);
    raster.image = reader.read().convertToFormat(QImage::Format_ARGB32_Premultiplied);
    if (raster.image.isNull()) {
        raster.image = QImage(pixels, QImage::Format_ARGB32_Premultiplied);
        raster.image.fill(Qt::transparent);
    }
    if (tint.isValid() && tint.alpha() > 0) {
        // As ColorImage colours an icon: keep its alpha, take the colour.
        QPainter painter(&raster.image);
        painter.setCompositionMode(QPainter::CompositionMode_SourceIn);
        painter.fillRect(raster.image.rect(), tint);
    }
    raster.image.setDevicePixelRatio(dpr);
    lock.relock();
    cache.insert(key, new IconRaster(raster), qMax<qsizetype>(1, raster.image.sizeInBytes()));
    return raster;
}

QString iconName(int status, bool failed)
{
    if (failed)
        return QStringLiteral("tiny/tiny-exclamation");
    switch (status) {
    case MessageHeaderData::StatusDelivered: return QStringLiteral("tiny/message/delivered");
    case MessageHeaderData::StatusSent: return QStringLiteral("tiny/message/sent");
    case MessageHeaderData::StatusSending: return QStringLiteral("tiny/pending");
    case MessageHeaderData::StatusExpired: return QStringLiteral("tiny/tiny-exclamation");
    default: return {};
    }
}

const char* keyName(Key key)
{
    switch (key) {
    case Key::Name: return "name";
    case Key::OriginInfo: return "originInfo";
    case Key::TrustIcon: return "trustIcon";
    case Key::ContactIcon: return "contactIcon";
    case Key::SecondaryName: return "secondaryName";
    case Key::FirstDot: return "firstDot";
    case Key::TertiaryDetail: return "tertiaryDetail";
    case Key::SecondDot: return "secondDot";
    case Key::Timestamp: return "timestamp";
    case Key::StatusIcon: return "statusIcon";
    case Key::StatusLabel: return "statusLabel";
    }
    return "";
}

} // namespace

MessageHeaderItem::MessageHeaderItem(QQuickItem* parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents);
    setAcceptHoverEvents(true);
    setAcceptedMouseButtons(Qt::LeftButton);
    connectAppearance();
    ChatTextAccessibility::track(this, "accessibleText");
}

MessageHeaderItem::~MessageHeaderItem()
{
    ChatTextAccessibility::untrack(this);
    if (m_services) {
        m_services->hideTooltip(this);
        if (m_services->tooltipAnchor() && m_services->tooltipAnchor()->parentItem() == this)
            m_services->tooltipAnchor()->setParentItem(nullptr);
        m_services->unsubscribe(this);
    }
}

MessageHeaderAppearance* MessageHeaderItem::appearance() const
{
    return m_appearance ? m_appearance.data() : MessageHeaderAppearance::defaults();
}

void MessageHeaderItem::setAppearance(MessageHeaderAppearance* value)
{
    if (m_appearance == value)
        return;
    m_appearance = value;
    connectAppearance();
    invalidate(DirtyContent | DirtyTimestamp | DirtyFonts | DirtyColors | DirtyGeometry);
    emit appearanceChanged();
}

void MessageHeaderItem::connectAppearance()
{
    for (const auto& connection : std::as_const(m_appearanceConnections))
        disconnect(connection);
    m_appearanceConnections.clear();
    MessageHeaderAppearance* a = appearance();
    m_appearanceConnections = {
        connect(a, &MessageHeaderAppearance::fontsChanged, this,
                [this] { invalidate(DirtyFonts | DirtyGeometry); }),
        connect(a, &MessageHeaderAppearance::colorsChanged, this, [this] { invalidate(DirtyColors); }),
        connect(a, &MessageHeaderAppearance::metricsChanged, this,
                [this] { invalidate(DirtyContent | DirtyGeometry); }),
        connect(a, &MessageHeaderAppearance::textsChanged, this, [this] { invalidate(DirtyContent); }),
        connect(a, &MessageHeaderAppearance::timeFormatChanged, this,
                [this] { invalidate(DirtyTimestamp); }),
        // A destroyed appearance falls back to the defaults.
        connect(a, &QObject::destroyed, this, [this] {
            if (!m_appearance) {
                connectAppearance();
                invalidate(DirtyContent | DirtyTimestamp | DirtyFonts | DirtyColors | DirtyGeometry);
            }
        }),
    };
}

void MessageHeaderItem::setServices(MessageHeaderServices* value)
{
    if (m_services == value)
        return;
    if (m_services) {
        m_services->hideTooltip(this);
        m_services->unsubscribe(this);
    }
    m_clockSubscribed = false;
    m_services = value;
    // A different clock: the cached timestamp may not match it.
    m_formattedClock = 0;
    invalidate(DirtyTimestamp | DirtyStatus);
    updateClockSubscription();
    emit servicesChanged();
}

void MessageHeaderItem::servicesDestroyed()
{
    m_clockSubscribed = false;
    m_services = nullptr;
    if (m_resendButton) {
        m_resendButton->setVisible(false);
        m_resendButton->setEnabled(false);
    }
}

void MessageHeaderItem::setHeaderData(const MessageHeaderData& data)
{
    if (m_data == data)
        return;
    const bool timestampChanged = m_data.timestamp != data.timestamp;
    m_data = data;
    invalidate(DirtyContent | (timestampChanged ? DirtyTimestamp : 0));
    if (timestampChanged)
        updateClockSubscription();
    emit headerDataChanged();
}

void MessageHeaderItem::setDisplayNameClickable(bool value)
{
    if (m_displayNameClickable == value)
        return;
    m_displayNameClickable = value;
    if (!value) {
        setNameHovered(false);
        unsetCursor();
    } else if (m_hovering) {
        updateHover(m_hoverPoint);
    }
    emit displayNameClickableChanged();
}

void MessageHeaderItem::setShowFullTimestamp(bool value)
{
    if (m_showFullTimestamp == value)
        return;
    m_showFullTimestamp = value;
    invalidate(DirtyTimestamp);
    updateClockSubscription();
    emit showFullTimestampChanged();
}

bool MessageHeaderItem::statusFlagsMatter() const
{
    return (m_data.amISender && m_data.outgoingStatus != MessageHeaderData::StatusUnknown)
            || m_data.outgoingStatus == MessageHeaderData::StatusExpired;
}

void MessageHeaderItem::setShowOutgoingStatusLabel(bool value)
{
    if (m_showOutgoingStatusLabel == value)
        return;
    m_showOutgoingStatusLabel = value;
    // Hovering a message row toggles this on every header it passes; for an
    // incoming message it changes nothing.
    if (statusFlagsMatter())
        invalidate(DirtyStatus);
    emit showOutgoingStatusLabelChanged();
}

void MessageHeaderItem::setIsMobile(bool value)
{
    if (m_isMobile == value)
        return;
    m_isMobile = value;
    if (statusFlagsMatter())
        invalidate(DirtyStatus);
    emit isMobileChanged();
}

void MessageHeaderItem::invalidate(quint16 flags)
{
    m_dirty |= flags;
    if (m_complete)
        polish();
}

void MessageHeaderItem::componentComplete()
{
    QQuickItem::componentComplete();
    m_complete = true;
    // Ready at once, so a view reads the final height of a new delegate.
    process();
}

void MessageHeaderItem::updatePolish()
{
    process();
}

void MessageHeaderItem::applyPendingChanges()
{
    if (m_dirty)
        process();
}

void MessageHeaderItem::process()
{
    if (!m_complete || !m_dirty)
        return;
    const quint16 flags = m_dirty;
    m_dirty = 0;

    const QString oldTimestamp = m_prepared.timestamp;
    if (flags & DirtyContent)
        prepareContent();
    else if (flags & DirtyStatus)
        prepareStatus();
    if (flags & (DirtyContent | DirtyTimestamp))
        prepareTimestamp();

    if (flags & DirtyFonts) {
        for (auto& part : m_parts) {
            if (!part->icon) {
                part->shaped = false;
                touch(*part);
            }
        }
    }

    const quint64 revisionBefore = m_revision;
    const auto partsBefore = m_parts.size();
    if (flags & (DirtyContent | DirtyStatus | DirtyTimestamp | DirtyColors | DirtyFonts))
        syncParts();
    bool geometry = (flags & (DirtyGeometry | DirtyFonts)) || m_parts.size() != partsBefore;
    for (auto& part : m_parts) {
        if (!part->shaped) {
            shapePart(*part);
            geometry = true;
        } else if (part->icon && part->width != part->iconSize) {
            part->width = part->height = part->iconSize;
            geometry = true;
        }
    }
    if (flags & (DirtyContent | DirtyStatus))
        syncResendButton();
    // Parts that only changed colour keep their geometry.
    if (geometry || (flags & (DirtyContent | DirtyStatus)))
        computeGeometry();

    if (m_revision != revisionBefore || geometry)
        update();
    if (m_prepared.timestamp != oldTimestamp)
        emit formattedTimestampChanged();
    if (flags & (DirtyContent | DirtyStatus | DirtyTimestamp))
        updateAccessibleText();
    if (geometry || (flags & (DirtyContent | DirtyStatus | DirtyTimestamp)))
        emit displayDataChanged();

    updateClockSubscription();
    // Hover and tooltip follow the new content, never the old one.
    if (m_hovering)
        updateHover(m_hoverPoint);
}

void MessageHeaderItem::prepareContent()
{
    const MessageHeaderAppearance* a = appearance();
    const MessageHeaderData& d = m_data;
    PreparedHeader& p = m_prepared;

    p.name = d.amISender ? a->youText() : d.displayName;
    if (p.name.contains(QLatin1Char('\n')))
        p.name.replace(QLatin1Char('\n'), QChar::LineSeparator);
    p.originInfo = d.messageOriginInfo;

    p.verificationSlot = !d.amISender;
    p.trustIcon.clear();
    p.contactIcon = false;
    p.verificationText.clear();
    if (p.verificationSlot) {
        const bool verified = d.trustIndicator == MessageHeaderData::TrustVerified;
        const bool untrusted = d.trustIndicator == MessageHeaderData::TrustUntrustworthy;
        if (untrusted || (d.isContact && verified))
            p.trustIcon = verified ? QStringLiteral("trustedContact") : QStringLiteral("untrustworthyContact");
        p.contactIcon = d.isContact && !verified;
        if (d.isContact)
            p.verificationText = verified ? a->trustedContactText()
                    : untrusted ? a->untrustedContactText() : a->contactText();
        else if (untrusted)
            p.verificationText = a->untrustedText();
    }

    const bool secondary = !d.amISender && !d.secondaryName.isEmpty();
    p.secondaryName = secondary ? QLatin1Char('(') + d.secondaryName + QLatin1Char(')') : QString();
    const QString tertiary = d.tertiaryDetail();
    p.hasTertiary = !d.amISender && d.messageOriginInfo.isEmpty() && !tertiary.isEmpty();
    // Utils.elideText(text, 3, 6)
    p.tertiaryDetail = p.hasTertiary ? tertiary.left(3) + QChar(0x2026) + tertiary.right(6) : QString();
    p.firstDot = secondary && p.hasTertiary;
    p.secondDot = p.verificationSlot || secondary || d.amISender || p.hasTertiary;
    prepareStatus();
}

void MessageHeaderItem::prepareStatus()
{
    const MessageHeaderAppearance* a = appearance();
    const MessageHeaderData& d = m_data;
    PreparedHeader& p = m_prepared;
    const bool expired = d.outgoingStatus == MessageHeaderData::StatusExpired;
    const bool failed = !d.resendError.isEmpty();
    p.status = d.amISender && d.outgoingStatus != MessageHeaderData::StatusUnknown;
    p.statusWarning = expired;
    p.statusIcon = p.status ? iconName(d.outgoingStatus, failed) : QString();
    p.statusLabelShown = p.status && (m_showOutgoingStatusLabel || (m_isMobile && (expired || failed)));
    p.statusLabel.clear();
    if (p.statusLabelShown) {
        if (failed) {
            p.statusLabel = a->failedToResendTemplate().arg(d.resendError);
        } else {
            switch (d.outgoingStatus) {
            case MessageHeaderData::StatusDelivered: p.statusLabel = a->deliveredText(); break;
            case MessageHeaderData::StatusSent: p.statusLabel = a->sentText(); break;
            case MessageHeaderData::StatusSending: p.statusLabel = a->sendingText(); break;
            case MessageHeaderData::StatusExpired: p.statusLabel = a->sendingFailedText(); break;
            default: break;
            }
        }
    }
    p.resend = (m_showOutgoingStatusLabel || m_isMobile) && expired;
}

const MessageHeaderTimeFormats& MessageHeaderItem::timeFormats() const
{
    if (m_services)
        return m_services->timeFormats(appearance());
    // Without services: rebuilt on every use.
    static MessageHeaderTimeFormats local;
    local.build(appearance(), 0, QDate::currentDate());
    return local;
}

void MessageHeaderItem::prepareTimestamp()
{
    const MessageHeaderAppearance* a = appearance();
    const quint64 clock = m_services ? m_services->clock().revision : 0;
    if (clock != 0 && m_formattedFor == m_data.timestamp && m_formattedFull == m_showFullTimestamp
            && m_formattedTimeFormat == a->timeFormatRevision() && m_formattedAppearance == a
            && m_formattedClock == clock)
        return;
    m_formattedFor = m_data.timestamp;
    m_formattedFull = m_showFullTimestamp;
    m_formattedTimeFormat = a->timeFormatRevision();
    m_formattedAppearance = a;
    m_formattedClock = clock;
    const qint64 ms = qint64(m_data.timestamp);
    const MessageHeaderTimeFormats& formats = timeFormats();
    m_prepared.timestamp = m_showFullTimestamp ? formats.full(ms) : formats.relative(ms);
}

QString MessageHeaderItem::fullTimestamp() const
{
    if (!m_data.timestamp)
        return {};
    return timeFormats().full(qint64(m_data.timestamp));
}

const QTextLayout* MessageHeaderItem::Part::layout() const
{
    return wrapped ? wrapped.get() : &line->layout;
}

MessageHeaderItem::Part* MessageHeaderItem::findPart(Key key) const
{
    for (const auto& part : m_parts) {
        if (part->key == key)
            return part.get();
    }
    return nullptr;
}

void MessageHeaderItem::syncParts()
{
    const MessageHeaderAppearance* a = appearance();
    const PreparedHeader& p = m_prepared;
    const QColor statusColor = p.statusWarning ? a->warningColor() : a->detailColor();

    struct Wanted
    {
        Key key;
        bool icon;
        const QString* text;
        QString iconName;
        qreal iconSize;
        QColor color;
    };
    QVarLengthArray<Wanted, 11> wanted;
    const auto text = [&](Key key, const QString& value, const QColor& color) {
        wanted.append({key, false, &value, {}, 0, color});
    };
    text(Key::Name, p.name, a->nameColor());
    if (!p.originInfo.isEmpty())
        text(Key::OriginInfo, p.originInfo, a->detailColor());
    if (!p.trustIcon.isEmpty())
        wanted.append({Key::TrustIcon, true, nullptr, p.trustIcon, a->verificationIconSize(), {}});
    if (p.contactIcon)
        wanted.append({Key::ContactIcon, true, nullptr, QStringLiteral("justContact"),
                       a->verificationIconSize(), {}});
    if (!p.secondaryName.isEmpty())
        text(Key::SecondaryName, p.secondaryName, a->detailColor());
    if (p.firstDot)
        text(Key::FirstDot, Dot, a->detailColor());
    if (p.hasTertiary)
        text(Key::TertiaryDetail, p.tertiaryDetail, a->detailColor());
    if (p.secondDot)
        text(Key::SecondDot, Dot, a->detailColor());
    text(Key::Timestamp, p.timestamp, a->detailColor());
    if (p.status)
        wanted.append({Key::StatusIcon, true, nullptr, p.statusIcon, a->statusIconSize(), statusColor});
    if (p.statusLabelShown)
        text(Key::StatusLabel, p.statusLabel, statusColor);

    for (qsizetype i = 0; i < wanted.size(); ++i) {
        const Wanted& w = wanted[i];
        const size_t index = size_t(i);
        // Fast path: the part is already in place.
        if (index >= m_parts.size() || m_parts[index]->key != w.key) {
            auto found = std::find_if(m_parts.begin() + qMin(index, m_parts.size()), m_parts.end(),
                                      [&](const auto& part) { return part->key == w.key; });
            if (found != m_parts.end()) {
                std::rotate(m_parts.begin() + index, found, found + 1);
            } else {
                auto part = std::make_unique<Part>();
                part->key = w.key;
                part->icon = w.icon;
                part->nameFont = w.key == Key::Name;
                touch(*part);
                m_parts.insert(m_parts.begin() + index, std::move(part));
            }
        }
        Part& part = *m_parts[index];
        if (w.icon) {
            const QUrl url = w.iconName.isEmpty() ? QUrl()
                    : appearance()->iconBaseUrl().resolved(QUrl(w.iconName + QStringLiteral(".svg")));
            if (part.iconUrl != url || part.iconSize != w.iconSize || part.color != w.color) {
                part.iconUrl = url;
                part.iconSize = w.iconSize;
                part.color = w.color;
                touch(part);
            }
        } else {
            if (part.text != *w.text) {
                part.text = *w.text;
                part.shaped = false;
                touch(part);
            }
            if (part.color != w.color) {
                part.color = w.color;
                touch(part);
            }
        }
    }
    m_parts.erase(m_parts.begin() + wanted.size(), m_parts.end());
}

void MessageHeaderItem::shapePart(Part& part)
{
    if (part.icon) {
        part.width = part.height = part.iconSize;
        part.shaped = true;
        return;
    }
    const MessageHeaderAppearance* a = appearance();
    const QFont font = part.nameFont ? a->nameFont() : a->detailFont();
    if (m_services)
        part.line = m_services->shapedText(part.text, font, a, a->fontRevision() * 2 + part.nameFont);
    else
        part.line = std::make_shared<const MessageHeaderShapedText>(part.text, font);
    part.wrapped.reset();
    part.naturalWidth = part.line->naturalWidth;
    // A label occupies whole pixels in a layout, as each Text did.
    part.width = qCeil(part.naturalWidth);
    part.height = part.line->height;
    part.wrapWidth = -1;
    part.shaped = true;
    touch(part);
}

// The name fills the room left by the other parts, never wider than its own
// text, and wraps at word boundaries below that.
void MessageHeaderItem::layoutName(Part& part, qreal available)
{
    const qreal natural = qCeil(part.naturalWidth);
    if (natural <= available) {
        if (part.wrapped) {
            part.wrapped.reset();
            part.height = part.line->height;
            part.wrapWidth = -1;
            touch(part);
        }
        part.width = natural;
        return;
    }
    const qreal width = qMax<qreal>(0, available);
    if (part.wrapped && part.wrapWidth == width)
        return;
    if (!part.wrapped) {
        part.wrapped = std::make_unique<QTextLayout>(part.text, part.line->layout.font());
        part.wrapped->setCacheEnabled(true);
        QTextOption option;
        option.setWrapMode(QTextOption::WordWrap);
        option.setAlignment(Qt::AlignLeft);
        part.wrapped->setTextOption(option);
    }
    QTextLayout& layout = *part.wrapped;
    layout.beginLayout();
    qreal y = 0;
    for (QTextLine line = layout.createLine(); line.isValid(); line = layout.createLine()) {
        line.setLineWidth(width);
        line.setPosition(QPointF(0, y));
        y += line.height();
    }
    layout.endLayout();
    part.wrapWidth = width;
    part.width = width;
    part.height = y;
    touch(part);
}

void MessageHeaderItem::computeGeometry()
{
    const MessageHeaderAppearance* a = appearance();
    const qreal spacing = a->spacing();
    const qreal iconSpacing = a->verificationIconSpacing();

    // Cells in RowLayout order. The verification slot exists for every
    // incoming message, even without icons, as its Loader did.
    m_cells.clear();
    Part* name = nullptr;
    bool verificationPlaced = false;
    int statusCell = -1;
    for (int i = 0; i < int(m_parts.size()); ++i) {
        Part& part = *m_parts[size_t(i)];
        const bool verification = part.key == Key::TrustIcon || part.key == Key::ContactIcon;
        if (!verificationPlaced && m_prepared.verificationSlot && !verification
                && part.key > Key::OriginInfo) {
            m_cells.push_back({i, 0, 0, 0, false});
            verificationPlaced = true;
        }
        if (part.key == Key::Name)
            name = &part;
        if (verification) {
            if (!verificationPlaced) {
                m_cells.push_back({i, 0, 0, 0, false});
                verificationPlaced = true;
            }
            Cell& cell = m_cells.back();
            cell.width += (cell.count ? iconSpacing : 0) + part.width;
            cell.height = qMax(cell.height, part.height);
            ++cell.count;
            continue;
        }
        if (part.key == Key::StatusLabel && statusCell >= 0) {
            Cell& cell = m_cells[size_t(statusCell)];
            cell.width += part.width;
            cell.height = qMax(cell.height, part.height);
            ++cell.count;
            continue;
        }
        if (part.key == Key::StatusIcon)
            statusCell = int(m_cells.size());
        m_cells.push_back({i, 1, part.width, part.height, false});
    }
    if (m_resendButton) {
        m_cells.push_back({int(m_parts.size()), 0, m_resendButton->implicitWidth(),
                           m_resendButton->implicitHeight(), true});
    }

    // Room for the name: the other cells, and a spacing between every two
    // cells including the trailing filler.
    qreal others = 0;
    for (const Cell& cell : m_cells) {
        if (!name || cell.first != 0)
            others += cell.width;
    }
    const qreal spacings = spacing * qreal(m_cells.size());
    const qreal margin = a->nameBottomMargin();
    if (name) {
        const qreal available = width() > 0 ? width() - others - spacings : UnboundedWidth;
        layoutName(*name, available);
        m_cells.front().width = name->width;
        m_cells.front().height = name->height + margin;
    }

    qreal rowHeight = 0;
    for (const Cell& cell : m_cells)
        rowHeight = qMax(rowHeight, cell.height);

    bool changed = false;
    qreal x = 0;
    for (const Cell& cell : m_cells) {
        // Vertically centred and rounded, as RowLayout places its items.
        const qreal top = qRound((rowHeight - cell.height) / 2);
        if (cell.resend) {
            m_resendButton->setPosition(QPointF(x, top));
            m_resendButton->setSize(QSizeF(cell.width, cell.height));
        }
        qreal partX = x;
        for (int i = cell.first; i < cell.first + cell.count; ++i) {
            Part& part = *m_parts[size_t(i)];
            const qreal y = part.key == Key::Name ? top : top + qRound((cell.height - part.height) / 2);
            const QPointF position(partX, y);
            if (part.position != position) {
                part.position = position;
                changed = true;
            }
            partX += part.width + (part.icon && part.key != Key::StatusIcon ? iconSpacing : 0);
        }
        x += cell.width + spacing;
    }

    qreal implicit = spacings;
    for (const Cell& cell : m_cells)
        implicit += cell.width;
    if (name)
        implicit += qCeil(name->naturalWidth) - name->width;
    changed = changed || implicitWidth() != implicit || implicitHeight() != rowHeight;
    setImplicitSize(implicit, rowHeight);
    if (changed)
        emit layoutChanged();
}

void MessageHeaderItem::syncResendButton()
{
    if (m_prepared.resend && !m_resendButton && m_services) {
        m_resendButton = m_services->createResendButton(this);
        if (m_resendButton) {
            const auto relayout = [this] { invalidate(DirtyGeometry); };
            connect(m_resendButton, &QQuickItem::implicitWidthChanged, this, relayout);
            connect(m_resendButton, &QQuickItem::implicitHeightChanged, this, relayout);
            emit resendButtonItemChanged();
        }
    } else if (!m_prepared.resend && m_resendButton) {
        QQuickItem* button = m_resendButton;
        m_resendButton = nullptr;
        disconnect(button, nullptr, this, nullptr);
        button->setVisible(false);
        button->setEnabled(false);
        button->deleteLater();
        emit resendButtonItemChanged();
    }
}

void MessageHeaderItem::geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    if (newGeometry.width() != oldGeometry.width())
        invalidate(DirtyGeometry);
}

void MessageHeaderItem::itemChange(ItemChange change, const ItemChangeData& value)
{
    switch (change) {
    case ItemSceneChange:
        if (m_services)
            m_services->hideTooltip(this);
        clearHover();
        updateClockSubscription();
        break;
    case ItemVisibleHasChanged:
        if (!value.boolValue) {
            if (m_services)
                m_services->hideTooltip(this);
            clearHover();
        }
        updateClockSubscription();
        break;
    case ItemEnabledHasChanged:
        if (!value.boolValue) {
            if (m_services)
                m_services->hideTooltip(this);
            clearHover();
        }
        break;
    case ItemDevicePixelRatioHasChanged:
        for (auto& part : m_parts) {
            if (part->icon)
                touch(*part);
        }
        update();
        break;
    default:
        break;
    }
    QQuickItem::itemChange(change, value);
}

void MessageHeaderItem::updateClockSubscription()
{
    const bool wanted = m_services && window() && isVisible() && m_data.timestamp != 0
            && !m_showFullTimestamp;
    if (wanted == m_clockSubscribed)
        return;
    m_clockSubscribed = wanted;
    if (wanted) {
        m_services->subscribe(this);
        // Hidden, it missed the ticks.
        if (m_services->clock().revision != m_formattedClock)
            invalidate(DirtyTimestamp);
    } else if (m_services) {
        m_services->unsubscribe(this);
    }
}

void MessageHeaderItem::clockChanged()
{
    invalidate(DirtyTimestamp);
}

MessageHeaderItem::Region MessageHeaderItem::regionAtPoint(const QPointF& point) const
{
    for (const Cell& cell : m_cells) {
        if (cell.resend || !cell.count)
            continue;
        const Part& first = *m_parts[size_t(cell.first)];
        const Part& last = *m_parts[size_t(cell.first + cell.count - 1)];
        const QRectF rect(first.position.x(), qMin(first.position.y(), last.position.y()), cell.width,
                          qMax(first.height, last.height));
        if (!rect.contains(point))
            continue;
        switch (first.key) {
        case Key::Name: return Region::Name;
        case Key::TrustIcon:
        case Key::ContactIcon: return Region::Verification;
        case Key::Timestamp: return first.text.isEmpty() ? Region::None : Region::Timestamp;
        default: return Region::None;
        }
    }
    return Region::None;
}

QString MessageHeaderItem::regionAt(qreal x, qreal y)
{
    applyPendingChanges();
    switch (regionAtPoint(QPointF(x, y))) {
    case Region::Name: return QStringLiteral("name");
    case Region::Verification: return QStringLiteral("verification");
    case Region::Timestamp: return QStringLiteral("timestamp");
    case Region::None: break;
    }
    return {};
}

QRectF MessageHeaderItem::partRect(const QString& key)
{
    applyPendingChanges();
    for (const auto& part : m_parts) {
        if (QLatin1String(keyName(part->key)) == key)
            return QRectF(part->position, QSizeF(part->width, part->height));
    }
    return {};
}

void MessageHeaderItem::setNameHovered(bool hovered)
{
    if (m_nameHovered == hovered)
        return;
    m_nameHovered = hovered;
    // The underline is an overlay node: nothing is reshaped.
    update();
    emit nameHoveredChanged();
}

void MessageHeaderItem::updateHover(const QPointF& point)
{
    m_hovering = true;
    m_hoverPoint = point;
    // A tooltip for content still being prepared would show stale text; the
    // pending polish calls back here once the parts are current.
    if (m_dirty) {
        polish();
        return;
    }
    const Region region = regionAtPoint(point);
    const bool onName = region == Region::Name && m_displayNameClickable;
    if (onName != m_nameHovered) {
        if (onName)
            setCursor(Qt::PointingHandCursor);
        else
            unsetCursor();
    }
    setNameHovered(onName);
    m_hoverRegion = region;
    refreshTooltip();
}

void MessageHeaderItem::clearHover()
{
    m_hovering = false;
    m_hoverRegion = Region::None;
    m_pressedOnName = false;
    setNameHovered(false);
    if (m_services)
        m_services->hideTooltip(this);
}

void MessageHeaderItem::refreshTooltip()
{
    if (!m_services)
        return;
    if (!m_hovering || !isEnabled() || !isVisible() || !window()) {
        m_services->hideTooltip(this);
        return;
    }
    if (m_hoverRegion == Region::Timestamp && !m_showFullTimestamp && m_data.timestamp) {
        m_services->showTooltip(this, partRect(QStringLiteral("timestamp")), fullTimestamp(), 350,
                                QStringLiteral("timestampTooltip"));
        return;
    }
    if (m_hoverRegion == Region::Verification && !m_prepared.verificationText.isEmpty()) {
        for (const Cell& cell : m_cells) {
            if (!cell.count || cell.resend)
                continue;
            const Part& first = *m_parts[size_t(cell.first)];
            if (first.key != Key::TrustIcon && first.key != Key::ContactIcon)
                continue;
            m_services->showTooltip(this, QRectF(first.position, QSizeF(cell.width, cell.height)),
                                    m_prepared.verificationText, -1,
                                    QStringLiteral("verificationIconsTooltip"));
            return;
        }
    }
    m_services->hideTooltip(this);
}

void MessageHeaderItem::hoverEnterEvent(QHoverEvent* event)
{
    updateHover(event->position());
}

void MessageHeaderItem::hoverMoveEvent(QHoverEvent* event)
{
    updateHover(event->position());
}

void MessageHeaderItem::hoverLeaveEvent(QHoverEvent*)
{
    clearHover();
    unsetCursor();
}

void MessageHeaderItem::mousePressEvent(QMouseEvent* event)
{
    applyPendingChanges();
    if (event->button() == Qt::LeftButton && m_displayNameClickable
            && regionAtPoint(event->position()) == Region::Name) {
        m_pressedOnName = true;
        event->accept();
        return;
    }
    event->ignore();
}

void MessageHeaderItem::mouseReleaseEvent(QMouseEvent* event)
{
    if (!m_pressedOnName) {
        event->ignore();
        return;
    }
    m_pressedOnName = false;
    event->accept();
    if (m_displayNameClickable && regionAtPoint(event->position()) == Region::Name)
        emit clicked(this);
}

void MessageHeaderItem::mouseUngrabEvent()
{
    m_pressedOnName = false;
}

QString MessageHeaderItem::displayName()
{
    applyPendingChanges();
    return m_prepared.name;
}

QString MessageHeaderItem::formattedTimestamp()
{
    applyPendingChanges();
    return m_prepared.timestamp;
}

QString MessageHeaderItem::accessibleText()
{
    applyPendingChanges();
    return m_accessibleText;
}

void MessageHeaderItem::updateAccessibleText()
{
    const PreparedHeader& p = m_prepared;
    QStringList pieces;
    pieces.reserve(7);
    const auto add = [&](const QString& text) {
        if (!text.isEmpty())
            pieces.append(text);
    };
    add(p.name);
    add(p.originInfo);
    add(p.verificationText);
    add(p.secondaryName);
    add(p.tertiaryDetail);
    add(p.timestamp);
    add(p.statusLabel);
    QString text = pieces.join(QStringLiteral(", "));
    if (text == m_accessibleText)
        return;
    m_accessibleText = std::move(text);
    emit accessibleTextChanged();
    ChatTextAccessibility::update(this);
}

QVariantMap MessageHeaderItem::displayData()
{
    applyPendingChanges();
    const PreparedHeader& p = m_prepared;
    QVariantList parts;
    for (const auto& part : m_parts) {
        parts.append(QVariantMap{
            {QStringLiteral("key"), QLatin1String(keyName(part->key))},
            {QStringLiteral("text"), part->text},
            {QStringLiteral("icon"), part->iconUrl},
            {QStringLiteral("x"), part->position.x()},
            {QStringLiteral("y"), part->position.y()},
            {QStringLiteral("width"), part->width},
            {QStringLiteral("height"), part->height},
            {QStringLiteral("lines"), part->icon || !part->line ? 0 : part->layout()->lineCount()},
        });
    }
    return {
        {QStringLiteral("name"), p.name},
        {QStringLiteral("originInfo"), p.originInfo},
        {QStringLiteral("secondaryName"), p.secondaryName},
        {QStringLiteral("tertiaryDetail"), p.tertiaryDetail},
        {QStringLiteral("timestamp"), p.timestamp},
        {QStringLiteral("statusIcon"), p.statusIcon},
        {QStringLiteral("statusLabel"), p.statusLabel},
        {QStringLiteral("verificationText"), p.verificationText},
        {QStringLiteral("resend"), p.resend},
        {QStringLiteral("parts"), parts},
    };
}

QSGNode* MessageHeaderItem::updatePaintNode(QSGNode* old, UpdatePaintNodeData*)
{
    QQuickWindow* win = window();
    if (!win || m_parts.empty()) {
        delete old;
        return nullptr;
    }
    auto* root = static_cast<RootNode*>(old);
    if (!root)
        root = new RootNode;

    // Existing part nodes, matched by revision: a part keeps its node while
    // it neither changes nor is recreated, wherever it moved in the list.
    QVarLengthArray<PartNode*, 16> existing;
    for (QSGNode* child = root->firstChild(); child; child = child->nextSibling()) {
        if (child != root->underline)
            existing.append(static_cast<PartNode*>(child));
    }
    const qreal dpr = win->effectiveDevicePixelRatio();
    for (const auto& partPointer : m_parts) {
        const Part& part = *partPointer;
        const bool drawn = part.icon ? !part.iconUrl.isEmpty() : !part.text.isEmpty();
        if (!drawn)
            continue;
        PartNode* node = nullptr;
        for (auto it = existing.begin(); it != existing.end(); ++it) {
            if ((*it)->revision == part.revision) {
                node = *it;
                existing.erase(it);
                break;
            }
        }
        if (node) {
            if (node->position != part.position) {
                node->position = part.position;
                node->setMatrix(translation(part.position));
            }
            continue;
        }
        node = new PartNode;
        node->revision = part.revision;
        node->position = part.position;
        node->setMatrix(translation(part.position));
        if (part.icon) {
            const IconRaster raster = iconImage(part.iconUrl, part.iconSize, dpr, part.color);
            QSGImageNode* image = win->createImageNode();
            image->setTexture(win->createTextureFromImage(raster.image));
            image->setOwnsTexture(true);
            image->setFiltering(QSGTexture::Linear);
            // Centred in its box, as Image centres a fitted picture.
            image->setRect(QRectF(QPointF((part.iconSize - raster.size.width()) / 2,
                                          (part.iconSize - raster.size.height()) / 2),
                                  raster.size));
            node->appendChildNode(image);
        } else {
            QSGTextNode* text = win->createTextNode();
            text->setColor(part.color);
            text->addTextLayout(QPointF(0, 0), const_cast<QTextLayout*>(part.layout()));
            node->appendChildNode(text);
        }
        root->appendChildNode(node);
    }
    for (PartNode* node : existing) {
        root->removeChildNode(node);
        delete node;
    }

    // Underline of the hovered, clickable name.
    const Part* name = m_parts.front()->key == Key::Name ? m_parts.front().get() : nullptr;
    const bool underline = name && m_nameHovered && m_displayNameClickable && !name->text.isEmpty();
    if (!underline) {
        if (root->underline) {
            root->removeChildNode(root->underline);
            delete root->underline;
            root->underline = nullptr;
        }
    } else if (!root->underline || root->underlineRevision != name->revision
               || root->underlinePosition != name->position || root->underlineColor != name->color) {
        if (root->underline) {
            root->removeChildNode(root->underline);
            delete root->underline;
        }
        root->underline = new QSGTransformNode;
        root->underline->setMatrix(translation(name->position));
        root->underlineRevision = name->revision;
        root->underlinePosition = name->position;
        root->underlineColor = name->color;
        const QTextLayout& nameLayout = *name->layout();
        const QFontMetricsF metrics(nameLayout.font());
        const qreal thickness = qMax<qreal>(1, metrics.lineWidth());
        for (int i = 0; i < nameLayout.lineCount(); ++i) {
            const QTextLine line = nameLayout.lineAt(i);
            QSGRectangleNode* rect = win->createRectangleNode();
            rect->setColor(name->color);
            const QRectF natural = line.naturalTextRect();
            rect->setRect(QRectF(natural.x(), line.y() + line.ascent() + metrics.underlinePos() - thickness / 2,
                                 natural.width(), thickness));
            root->underline->appendChildNode(rect);
        }
        root->appendChildNode(root->underline);
    }
    return root;
}
