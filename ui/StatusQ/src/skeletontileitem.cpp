#include "StatusQ/skeletontileitem.h"

#include <QElapsedTimer>
#include <QQuickWindow>
#include <QSGGeometryNode>
#include <QSGMaterial>
#include <QSGMaterialShader>

#include <cstring>

namespace {

constexpr qint64 kSweepDurationMs = 1000;

// shared by all tiles, so that they sweep in step whenever they were created
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

    // offsets follow the std140 layout of the uniform block in skeletontile.frag
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

    // called on the render thread while the GUI thread is blocked
    void sync(const SkeletonTileItem* item)
    {
        m_window = item->window();

        const QSizeF size = item->size();
        QSGGeometry::updateTexturedRectGeometry(geometry(), QRectF(QPointF(0, 0), size), QRectF(0, 0, 1, 1));
        markDirty(DirtyGeometry);

        auto* m = static_cast<SkeletonTileMaterial*>(material());
        m->color = item->color();
        m->highlightColor = item->highlightColor();
        m->itemSize = size;
        m->radius = item->radius();
        m->pixelRatio = m_window ? m_window->effectiveDevicePixelRatio() : 1;
        m->sweepOrigin = item->sweepOrigin();
        m->sweepSize = item->sweepSize();
        markDirty(DirtyMaterial);
    }

    // Runs once per frame only while the node is in the rendered scene, so a
    // hidden or removed tile stops requesting frames by itself.
    void preprocess() override
    {
        static_cast<SkeletonTileMaterial*>(material())->phase = sweepPhase();
        markDirty(DirtyMaterial);

        if (m_window)
            m_window->update();
    }

private:
    QQuickWindow* m_window = nullptr;
};

} // namespace

SkeletonTileItem::SkeletonTileItem(QQuickItem* parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents);
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
