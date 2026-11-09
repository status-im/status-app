#pragma once

#include <QMetaObject>
#include <QSGGeometryNode>

class QQuickWindow;

// Milliseconds on one clock for the GUI and render threads.
qint64 sceneGraphClockMs();

// An item-sized quad whose material animates in preprocess() and which asks
// for its own next frame. Before that frame renders it marks itself dirty
// again, as a layer it is in does not see changes made while it renders.
class AnimatedQuadNode : public QSGGeometryNode
{
public:
    explicit AnimatedQuadNode(QSGMaterial* material);
    ~AnimatedQuadNode() override;

protected:
    // during sync
    void setWindow(QQuickWindow* window);
    void setSize(const QSizeF& size);

    // from preprocess(): at once from the render thread, at most every 16 ms
    // when the scene graph renders on the GUI thread
    void requestNextFrame();

private:
    QQuickWindow* m_window = nullptr;
    QMetaObject::Connection m_beforeRendering;
    bool m_nextFrameRequested = false;
};
