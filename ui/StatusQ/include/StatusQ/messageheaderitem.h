#pragma once

#include "StatusQ/messageheaderdata.h"
#include "StatusQ/messageheaderappearance.h"
#include "StatusQ/messageheaderservices.h"

#include <QQuickItem>
#include <QPointer>
#include <QFont>
#include <QColor>
#include <QVariantMap>
#include <memory>
#include <vector>

// Experimental renderer used by StatusMessageHeaderPrototype. Message values
// are strongly typed; appearance is shared and interaction flags are per item.
class MessageHeaderItem : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(MessageHeaderServices* services READ services WRITE setServices NOTIFY servicesChanged)
    Q_PROPERTY(QQuickItem* trailingItem READ trailingItem WRITE setTrailingItem NOTIFY trailingItemChanged)
    Q_PROPERTY(MessageHeaderData headerData READ headerData WRITE setHeaderData NOTIFY headerDataChanged)
    Q_PROPERTY(bool expired READ expired NOTIFY headerDataChanged)
    Q_PROPERTY(qint64 rawTimestamp READ rawTimestamp NOTIFY headerDataChanged)
    Q_PROPERTY(QVariantMap displayData READ displayData NOTIFY displayDataChanged)
    Q_PROPERTY(QString accessibleText READ accessibleText NOTIFY accessibleTextChanged)
    Q_PROPERTY(MessageHeaderAppearance* appearance READ appearance WRITE setAppearance NOTIFY appearanceChanged)
    Q_PROPERTY(bool displayNameClickable READ displayNameClickable WRITE setDisplayNameClickable NOTIFY displayNameClickableChanged)
    Q_PROPERTY(bool showOutgoingStatusLabel READ showOutgoingStatusLabel WRITE setShowOutgoingStatusLabel NOTIFY showOutgoingStatusLabelChanged)
    Q_PROPERTY(bool showFullTimestamp READ showFullTimestamp WRITE setShowFullTimestamp NOTIFY showFullTimestampChanged)
    Q_PROPERTY(bool isMobile READ isMobile WRITE setIsMobile NOTIFY isMobileChanged)
    Q_PROPERTY(QString timestampText READ timestampText NOTIFY timestampTextChanged)
    Q_PROPERTY(QRectF textRect READ textRect NOTIFY layoutChanged)
    Q_PROPERTY(QRectF nameRect READ nameRect NOTIFY layoutChanged)
    Q_PROPERTY(qreal contentWidth READ contentWidth NOTIFY layoutChanged)
    Q_PROPERTY(int hoveredPart READ hoveredPart NOTIFY hoveredPartChanged)
public:
    enum HitPart { None, Name, Verification, Timestamp };
    Q_ENUM(HitPart)
    explicit MessageHeaderItem(QQuickItem* parent = nullptr);
    ~MessageHeaderItem() override;
    MessageHeaderServices* services() const { return m_services; }
    void setServices(MessageHeaderServices* value);
    QQuickItem* trailingItem() const { return m_trailingItem; }
    void setTrailingItem(QQuickItem* item);
    MessageHeaderData headerData() const { return m_headerData; }
    void setHeaderData(const MessageHeaderData& value);
    bool expired() const { return m_headerData.outgoingStatus() == MessageHeaderData::Expired; }
    qint64 rawTimestamp() const { return m_headerData.timestamp(); }
    Q_INVOKABLE bool dataIsContact() const { return m_headerData.isContact(); }
    Q_INVOKABLE int dataTrustIndicator() const { return m_headerData.trustIndicator(); }
    QVariantMap displayData() const;
    QString accessibleText() const;
    MessageHeaderAppearance* appearance() const { return m_appearance; }
    void setAppearance(MessageHeaderAppearance* value);
    bool displayNameClickable() const { return m_clickable; }
    bool showOutgoingStatusLabel() const { return m_showOutgoingStatusLabel; }
    bool showFullTimestamp() const { return m_showFullTimestamp; }
    bool isMobile() const { return m_isMobile; }
    void setDisplayNameClickable(bool value);
    void setShowOutgoingStatusLabel(bool value);
    void setShowFullTimestamp(bool value);
    void setIsMobile(bool value);
    QString timestampText() const;
    Q_INVOKABLE QString fullTimestampText() const;
    Q_INVOKABLE void refreshTimestamp();
    Q_INVOKABLE QRectF partRect(int role) const;
    QRectF textRect() const { return m_textRect; }
    QRectF nameRect() const { return m_nameRect; }
    qreal contentWidth() const { return m_contentWidth; }
    int hoveredPart() const { return m_hoveredPart; }
signals:
    void trailingItemChanged();
    void servicesChanged();
    void appearanceChanged();
    void displayNameClickableChanged();
    void showOutgoingStatusLabelChanged();
    void showFullTimestampChanged();
    void isMobileChanged();
    void headerDataChanged();
    void displayDataChanged();
    void accessibleTextChanged();
    void layoutChanged();
    void timestampTextChanged();
    void hoveredPartChanged();
    void nameClicked();
    void resendClicked();
protected:
    void componentComplete() override;
    void geometryChange(const QRectF& now, const QRectF& before) override;
    void updatePolish() override;
    void itemChange(ItemChange change, const ItemChangeData& value) override;
    QSGNode* updatePaintNode(QSGNode* old, UpdatePaintNodeData*) override;
    void hoverMoveEvent(QHoverEvent* event) override;
    void hoverEnterEvent(QHoverEvent* event) override;
    void hoverLeaveEvent(QHoverEvent* event) override;
    void mousePressEvent(QMouseEvent* event) override;
    void mouseReleaseEvent(QMouseEvent* event) override;
private:
    friend class MessageHeaderServices;
    enum class PartKey {
        Name, Origin, VerificationFirst, VerificationSecond, Secondary,
        DetailSeparator, Tertiary, TimestampSeparator, Timestamp, StatusIcon, StatusText
    };
    struct Part;
    struct TimestampCache;
    bool updateTimestamp();
    void prepareDisplayData();
    void prepareStatusData();
    void connectAppearance();
    enum Dirty { ContentDirty = 1, PartsDirty = 2, GeometryDirty = 4, ClockDirty = 8, StatusDirty = 16,
                 AllDirty = ContentDirty | PartsDirty | GeometryDirty | ClockDirty };
    void scheduleLayout(int dirty = AllDirty);
    void syncResendItem();
    void clearResendItem();
    bool updateParts();
    bool layoutParts();
    void setHoveredPart(int value);
    int partAt(const QPointF& point) const;
    QPointer<MessageHeaderServices> m_services;
    QPointer<QQuickItem> m_trailingItem;
    QPointer<QQuickItem> m_resendItem;
    MessageHeaderAppearance* m_appearance = MessageHeaderAppearance::defaults();
    bool m_appearancePending = true;
    bool m_timestampDirty = true;
    bool m_showOutgoingStatusLabel = false, m_showFullTimestamp = false, m_isMobile = false;
    struct PreparedHeader {
        QString name, senderId, origin, secondary, tertiary, statusText;
        QList<QUrl> verificationIcons;
        QUrl statusIcon;
        int verificationSize = 10;
        bool warning = false;
    };
    PreparedHeader m_prepared;
    MessageHeaderData m_headerData;
    std::unique_ptr<TimestampCache> m_timestampCache;
    bool m_clickable = true;
    std::vector<std::unique_ptr<Part>> m_parts;
    // Unique across parts and lifetimes, including changes coalesced before paint.
    quint64 m_partRevision = 0;
    QRectF m_nameRect;
    QRectF m_textRect;
    qreal m_contentWidth = 0;
    int m_hoveredPart = None;
    bool m_pressed = false;
    bool m_pointerHovered = false;
    bool m_tooltipDirty = true;
    QPointF m_hoverPosition;
    int m_dirty = AllDirty;
    bool m_accessibilityPending = false;
};
