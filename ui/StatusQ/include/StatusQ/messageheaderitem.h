#pragma once

#include "StatusQ/messageheaderappearance.h"
#include "StatusQ/messageheaderdata.h"
#include "StatusQ/messageheaderservices.h"

#include <QColor>
#include <QPointer>
#include <QQuickItem>
#include <QTextLayout>
#include <QUrl>
#include <QVariantMap>

#include <memory>
#include <vector>

// A message header (sender name, verification, details, timestamp, delivery
// status) as one item: text is laid out with QTextLayout and drawn as text
// and image nodes, without an item per label.
//
// Content, status, timestamp, colours, fonts, geometry and hover are
// invalidated separately and coalesced in updatePolish(); each text part keeps
// its layout while its text and font are unchanged, and its scene graph node
// while it neither changes nor moves.
class MessageHeaderItem : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(MessageHeaderAppearance* appearance READ appearance WRITE setAppearance
               NOTIFY appearanceChanged)
    Q_PROPERTY(MessageHeaderServices* services READ services WRITE setServices NOTIFY servicesChanged)
    Q_PROPERTY(MessageHeaderData headerData READ headerData WRITE setHeaderData NOTIFY headerDataChanged)
    Q_PROPERTY(bool displayNameClickable READ displayNameClickable WRITE setDisplayNameClickable
               NOTIFY displayNameClickableChanged)
    Q_PROPERTY(bool showFullTimestamp READ showFullTimestamp WRITE setShowFullTimestamp
               NOTIFY showFullTimestampChanged)
    Q_PROPERTY(bool showOutgoingStatusLabel READ showOutgoingStatusLabel
               WRITE setShowOutgoingStatusLabel NOTIFY showOutgoingStatusLabelChanged)
    Q_PROPERTY(bool isMobile READ isMobile WRITE setIsMobile NOTIFY isMobileChanged)

    // Outputs. Reading any of them first applies pending changes.
    Q_PROPERTY(QString displayName READ displayName NOTIFY displayDataChanged)
    Q_PROPERTY(QString formattedTimestamp READ formattedTimestamp NOTIFY formattedTimestampChanged)
    Q_PROPERTY(QString accessibleText READ accessibleText NOTIFY accessibleTextChanged)
    // Diagnostic: assembled only when read, not used for rendering.
    Q_PROPERTY(QVariantMap displayData READ displayData NOTIFY displayDataChanged)
    Q_PROPERTY(bool nameHovered READ nameHovered NOTIFY nameHoveredChanged)
    Q_PROPERTY(QQuickItem* resendButtonItem READ resendButtonItem NOTIFY resendButtonItemChanged)
public:
    explicit MessageHeaderItem(QQuickItem* parent = nullptr);
    ~MessageHeaderItem() override;

    MessageHeaderAppearance* appearance() const;
    void setAppearance(MessageHeaderAppearance* appearance);
    MessageHeaderServices* services() const { return m_services; }
    void setServices(MessageHeaderServices* services);
    MessageHeaderData headerData() const { return m_data; }
    void setHeaderData(const MessageHeaderData& data);
    bool displayNameClickable() const { return m_displayNameClickable; }
    void setDisplayNameClickable(bool value);
    bool showFullTimestamp() const { return m_showFullTimestamp; }
    void setShowFullTimestamp(bool value);
    bool showOutgoingStatusLabel() const { return m_showOutgoingStatusLabel; }
    void setShowOutgoingStatusLabel(bool value);
    bool isMobile() const { return m_isMobile; }
    void setIsMobile(bool value);

    QString displayName();
    QString formattedTimestamp();
    QString accessibleText();
    QVariantMap displayData();
    bool nameHovered() const { return m_nameHovered; }
    QQuickItem* resendButtonItem() const { return m_resendButton; }

    // The long date and time, as the timestamp tooltip shows it.
    Q_INVOKABLE QString fullTimestamp() const;
    // Region under a point: "name", "verification", "timestamp" or "".
    Q_INVOKABLE QString regionAt(qreal x, qreal y);
    // Geometry of a part by key ("name", "timestamp", ...); empty if absent.
    Q_INVOKABLE QRectF partRect(const QString& key);
    // Applies pending changes now instead of at the next polish.
    Q_INVOKABLE void applyPendingChanges();

    // From MessageHeaderServices.
    void clockChanged();
    void servicesDestroyed();

signals:
    void appearanceChanged();
    void servicesChanged();
    void headerDataChanged();
    void displayNameClickableChanged();
    void showFullTimestampChanged();
    void showOutgoingStatusLabelChanged();
    void isMobileChanged();
    void layoutChanged();
    void formattedTimestampChanged();
    void accessibleTextChanged();
    void displayDataChanged();
    void nameHoveredChanged();
    void resendButtonItemChanged();

    void clicked(QQuickItem* sender);
    void resendClicked();

protected:
    void componentComplete() override;
    void updatePolish() override;
    QSGNode* updatePaintNode(QSGNode* old, UpdatePaintNodeData*) override;
    void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;
    void itemChange(ItemChange change, const ItemChangeData& value) override;
    void hoverEnterEvent(QHoverEvent* event) override;
    void hoverMoveEvent(QHoverEvent* event) override;
    void hoverLeaveEvent(QHoverEvent* event) override;
    void mousePressEvent(QMouseEvent* event) override;
    void mouseReleaseEvent(QMouseEvent* event) override;
    void mouseUngrabEvent() override;

public:
    // Semantic roles, in display order. A part keeps its key when optional
    // parts before it come and go, so its layout and node are reused.
    enum class Key : quint8 {
        Name, OriginInfo, TrustIcon, ContactIcon, SecondaryName, FirstDot,
        TertiaryDetail, SecondDot, Timestamp, StatusIcon, StatusLabel
    };
    enum class Region : quint8 { None, Name, Verification, Timestamp };

private:
    enum Dirty : quint16 {
        DirtyContent = 1,     // every part from data, texts, metrics
        DirtyStatus = 2,      // delivery status and resend only
        DirtyTimestamp = 4,   // timestamp text
        DirtyFonts = 8,       // reshape every text part
        DirtyColors = 16,     // repaint every part
        DirtyGeometry = 32,   // positions and name wrapping
    };

    // What the parts show, prepared from the data, the flags and the
    // appearance. Rendering and accessibility read these fields directly.
    struct PreparedHeader
    {
        QString name;
        QString originInfo;
        QString secondaryName;
        QString tertiaryDetail;
        QString timestamp;
        QString statusLabel;
        QString trustIcon;      // icon name, or empty
        QString statusIcon;     // icon name, or empty (the slot stays)
        QString verificationText;
        bool contactIcon = false;
        bool verificationSlot = false;
        bool firstDot = false;
        bool secondDot = false;
        bool hasTertiary = false;
        bool status = false;
        bool statusLabelShown = false;
        bool statusWarning = false;
        bool resend = false;
    };

    struct Part
    {
        Key key;
        bool icon = false;
        bool nameFont = false;
        QString text;
        QUrl iconUrl;
        qreal iconSize = 0;
        QColor color;          // text colour, or icon tint (invalid: none)
        // Shared single line; a wrapped name has its own layout instead.
        std::shared_ptr<const MessageHeaderShapedText> line;
        std::unique_ptr<QTextLayout> wrapped;
        const QTextLayout* layout() const;
        bool shaped = false;
        qreal naturalWidth = 0;
        qreal width = 0;
        qreal height = 0;
        qreal wrapWidth = -1;  // name only: the width it was wrapped at
        QPointF position;
        quint64 revision = 0;
    };

    struct Cell
    {
        int first = 0;
        int count = 0;
        qreal width = 0;
        qreal height = 0;
        bool resend = false;
    };

    void connectAppearance();
    void invalidate(quint16 flags);
    void process();
    void prepareContent();
    void prepareStatus();
    void prepareTimestamp();
    void syncParts();
    void syncResendButton();
    void shapePart(Part& part);
    void layoutName(Part& part, qreal width);
    void computeGeometry();
    void touch(Part& part) { part.revision = ++m_revision; }
    Part* findPart(Key key) const;
    Region regionAtPoint(const QPointF& point) const;
    void updateHover(const QPointF& point);
    void clearHover();
    void refreshTooltip();
    void updateClockSubscription();
    void setNameHovered(bool hovered);
    void updateAccessibleText();
    const MessageHeaderTimeFormats& timeFormats() const;
    bool statusFlagsMatter() const;

    QPointer<MessageHeaderAppearance> m_appearance;
    QPointer<MessageHeaderServices> m_services;
    QList<QMetaObject::Connection> m_appearanceConnections;
    MessageHeaderData m_data;
    bool m_displayNameClickable = true;
    bool m_showFullTimestamp = false;
    bool m_showOutgoingStatusLabel = false;
    bool m_isMobile = false;

    quint16 m_dirty = DirtyContent | DirtyTimestamp | DirtyGeometry;
    bool m_complete = false;
    PreparedHeader m_prepared;
    std::vector<std::unique_ptr<Part>> m_parts;
    std::vector<Cell> m_cells;
    quint64 m_revision = 0;
    QPointer<QQuickItem> m_resendButton;
    QString m_accessibleText;

    // Timestamp formatting cache.
    double m_formattedFor = -1;
    bool m_formattedFull = false;
    quint64 m_formattedTimeFormat = 0;
    quint64 m_formattedClock = 0;
    const void* m_formattedAppearance = nullptr;
    bool m_clockSubscribed = false;

    // Hover and press.
    bool m_hovering = false;
    QPointF m_hoverPoint;
    Region m_hoverRegion = Region::None;
    bool m_nameHovered = false;
    bool m_pressedOnName = false;
};
