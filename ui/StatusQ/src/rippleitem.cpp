#include "StatusQ/rippleitem.h"

#include "scenegraphanimation.h"

#include <QEasingCurve>
#include <QQuickWindow>
#include <QSGGeometryNode>
#include <QSGMaterial>
#include <QSGMaterialShader>

#include <cstring>

qreal RippleTimeline::radiusAt(qint64 time) const
{
    if (pressTime < 0)
        return 0;

    if (releaseTime < 0 || time < collapseStart()) {
        if (time >= expandEnd())
            return endRadius;
        static const QEasingCurve expandEasing(QEasingCurve::OutCubic);
        return endRadius * expandEasing.valueForProgress(qreal(time - pressTime) / expandDuration);
    }

    if (time >= collapseEnd())
        return 0;
    static const QEasingCurve collapseEasing(QEasingCurve::InOutQuad);
    return endRadius
           * (1 - collapseEasing.valueForProgress(qreal(time - collapseStart()) / collapseDuration));
}

bool RippleTimeline::settledAt(qint64 time) const
{
    if (pressTime < 0)
        return true;
    return releaseTime < 0 ? time >= expandEnd() : time >= collapseEnd();
}

namespace {

class RippleMaterial : public QSGMaterial
{
public:
    RippleMaterial()
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

    QSizeF itemSize;
    float radius = 0;
    QPointF centre;
    float rippleRadius = 0;
    QColor color;
};

class RippleShader : public QSGMaterialShader
{
public:
    RippleShader()
    {
        setShaderFileName(VertexStage, QStringLiteral(":/StatusQ/shaders/ripple.vert.qsb"));
        setShaderFileName(FragmentStage, QStringLiteral(":/StatusQ/shaders/ripple.frag.qsb"));
    }

    // offsets follow the std140 layout of the uniform block in ripple.frag
    bool updateUniformData(RenderState& state, QSGMaterial* newMaterial, QSGMaterial*) override
    {
        const auto* m = static_cast<RippleMaterial*>(newMaterial);
        char* buf = state.uniformData()->data();

        const auto writeFloat = [buf](int offset, float value) {
            std::memcpy(buf + offset, &value, sizeof(value));
        };

        std::memcpy(buf, state.combinedMatrix().constData(), 64);
        writeFloat(64, state.opacity());
        writeFloat(72, m->itemSize.width());
        writeFloat(76, m->itemSize.height());
        writeFloat(80, m->radius);
        writeFloat(88, m->centre.x());
        writeFloat(92, m->centre.y());
        writeFloat(96, m->rippleRadius);

        const float a = m->color.alphaF();
        const float rgba[4] = {m->color.redF() * a, m->color.greenF() * a, m->color.blueF() * a, a};
        std::memcpy(buf + 112, rgba, sizeof(rgba));
        return true;
    }
};

QSGMaterialShader* RippleMaterial::createShader(QSGRendererInterface::RenderMode) const
{
    return new RippleShader;
}

class RippleNode : public QSGGeometryNode
{
public:
    RippleNode()
    {
        auto geometry = new QSGGeometry(QSGGeometry::defaultAttributes_TexturedPoint2D(), 4);
        setGeometry(geometry);
        setMaterial(new RippleMaterial);
        setFlags(OwnsGeometry | OwnsMaterial | UsePreprocess);
    }

    // called on the render thread while the GUI thread is blocked
    void sync(const RippleItem* item)
    {
        m_window = item->window();
        m_timeline = item->timeline();

        const QSizeF size = item->size();
        QSGGeometry::updateTexturedRectGeometry(geometry(), QRectF(QPointF(0, 0), size), QRectF(0, 0, 1, 1));
        markDirty(DirtyGeometry);

        auto* m = static_cast<RippleMaterial*>(material());
        m->itemSize = size;
        m->radius = std::clamp(item->radius(), 0.0, std::min(size.width(), size.height()) / 2);
        m->centre = item->centre();
        m->color = item->color();
        markDirty(DirtyMaterial);
    }

    // Runs once per frame only while the node is in the rendered scene, so a
    // hidden or removed ripple stops requesting frames by itself.
    void preprocess() override
    {
        const qint64 now = sceneGraphClockMs();
        static_cast<RippleMaterial*>(material())->rippleRadius = m_timeline.radiusAt(now);
        markDirty(DirtyMaterial);

        if (m_window && !m_timeline.settledAt(now))
            requestNextFrame(m_window);
    }

private:
    QQuickWindow* m_window = nullptr;
    RippleTimeline m_timeline;
};

} // namespace

RippleItem::RippleItem(QQuickItem* parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents);
    m_settleTimer.setSingleShot(true);
    connect(&m_settleTimer, &QTimer::timeout, this, &RippleItem::settle);
}

void RippleItem::setColor(const QColor& color)
{
    if (m_color == color)
        return;
    m_color = color;
    update();
    emit colorChanged();
}

void RippleItem::setRadius(qreal radius)
{
    if (qFuzzyCompare(m_radius, radius))
        return;
    m_radius = radius;
    update();
    emit radiusChanged();
}

void RippleItem::setCentre(const QPointF& centre)
{
    if (m_centre == centre)
        return;
    m_centre = centre;
    update();
    emit centreChanged();
}

void RippleItem::setEndRadius(qreal radius)
{
    if (qFuzzyCompare(m_timeline.endRadius, radius))
        return;
    m_timeline.endRadius = radius;
    if (m_rippleRadius > 0)
        setRippleRadius(radius);
    update();
    emit endRadiusChanged();
}

void RippleItem::setExpandDuration(int duration)
{
    if (m_timeline.expandDuration == duration)
        return;
    m_timeline.expandDuration = duration;
    settle();
    update();
    emit expandDurationChanged();
}

void RippleItem::setCollapseDuration(int duration)
{
    if (m_timeline.collapseDuration == duration)
        return;
    m_timeline.collapseDuration = duration;
    settle();
    update();
    emit collapseDurationChanged();
}

void RippleItem::press()
{
    m_timeline.pressTime = sceneGraphClockMs();
    m_timeline.releaseTime = -1;
    setRippleRadius(0);
    setActive(true);
    settle();
    update();
}

void RippleItem::release()
{
    if (m_timeline.pressTime < 0 || m_timeline.releaseTime >= 0)
        return;
    m_timeline.releaseTime = sceneGraphClockMs();
    settle();
    update();
}

// Brings the item's state to where the timeline is now and waits for its
// next step.
void RippleItem::settle()
{
    m_settleTimer.stop();
    if (m_timeline.pressTime < 0)
        return;

    const qint64 now = sceneGraphClockMs();
    if (now < m_timeline.expandEnd()) {
        m_settleTimer.start(int(m_timeline.expandEnd() - now));
        return;
    }
    if (m_timeline.releaseTime < 0) {
        setRippleRadius(m_timeline.endRadius);
        return;
    }
    if (now < m_timeline.collapseEnd()) {
        setRippleRadius(m_timeline.endRadius);
        m_settleTimer.start(int(m_timeline.collapseEnd() - now));
        return;
    }

    m_timeline.pressTime = -1;
    m_timeline.releaseTime = -1;
    setRippleRadius(0);
    setActive(false);
    update();
}

void RippleItem::setActive(bool active)
{
    if (m_active == active)
        return;
    m_active = active;
    emit activeChanged();
}

void RippleItem::setRippleRadius(qreal radius)
{
    if (qFuzzyCompare(m_rippleRadius, radius))
        return;
    m_rippleRadius = radius;
    emit rippleRadiusChanged();
}

QSGNode* RippleItem::updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*)
{
    auto* node = static_cast<RippleNode*>(oldNode);

    if (!m_active || width() <= 0 || height() <= 0) {
        delete node;
        return nullptr;
    }

    if (!node)
        node = new RippleNode;

    node->sync(this);
    return node;
}
