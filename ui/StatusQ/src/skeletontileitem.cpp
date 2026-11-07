#include "StatusQ/skeletontileitem.h"

#include <QElapsedTimer>
#include <QQuickWindow>
#include <QSet>
#include <QSGGeometryNode>
#include <QSGMaterial>
#include <QSGMaterialShader>
#include <QTimer>

#include <cstring>

namespace {

constexpr qint64 kSweepDurationMs = 1000;

float sweepPhase()
{
    static const QElapsedTimer clock = [] {
        QElapsedTimer timer;
        timer.start();
        return timer;
    }();
    return float(clock.elapsed() % kSweepDurationMs) / kSweepDurationMs;
}

void writePremultiplied(char* dst, const QColor& color)
{
    const float a = color.alphaF();
    const float rgba[4] = {color.redF() * a, color.greenF() * a, color.blueF() * a, a};
    std::memcpy(dst, rgba, sizeof(rgba));
}

class SkeletonTileMaterial : public QSGMaterial
{
public:
    SkeletonTileMaterial()
    {
        setFlag(Blending);
        setFlag(RequiresFullMatrix);
    }

    QSGMaterialType* type() const override
    {
        static QSGMaterialType type;
        return &type;
    }

    QSGMaterialShader* createShader(QSGRendererInterface::RenderMode) const override;

    QColor color;
    QColor highlightColor;
    QSizeF itemSize;
    QPointF sweepOrigin;
    QSizeF sweepSize;
    float radius = 0;
    float pixelRatio = 1;
    float phase = 0;
};

class SkeletonTileShader : public QSGMaterialShader
{
public:
    SkeletonTileShader()
    {
        setShaderFileName(VertexStage, QStringLiteral(":/StatusQ/shaders/skeletontile.vert.qsb"));
        setShaderFileName(FragmentStage, QStringLiteral(":/StatusQ/shaders/skeletontile.frag.qsb"));
    }

    bool updateUniformData(RenderState& state, QSGMaterial* newMaterial, QSGMaterial*) override
    {
        const auto* m = static_cast<SkeletonTileMaterial*>(newMaterial);
        char* buf = state.uniformData()->data();

        const auto writeFloat = [buf](int offset, float value) {
            std::memcpy(buf + offset, &value, sizeof(value));
        };

        std::memcpy(buf, state.combinedMatrix().constData(), 64);
        writeFloat(64, state.opacity());
        writeFloat(72, m->itemSize.width());
        writeFloat(76, m->itemSize.height());
        writeFloat(80, m->radius);
        writeFloat(84, m->pixelRatio);
        writePremultiplied(buf + 96, m->color);
        writePremultiplied(buf + 112, m->highlightColor);
        writeFloat(128, m->sweepOrigin.x());
        writeFloat(132, m->sweepOrigin.y());
        writeFloat(136, m->sweepSize.width());
        writeFloat(140, m->sweepSize.height());
        writeFloat(144, m->phase);
        return true;
    }
};

QSGMaterialShader* SkeletonTileMaterial::createShader(QSGRendererInterface::RenderMode) const
{
    return new SkeletonTileShader;
}

bool tileShouldSweep(const QQuickItem* item)
{
    return item->window() && item->isVisible() && item->width() > 0 && item->height() > 0;
}

// Drives item->update() on the GUI thread while any tile is on screen.
class SweepTicker : public QObject
{
public:
    static SweepTicker& instance()
    {
        static SweepTicker ticker;
        return ticker;
    }

    void add(QQuickItem* item)
    {
        m_items.insert(item);
        if (!m_timer.isActive())
            m_timer.start();
    }

    void remove(QQuickItem* item) { m_items.remove(item); }

private:
    SweepTicker()
    {
        m_timer.setInterval(1000 / 60);
        connect(&m_timer, &QTimer::timeout, this, [this] {
            for (auto it = m_items.begin(); it != m_items.end(); ) {
                QQuickItem* item = *it;
                if (!tileShouldSweep(item)) {
                    it = m_items.erase(it);
                    continue;
                }
                item->update();
                ++it;
            }
            if (m_items.isEmpty())
                m_timer.stop();
        });
    }

    QTimer m_timer;
    QSet<QQuickItem*> m_items;
};

class SkeletonTileNode : public QSGGeometryNode
{
public:
    SkeletonTileNode()
    {
        auto geometry = new QSGGeometry(QSGGeometry::defaultAttributes_TexturedPoint2D(), 4);
        setGeometry(geometry);
        setMaterial(new SkeletonTileMaterial);
        setFlags(OwnsGeometry | OwnsMaterial | UsePreprocess);
    }

    void sync(const SkeletonTileItem* item)
    {
        const QSizeF size = item->size();
        QSGGeometry::updateTexturedRectGeometry(geometry(), QRectF(QPointF(0, 0), size), QRectF(0, 0, 1, 1));
        markDirty(DirtyGeometry);

        auto* m = static_cast<SkeletonTileMaterial*>(material());
        m->color = item->color();
        m->highlightColor = item->highlightColor();
        m->itemSize = size;
        m->radius = item->radius();
        const auto* window = item->window();
        m->pixelRatio = window ? window->effectiveDevicePixelRatio() : 1;
        m->sweepOrigin = item->sweepOrigin();
        m->sweepSize = item->sweepSize();
        markDirty(DirtyMaterial);
    }

    void preprocess() override
    {
        static_cast<SkeletonTileMaterial*>(material())->phase = sweepPhase();
        markDirty(DirtyMaterial);
    }
};

} // namespace

SkeletonTileItem::SkeletonTileItem(QQuickItem* parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents);
}

SkeletonTileItem::~SkeletonTileItem()
{
    SweepTicker::instance().remove(this);
}

void SkeletonTileItem::itemChange(ItemChange change, const ItemChangeData& value)
{
    QQuickItem::itemChange(change, value);
    if (change == ItemVisibleHasChanged || change == ItemSceneChange)
        syncSweep();
}

void SkeletonTileItem::geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    if ((newGeometry.width() > 0) != (oldGeometry.width() > 0)
        || (newGeometry.height() > 0) != (oldGeometry.height() > 0))
        syncSweep();
}

void SkeletonTileItem::syncSweep()
{
    if (tileShouldSweep(this))
        SweepTicker::instance().add(this);
    else
        SweepTicker::instance().remove(this);
}

void SkeletonTileItem::setColor(const QColor& color)
{
    if (m_color == color)
        return;
    m_color = color;
    update();
    emit colorChanged();
}

void SkeletonTileItem::setHighlightColor(const QColor& color)
{
    if (m_highlightColor == color)
        return;
    m_highlightColor = color;
    update();
    emit highlightColorChanged();
}

void SkeletonTileItem::setRadius(qreal radius)
{
    if (qFuzzyCompare(m_radius, radius))
        return;
    m_radius = radius;
    update();
    emit radiusChanged();
}

void SkeletonTileItem::setSweepOrigin(const QPointF& origin)
{
    if (m_sweepOrigin == origin)
        return;
    m_sweepOrigin = origin;
    update();
    emit sweepOriginChanged();
}

void SkeletonTileItem::setSweepSize(const QSizeF& size)
{
    if (m_sweepSize == size)
        return;
    m_sweepSize = size;
    update();
    emit sweepSizeChanged();
}

QSGNode* SkeletonTileItem::updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*)
{
    auto* node = static_cast<SkeletonTileNode*>(oldNode);

    if (width() <= 0 || height() <= 0) {
        delete node;
        return nullptr;
    }

    if (!node)
        node = new SkeletonTileNode;

    node->sync(this);
    return node;
}
