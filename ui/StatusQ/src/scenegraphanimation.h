#pragma once

#include <QtGlobal>

class QQuickWindow;

// Milliseconds on one clock for the GUI and render threads.
qint64 sceneGraphClockMs();

// For QSGNode::preprocess(): asks for the next frame, at once from the render
// thread, at most every 16 ms when the scene graph renders on the GUI thread.
void requestNextFrame(QQuickWindow* window);
