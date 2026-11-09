#include "StatusQ/skeletontileitem.h"

#include "scenegraphanimation.h"

#include <QImage>
#include <QQuickWindow>
#include <QSGDynamicTexture>
#include <QSGGeometryNode>
#include <QSGMaterial>
#include <QSGMaterialShader>
#include <QSGTexture>
#include <QSGTextureProvider>
#include <QtQuick/private/qsgplaintexture_p.h>

#include <cstring>
#include <memory>

namespace {

constexpr qint64 kSweepDurationMs = 1000;

// shared by all tiles, so that they sweep in step whenever they were created
float sweepPhase()
{
    return float(sceneGraphClockMs() % kSweepDurationMs) / kSweepDurationMs;
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
    explicit SkeletonTileMaterial(bool masked)
        : masked(masked)
    {
        setFlag(Blending);
        setFlag(RequiresFullMatrix);
    }

    QSGMaterialType* type() const override
    {
        static QSGMaterialType plainType;
        static QSGMaterialType maskedType;
        return masked ? &maskedType : &plainType;
    }

    QSGMaterialShader* createShader(QSGRendererInterface::RenderMode) const override;

    // read on every frame: the provider replaces its texture between syncs
    QSGTexture* maskTexture()
    {
        if (maskProvider && maskProvider->texture())
            return maskProvider->texture();
        if (!emptyMask) {
            QImage transparent(1, 1, QImage::Format_RGBA8888_Premultiplied);
            transparent.fill(Qt::transparent);
            emptyMask = std::make_unique<QSGPlainTexture>();
            emptyMask->setImage(transparent);
        }
        return emptyMask.get();
    }

    const bool masked;
    QColor color;
    QColor highlightColor;
    QSizeF itemSize;
    QPointF sweepOrigin;
    QSizeF sweepSize;
    float radius = 0;
    float pixelRatio = 1;
    float phase = 0;
    QPointer<QSGTextureProvider> maskProvider;

private:
    std::unique_ptr<QSGPlainTexture> emptyMask;
};

class SkeletonTileShader : public QSGMaterialShader
{
public:
    explicit SkeletonTileShader(bool masked)
    {
        setShaderFileName(VertexStage, QStringLiteral(":/StatusQ/shaders/skeletontile.vert.qsb"));
        setShaderFileName(FragmentStage, masked
                              ? QStringLiteral(":/StatusQ/shaders/skeletontilemask.frag.qsb")
                              : QStringLiteral(":/StatusQ/shaders/skeletontile.frag.qsb"));
    }

    // offsets follow the std140 layout of the uniform block in skeletontile.frag
    bool updateUniformData(RenderState& state, QSGMaterial* newMaterial, QSGMaterial*) override
    {
        auto* m = static_cast<SkeletonTileMaterial*>(newMaterial);
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
        if (m->masked) {
            // where the mask sits in its atlas
            const QRectF subRect = m->maskTexture()->normalizedTextureSubRect();
            writeFloat(160, subRect.x());
            writeFloat(164, subRect.y());
            writeFloat(168, subRect.width());
            writeFloat(172, subRect.height());
        }
        return true;
    }

    void updateSampledImage(RenderState& state, int binding, QSGTexture** texture,
                            QSGMaterial* newMaterial, QSGMaterial*) override
    {
        if (binding != 1)
            return;
        QSGTexture* const t = static_cast<SkeletonTileMaterial*>(newMaterial)->maskTexture();
        t->commitTextureOperations(state.rhi(), state.resourceUpdateBatch());
        *texture = t;
    }
};

QSGMaterialShader* SkeletonTileMaterial::createShader(QSGRendererInterface::RenderMode) const
{
    return new SkeletonTileShader(masked);
}

class SkeletonTileNode : public QSGGeometryNode
{
public:
    explicit SkeletonTileNode(bool masked)
    {
        auto geometry = new QSGGeometry(QSGGeometry::defaultAttributes_TexturedPoint2D(), 4);
        setGeometry(geometry);
        setMaterial(new SkeletonTileMaterial(masked));
        setFlags(OwnsGeometry | OwnsMaterial | UsePreprocess);
    }

    bool isMasked() const { return static_cast<const SkeletonTileMaterial*>(material())->masked; }

    // called on the render thread while the GUI thread is blocked
    void sync(const SkeletonTileItem* item, QSGTextureProvider* maskProvider)
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
        m->maskProvider = maskProvider;
        markDirty(DirtyMaterial);
    }

    // Runs once per frame only while the node is in the rendered scene, so a
    // hidden or removed tile stops requesting frames by itself.
    void preprocess() override
    {
        auto* m = static_cast<SkeletonTileMaterial*>(material());
        m->phase = sweepPhase();
        if (m->masked) {
            if (auto* dynamicMask = qobject_cast<QSGDynamicTexture*>(m->maskTexture()))
                dynamicMask->updateTexture();
        }
        markDirty(DirtyMaterial);

        if (m_window)
            requestNextFrame(m_window);
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

void SkeletonTileItem::setMask(QQuickItem* mask)
{
    if (m_mask == mask)
        return;
    if (m_mask)
        disconnect(m_mask, &QObject::destroyed, this, nullptr);
    m_mask = mask;
    if (mask) {
        connect(mask, &QObject::destroyed, this, [this] {
            update();
            emit maskChanged();
        });
    }
    update();
    emit maskChanged();
}

QSGNode* SkeletonTileItem::updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*)
{
    auto* node = static_cast<SkeletonTileNode*>(oldNode);

    QSGTextureProvider* const provider = m_mask && m_mask->isTextureProvider()
                                             ? m_mask->textureProvider() : nullptr;
    if (provider != m_maskProvider) {
        if (m_maskProvider)
            disconnect(m_maskProvider, nullptr, this, nullptr);
        m_maskProvider = provider;
        if (provider) {
            connect(provider, &QSGTextureProvider::textureChanged,
                    this, &QQuickItem::update, Qt::QueuedConnection);
        }
    }

    const bool masked = !m_mask.isNull();
    if (width() <= 0 || height() <= 0 || (masked && !(provider && provider->texture()))) {
        delete node;
        return nullptr;
    }

    if (node && node->isMasked() != masked) {
        delete node;
        node = nullptr;
    }
    if (!node)
        node = new SkeletonTileNode(masked);

    node->sync(this, provider);
    return node;
}
