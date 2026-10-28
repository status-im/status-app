#include "StatusQ/roundedimagebase.h"

#include <QtCore/QtMath>
#include <QtQuick/QQuickWindow>
#include <QtQuick/QSGGeometryNode>
#include <QtQuick/QSGMaterial>
#include <QtQuick/QSGMaterialShader>
#include <QtQuick/QSGRendererInterface>
#include <QtQuick/QSGTexture>
#include <QtQuick/private/qquickimage_p.h>
#include <QtQuick/private/qquickimage_p_p.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstring>
#include <tuple>
#include <type_traits>

namespace {

// One vertex of the quad: the painted image, grown by the border and the
// background. Everything but the position, texture and painted coordinates
// is the same on all four vertices, so it reaches the fragment shader
// unchanged; carrying it per vertex instead of in uniforms lets the renderer
// merge images.
using Color = std::array<float, 4>;

struct Vertex
{
    float x = 0, y = 0;    // item coordinates
    float u = 0, v = 0;    // texture coordinates, in the atlas when atlased
    float paintedX = 0, paintedY = 0; // 0..1 across the painted image
    float localX = 0, localY = 0; // from the rounded shape's centre
    float halfW = 0, halfH = 0; // half the rounded shape
    std::array<float, 4> radii{}; // outer: top-left, top-right, bottom-right, bottom-left
    float cutoutX = 0, cutoutY = 0, cutoutRadius = 0; // from the rounded shape's centre
    float borderWidth = 0;
    Color borderColor{};   // premultiplied
    Color backgroundColor{}; // premultiplied
};

// laid out as the attributes below declare it, read in place from the
// geometry's vertex data
static_assert(std::is_standard_layout_v<Vertex>);
static_assert(sizeof(Vertex) == 26 * sizeof(float));

// Locations 0-6: batchable vertex shaders take 7 for the z order.

const QSGGeometry::AttributeSet& attributes()
{
    static const QSGGeometry::Attribute data[] = {
        QSGGeometry::Attribute::createWithAttributeType(0, 2, QSGGeometry::FloatType,
                                                        QSGGeometry::PositionAttribute),
        // texture, painted
        QSGGeometry::Attribute::createWithAttributeType(1, 4, QSGGeometry::FloatType,
                                                        QSGGeometry::TexCoordAttribute),
        // local, half size
        QSGGeometry::Attribute::createWithAttributeType(2, 4, QSGGeometry::FloatType,
                                                        QSGGeometry::UnknownAttribute),
        QSGGeometry::Attribute::createWithAttributeType(3, 4, QSGGeometry::FloatType,
                                                        QSGGeometry::UnknownAttribute),
        // cut-out, border width
        QSGGeometry::Attribute::createWithAttributeType(4, 4, QSGGeometry::FloatType,
                                                        QSGGeometry::UnknownAttribute),
        QSGGeometry::Attribute::createWithAttributeType(5, 4, QSGGeometry::FloatType,
                                                        QSGGeometry::UnknownAttribute),
        QSGGeometry::Attribute::createWithAttributeType(6, 4, QSGGeometry::FloatType,
                                                        QSGGeometry::UnknownAttribute),
    };
    static const QSGGeometry::AttributeSet set = { 7, sizeof(Vertex), data };
    return set;
}

// With a texture: the image, its border and background. Without (no image
// yet, or an error): the border and background alone, by a shader with no
// sampler.
class RoundedImageMaterial : public QSGMaterial
{
public:
    explicit RoundedImageMaterial(bool isTextured)
        : textured(isTextured)
    {
        setFlag(Blending);
    }

    QSGMaterialType* type() const override
    {
        static QSGMaterialType texturedType;
        static QSGMaterialType borderType;
        return textured ? &texturedType : &borderType;
    }

    QSGMaterialShader* createShader(QSGRendererInterface::RenderMode) const override;

    // By texture and sampling only: images in one atlas texture can share a
    // draw call.
    int compare(const QSGMaterial* other) const override
    {
        const auto key = [](const RoundedImageMaterial* m) {
            return std::tuple(m->texture ? m->texture->comparisonKey() : 0, m->filtering,
                              m->mipmapFiltering, m->hWrap, m->vWrap);
        };
        const auto a = key(this);
        const auto b = key(static_cast<const RoundedImageMaterial*>(other));
        return a < b ? -1 : b < a ? 1 : 0;
    }

    const bool textured = false;
    QSGTexture* texture = nullptr; // not owned
    QSGTexture::Filtering filtering = QSGTexture::Linear;
    QSGTexture::Filtering mipmapFiltering = QSGTexture::None;
    QSGTexture::WrapMode hWrap = QSGTexture::ClampToEdge;
    QSGTexture::WrapMode vWrap = QSGTexture::ClampToEdge;
    // texture taken out of the atlas for repeating
    bool repeat = false;
};

class RoundedImageShader : public QSGMaterialShader
{
public:
    explicit RoundedImageShader(bool textured)
    {
        setShaderFileName(VertexStage, QStringLiteral(":/StatusQ/shaders/roundedrendersizedimage.vert.qsb"));
        setShaderFileName(FragmentStage,
                          textured ? QStringLiteral(":/StatusQ/shaders/roundedrendersizedimage.frag.qsb")
                                   : QStringLiteral(":/StatusQ/shaders/roundedrendersizedimageborder.frag.qsb"));
    }

    // the uniform block: qt_Matrix, then qt_Opacity
    static constexpr std::size_t MatrixSize = 16 * sizeof(float);
    static constexpr std::size_t OpacityOffset = MatrixSize;

    bool updateUniformData(RenderState& state, QSGMaterial*, QSGMaterial*) override
    {
        QByteArray* const buffer = state.uniformData();
        bool changed = false;
        if (state.isMatrixDirty()) {
            const QMatrix4x4 matrix = state.combinedMatrix();
            std::memcpy(buffer->data(), matrix.constData(), MatrixSize);
            changed = true;
        }
        if (state.isOpacityDirty()) {
            const float opacity = state.opacity();
            std::memcpy(buffer->data() + OpacityOffset, &opacity, sizeof(opacity));
            changed = true;
        }
        return changed;
    }

    void updateSampledImage(RenderState& state, int binding, QSGTexture** texture,
                            QSGMaterial* newMaterial, QSGMaterial*) override
    {
        if (binding != 1)
            return;
        const auto material = static_cast<RoundedImageMaterial*>(newMaterial);
        QSGTexture* const t = material->texture;
        if (!t)
            return;
        t->setFiltering(material->filtering);
        t->setMipmapFiltering(material->mipmapFiltering);
        t->setHorizontalWrapMode(material->hWrap);
        t->setVerticalWrapMode(material->vWrap);
        t->commitTextureOperations(state.rhi(), state.resourceUpdateBatch());
        *texture = t;
    }
};

QSGMaterialShader* RoundedImageMaterial::createShader(QSGRendererInterface::RenderMode) const
{
    return new RoundedImageShader(textured);
}

class RoundedImageNode : public QSGGeometryNode
{
public:
    explicit RoundedImageNode(bool textured)
        : m_geometry(attributes(), 4, 6)
        , m_material(textured)
    {
        m_geometry.setDrawingMode(QSGGeometry::DrawTriangles);
        static constexpr std::array<quint16, 6> quad{ 0, 1, 2, 2, 1, 3 };
        std::copy(quad.begin(), quad.end(), m_geometry.indexDataAsUShort());
        setGeometry(&m_geometry);
        setMaterial(&m_material);
    }

    RoundedImageMaterial* roundedMaterial() { return &m_material; }
    QSGGeometry* roundedGeometry() { return &m_geometry; }

private:
    QSGGeometry m_geometry;
    RoundedImageMaterial m_material;
};

// The node, or a new one if it draws the other kind
RoundedImageNode* nodeOfKind(RoundedImageNode* node, bool textured)
{
    if (node && node->roundedMaterial()->textured == textured)
        return node;
    delete node;
    return new RoundedImageNode(textured);
}

} // namespace

RoundedImageBase::RoundedImageBase(QQuickImage* item)
    : m_item(item)
{
}

void RoundedImageBase::changed()
{
    notifyShapeChanged();
    m_item->update();
}

qreal RoundedImageBase::radius() const
{
    return m_radius;
}

void RoundedImageBase::setRadius(qreal radius)
{
    if (m_radius == radius)
        return;
    m_radius = radius;
    changed();
}

qreal RoundedImageBase::cornerRadius(Corner corner) const
{
    return m_corners[corner] < 0 ? m_radius : m_corners[corner];
}

void RoundedImageBase::setCornerRadius(Corner corner, qreal radius)
{
    if (m_corners[corner] == radius)
        return;
    m_corners[corner] = radius;
    changed();
}

qreal RoundedImageBase::topLeftRadius() const { return cornerRadius(TopLeft); }
void RoundedImageBase::setTopLeftRadius(qreal r) { setCornerRadius(TopLeft, qMax(r, 0.0)); }
void RoundedImageBase::resetTopLeftRadius() { setCornerRadius(TopLeft, -1); }
qreal RoundedImageBase::topRightRadius() const { return cornerRadius(TopRight); }
void RoundedImageBase::setTopRightRadius(qreal r) { setCornerRadius(TopRight, qMax(r, 0.0)); }
void RoundedImageBase::resetTopRightRadius() { setCornerRadius(TopRight, -1); }
qreal RoundedImageBase::bottomRightRadius() const { return cornerRadius(BottomRight); }
void RoundedImageBase::setBottomRightRadius(qreal r) { setCornerRadius(BottomRight, qMax(r, 0.0)); }
void RoundedImageBase::resetBottomRightRadius() { setCornerRadius(BottomRight, -1); }
qreal RoundedImageBase::bottomLeftRadius() const { return cornerRadius(BottomLeft); }
void RoundedImageBase::setBottomLeftRadius(qreal r) { setCornerRadius(BottomLeft, qMax(r, 0.0)); }
void RoundedImageBase::resetBottomLeftRadius() { setCornerRadius(BottomLeft, -1); }

void RoundedImageBorder::setWidth(qreal width)
{
    width = qMax(width, 0.0);
    if (m_widthSet && m_width == width && m_valid)
        return;
    m_width = width;
    m_widthSet = true;
    m_set = true;
    validate();
    emit changed();
}

void RoundedImageBorder::setColor(const QColor& color)
{
    if (m_color == color && m_valid)
        return;
    m_color = color;
    m_set = true;
    validate();
    emit changed();
}

void RoundedImageBorder::setUnsetWidth(qreal width)
{
    if (m_unsetWidth == width)
        return;
    m_unsetWidth = width;
    if (m_widthSet)
        return;
    validate();
    emit changed();
}

// as QQuickPen's, pixel aligned
void RoundedImageBorder::validate()
{
    m_valid = m_set && m_color.alpha() > 0 && qRound(width()) >= 1;
}

RoundedImageBorder* RoundedImageBase::border()
{
    if (!m_border) {
        m_border = new RoundedImageBorder(m_item);
        m_border->setUnsetWidth(m_unsetBorderWidth);
        QObject::connect(m_border, &RoundedImageBorder::changed, m_item, &QQuickItem::update);
    }
    return m_border;
}

qreal RoundedImageBase::unsetBorderWidth() const
{
    return m_unsetBorderWidth;
}

void RoundedImageBase::setUnsetBorderWidth(qreal width)
{
    width = qMax(width, 0.0);
    if (m_unsetBorderWidth == width)
        return;
    m_unsetBorderWidth = width;
    if (m_border)
        m_border->setUnsetWidth(width);
    changed();
}

qreal RoundedImageBase::borderWidth() const
{
    return m_border ? m_border->width() : m_unsetBorderWidth;
}

bool RoundedImageBase::borderVisible() const
{
    return m_border && m_border->isValid();
}

QRectF RoundedImageBase::contentBox() const
{
    const qreal band = borderWidth();
    const qreal width = m_item->width();
    const qreal height = m_item->height();
    const qreal w = qMax(width - 2 * band, 0.0);
    const qreal h = qMax(height - 2 * band, 0.0);
    return QRectF((width - w) / 2, (height - h) / 2, w, h);
}

QColor RoundedImageBase::backgroundColor() const
{
    return m_backgroundColor;
}

void RoundedImageBase::setBackgroundColor(const QColor& color)
{
    if (m_backgroundColor == color)
        return;
    m_backgroundColor = color;
    changed();
}

QPointF RoundedImageBase::cutoutCenter() const
{
    return m_cutoutCenter;
}

void RoundedImageBase::setCutoutCenter(const QPointF& center)
{
    if (m_cutoutCenter == center)
        return;
    m_cutoutCenter = center;
    changed();
}

qreal RoundedImageBase::cutoutRadius() const
{
    return m_cutoutRadius;
}

void RoundedImageBase::setCutoutRadius(qreal radius)
{
    if (m_cutoutRadius == radius)
        return;
    m_cutoutRadius = radius;
    changed();
}

RoundedImageBase::Area RoundedImageBase::area() const
{
    return m_area;
}

void RoundedImageBase::setArea(Area area)
{
    if (m_area == area)
        return;
    m_area = area;
    changed();
}

QSGNode* RoundedImageBase::updateRoundedNode(QSGNode* oldNode,
                                             const std::function<QSGNode*(QSGNode*)>& plainNode)
{
    auto d = static_cast<QQuickImagePrivate*>(QQuickItemPrivate::get(m_item));
    QQuickWindow* window = m_item->window();

    const bool software = window
            && window->rendererInterface()->graphicsApi() == QSGRendererInterface::Software;

    auto node = dynamic_cast<RoundedImageNode*>(oldNode);
    if (software) {
        // the plain image node, unrounded
        if (node) {
            delete node;
            oldNode = nullptr;
        }
        return plainNode(oldNode);
    }
    if (oldNode && !node)
        delete oldNode;

    QSGTexture* texture = d->sceneGraphRenderContext()->textureForFactory(
                d->currentPix->textureFactory(), window);

    // keep the texture provider in step, for anything sampling this item
    if (d->provider) {
        d->provider->m_smooth = d->smooth;
        d->provider->m_mipmap = d->mipmap;
        d->provider->updateTexture(texture);
    }

    const qreal pixW = d->currentPix->width();
    const qreal pixH = d->currentPix->height();
    if (m_item->width() <= 0 || m_item->height() <= 0) {
        delete node;
        return nullptr;
    }
    // inside the border
    const QRectF box = contentBox();
    if (!texture || pixW <= 0 || pixH <= 0 || box.isEmpty())
        return updateBorderNode(node);
    const qreal boxW = box.width();
    const qreal boxH = box.height();

    // Laid out in the box as QQuickImage lays it out in the item: targetRect
    // in box coordinates, sourceRect in the units of nsWidth x nsHeight
    QRectF targetRect;
    QRectF sourceRect;
    QSGTexture::WrapMode hWrap = QSGTexture::ClampToEdge;
    QSGTexture::WrapMode vWrap = QSGTexture::ClampToEdge;

    qreal pixWidth = pixW / d->devicePixelRatio;
    qreal pixHeight = pixH / d->devicePixelRatio;
    if (d->fillMode == QQuickImage::PreserveAspectFit) {
        // the painted size, for the box rather than the item
        const qreal scale = qMin(boxW / pixWidth, boxH / pixHeight);
        pixWidth *= scale;
        pixHeight *= scale;
    }
    int xOffset = 0;
    if (d->hAlign == QQuickImage::AlignHCenter)
        xOffset = static_cast<int>((boxW - pixWidth) / 2);
    else if (d->hAlign == QQuickImage::AlignRight)
        xOffset = qCeil(boxW - pixWidth);
    int yOffset = 0;
    if (d->vAlign == QQuickImage::AlignVCenter)
        yOffset = static_cast<int>((boxH - pixHeight) / 2);
    else if (d->vAlign == QQuickImage::AlignBottom)
        yOffset = qCeil(boxH - pixHeight);

    switch (d->fillMode) {
    case QQuickImage::Stretch:
        targetRect = QRectF(0, 0, boxW, boxH);
        sourceRect = QRectF(0, 0, pixW, pixH);
        break;
    case QQuickImage::PreserveAspectFit:
        targetRect = QRectF(xOffset, yOffset, pixWidth, pixHeight);
        sourceRect = QRectF(0, 0, pixW, pixH);
        break;
    case QQuickImage::PreserveAspectCrop: {
        targetRect = QRectF(0, 0, boxW, boxH);
        const qreal wscale = boxW / pixW;
        const qreal hscale = boxH / pixH;
        if (wscale > hscale) {
            const int src = static_cast<int>((hscale / wscale) * pixH);
            int y = 0;
            if (d->vAlign == QQuickImage::AlignVCenter)
                y = qCeil((pixH - src) / 2.);
            else if (d->vAlign == QQuickImage::AlignBottom)
                y = qCeil(pixH - src);
            sourceRect = QRectF(0, y, pixW, src);
        } else {
            const int src = static_cast<int>((wscale / hscale) * pixW);
            int x = 0;
            if (d->hAlign == QQuickImage::AlignHCenter)
                x = qCeil((pixW - src) / 2.);
            else if (d->hAlign == QQuickImage::AlignRight)
                x = qCeil(pixW - src);
            sourceRect = QRectF(x, 0, src, pixH);
        }
        break;
    }
    case QQuickImage::Tile:
        targetRect = QRectF(0, 0, boxW, boxH);
        sourceRect = QRectF(-xOffset, -yOffset, boxW, boxH);
        hWrap = QSGTexture::Repeat;
        vWrap = QSGTexture::Repeat;
        break;
    case QQuickImage::TileHorizontally:
        targetRect = QRectF(0, 0, boxW, boxH);
        sourceRect = QRectF(-xOffset, 0, boxW, pixH);
        hWrap = QSGTexture::Repeat;
        break;
    case QQuickImage::TileVertically:
        targetRect = QRectF(0, 0, boxW, boxH);
        sourceRect = QRectF(0, -yOffset, pixW, boxH);
        vWrap = QSGTexture::Repeat;
        break;
    case QQuickImage::Pad: {
        const qreal w = qMin(pixWidth, boxW);
        const qreal h = qMin(pixHeight, boxH);
        const qreal x = pixWidth > boxW ? -xOffset : 0;
        const qreal y = pixHeight > boxH ? -yOffset : 0;
        targetRect = QRectF(x + xOffset, y + yOffset, w, h);
        sourceRect = QRectF(x, y, w, h);
        break;
    }
    }

    targetRect.translate(box.topLeft());

    const bool repeat = hWrap == QSGTexture::Repeat || vWrap == QSGTexture::Repeat;
    const qreal nsWidth = (hWrap == QSGTexture::Repeat || d->fillMode == QQuickImage::Pad)
            ? pixW / d->devicePixelRatio : pixW;
    const qreal nsHeight = (vWrap == QSGTexture::Repeat || d->fillMode == QQuickImage::Pad)
            ? pixH / d->devicePixelRatio : pixH;
    const QRectF nsRect(sourceRect.x() / nsWidth, sourceRect.y() / nsHeight,
                        sourceRect.width() / nsWidth, sourceRect.height() / nsHeight);

    if (targetRect.isEmpty() || !std::isfinite(targetRect.width())
            || !std::isfinite(targetRect.height()) || nsRect.isEmpty()
            || !std::isfinite(nsRect.width()) || !std::isfinite(nsRect.height())) {
        return updateBorderNode(node);
    }

    node = nodeOfKind(node, true);
    RoundedImageMaterial* material = node->roundedMaterial();
    // a new node has no texture yet
    if (d->pixmapChanged || !material->texture || repeat != material->repeat) {
        // a piece of an atlas can be neither repeated nor mipmapped
        if (texture->isAtlasTexture() && (repeat || d->mipmap))
            texture = texture->removedFromAtlas();
        material->texture = texture;
        material->repeat = repeat;
        d->pixmapChanged = false;
    }
    texture = material->texture;
    material->filtering = d->smooth ? QSGTexture::Linear : QSGTexture::Nearest;
    material->mipmapFiltering = d->mipmap ? QSGTexture::Linear : QSGTexture::None;
    material->hWrap = hWrap;
    material->vWrap = vWrap;

    // into the atlas; a repeated texture is never atlased. Mirroring flips
    // the texture over the painted rect, as QSGImageNode::setMirror does.
    const QRectF sub = texture->normalizedTextureSubRect();
    qreal u0 = sub.x() + nsRect.left() * sub.width();
    qreal u1 = sub.x() + nsRect.right() * sub.width();
    qreal v0 = sub.y() + nsRect.top() * sub.height();
    qreal v1 = sub.y() + nsRect.bottom() * sub.height();
    if (d->mirrorHorizontally)
        std::swap(u0, u1);
    if (d->mirrorVertically)
        std::swap(v0, v1);

    // the rounded shape within the border: what is painted, or the box
    const QRectF shape = m_area == ItemArea ? box : targetRect;
    writeVertices(node->roundedGeometry(), shape, targetRect,
                  QRectF(u0, v0, u1 - u0, v1 - v0));
    node->markDirty(QSGNode::DirtyGeometry | QSGNode::DirtyMaterial);
    return node;
}

QSGNode* RoundedImageBase::updateBorderNode(QSGNode* oldNode)
{
    auto node = static_cast<RoundedImageNode*>(oldNode);
    if (!borderVisible() && m_backgroundColor.alpha() == 0) {
        delete node;
        return nullptr;
    }
    node = nodeOfKind(node, false);

    // nothing painted: the box, within the border
    writeVertices(node->roundedGeometry(), contentBox(), {}, {});
    node->markDirty(QSGNode::DirtyGeometry | QSGNode::DirtyMaterial);
    return node;
}

void RoundedImageBase::writeVertices(QSGGeometry* geometry, const QRectF& area,
                                     const QRectF& painted, const QRectF& uv) const
{
    // an unset border's band: part of the shape, the background's
    const bool visible = borderVisible();
    const qreal band = borderWidth();
    const QRectF outer = area.adjusted(-band, -band, band, band);
    const QRectF shape = visible ? area : outer;
    const qreal border = visible ? band : 0;
    const auto halfW = static_cast<float>(shape.width() / 2);
    const auto halfH = static_cast<float>(shape.height() / 2);
    const qreal maxRadius = qMin(outer.width(), outer.height()) / 2;
    const QPointF centre = shape.center();
    const auto radius = [this, maxRadius](Corner corner) {
        return static_cast<float>(qBound(0.0, cornerRadius(corner), maxRadius));
    };
    const std::array<float, 4> radii{ radius(TopLeft), radius(TopRight), radius(BottomRight),
                                      radius(BottomLeft) };
    const auto premultiplied = [](const QColor& c) {
        const float a = c.alphaF();
        return Color{ c.redF() * a, c.greenF() * a, c.blueF() * a, a };
    };
    const Color borderColor = premultiplied(visible ? m_border->color()
                                                    : QColor(Qt::transparent));
    const Color backgroundColor = premultiplied(m_backgroundColor);
    const QPointF cutout = m_cutoutCenter - centre;

    // the painted image, grown to the border and the background
    QRectF quad = painted;
    if (visible || m_backgroundColor.alpha() > 0)
        quad = painted.isEmpty() ? outer : painted.united(outer);

    Vertex* const vertices = static_cast<Vertex*>(geometry->vertexData());
    const std::array<QPointF, 4> corners{ quad.topLeft(), quad.topRight(), quad.bottomLeft(),
                                          quad.bottomRight() };
    for (std::size_t i = 0; i < corners.size(); ++i) {
        const QPointF corner = corners[i];
        // across the painted rect, extrapolated over the rest
        const qreal px = painted.isEmpty() ? 0 : (corner.x() - painted.x()) / painted.width();
        const qreal py = painted.isEmpty() ? 0 : (corner.y() - painted.y()) / painted.height();
        Vertex& v = vertices[i];
        v.x = static_cast<float>(corner.x());
        v.y = static_cast<float>(corner.y());
        v.u = static_cast<float>(uv.x() + px * uv.width());
        v.v = static_cast<float>(uv.y() + py * uv.height());
        v.paintedX = static_cast<float>(px);
        v.paintedY = static_cast<float>(py);
        v.localX = static_cast<float>(corner.x() - centre.x());
        v.localY = static_cast<float>(corner.y() - centre.y());
        v.halfW = halfW;
        v.halfH = halfH;
        v.radii = radii;
        v.cutoutX = static_cast<float>(cutout.x());
        v.cutoutY = static_cast<float>(cutout.y());
        v.cutoutRadius = static_cast<float>(m_cutoutRadius);
        v.borderWidth = static_cast<float>(border);
        v.borderColor = borderColor;
        v.backgroundColor = backgroundColor;
    }
}
