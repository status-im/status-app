package app.status.mobile;

import android.app.Activity;
import android.graphics.Rect;
import android.os.Build;
import android.view.MotionEvent;
import android.view.VelocityTracker;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewConfiguration;
import android.widget.FrameLayout;
import java.util.Collections;

public class NativeSwipeHandlerHelper {
    private final long nativePtr;
    private final Activity activity;
    private View touchOverlayView;

    // Track in screen coordinates so moving the overlay view during the gesture doesn't distort deltas.
    private float startRawX = 0.0f;
    private float lastRawX = 0.0f;
    private long lastEventTimeMs = 0;
    private float lastVx = 0.0f;
    private boolean active = false;
    private int activePointerId = -1;
    // VelocityTracker uses view-local coords; we compute velocity from rawX instead.
    private VelocityTracker velocityTracker;
    private boolean swiping = false;
    private int touchSlopPx = 0;
    private View passthroughTarget;

    // Handler rect in parent pixels (contentView coordinates).
    private float handlerX = 0.0f;
    private float handlerY = 0.0f;
    private float handlerWidth = 20.0f;
    private float handlerHeight = 20.0f;

    private static native void nativeOnSwipeBegan(long ptr, float velocityX);
    private static native void nativeOnSwipeChanged(long ptr, float deltaX, float velocityX);
    private static native void nativeOnSwipeEnded(long ptr, float deltaX, float velocityX, boolean canceled);

    public NativeSwipeHandlerHelper(long ptr, Activity activity) {
        this.nativePtr = ptr;
        this.activity = activity;
        this.touchSlopPx = ViewConfiguration.get(activity).getScaledTouchSlop();

        createTouchOverlay();
    }

    private void createTouchOverlay() {
        activity.runOnUiThread(() -> {
            touchOverlayView = new View(activity);
            touchOverlayView.setBackgroundColor(0x00000000);

            ViewGroup contentView = (ViewGroup) activity.getWindow().getDecorView().findViewById(android.R.id.content);
            if (contentView == null)
                return;

            FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                (int) Math.max(1, handlerWidth),
                (int) Math.max(1, handlerHeight)
            );
            touchOverlayView.setLayoutParams(params);
            touchOverlayView.setX(handlerX);
            touchOverlayView.setY(handlerY);
            touchOverlayView.setClickable(true);
            touchOverlayView.setLongClickable(false);

            touchOverlayView.setOnTouchListener((v, event) -> {
                final int action = event.getActionMasked();

                if (action == MotionEvent.ACTION_DOWN) {
                    // The overlay view is sized/positioned to the swipe rect, so any DOWN here is in-bounds.
                    final float x = event.getX();
                    final float rawX = event.getRawX();

                    active = true;
                    swiping = false;
                    activePointerId = event.getPointerId(0);
                    startRawX = rawX;
                    lastRawX = rawX;
                    lastEventTimeMs = event.getEventTime();
                    lastVx = 0.0f;
                    passthroughTarget = findPassthroughTarget();

                    if (velocityTracker != null) {
                        velocityTracker.recycle();
                        velocityTracker = null;
                    }
                    velocityTracker = VelocityTracker.obtain();
                    velocityTracker.addMovement(event);

                    // Prevent parents from intercepting once we start.
                    if (touchOverlayView.getParent() instanceof ViewGroup) {
                        ((ViewGroup) touchOverlayView.getParent()).requestDisallowInterceptTouchEvent(true);
                    }

                    if (passthroughTarget != null) {
                        dispatchToTarget(passthroughTarget, event, MotionEvent.ACTION_DOWN);
                    }
                    return true;
                }

                if (!active) {
                    return false;
                }

                // Keep tracking even if the finger moves out of the original edge bounds.
                if (velocityTracker != null) {
                    velocityTracker.addMovement(event);
                    velocityTracker.computeCurrentVelocity(1000);
                }

                final int idx = activePointerId >= 0 ? event.findPointerIndex(activePointerId) : 0;
                final float x = idx >= 0 ? event.getX(idx) : event.getX();
                final float rawX = idx >= 0 ? event.getRawX(idx) : event.getRawX();
                final long t = event.getEventTime();
                final long dt = Math.max(1, t - lastEventTimeMs);
                final float vx = ((rawX - lastRawX) / (float) dt) * 1000.0f;
                lastRawX = rawX;
                lastEventTimeMs = t;

                if (action == MotionEvent.ACTION_MOVE) {
                    final float dx = rawX - startRawX;
                    lastVx = vx;
                    if (!swiping && Math.abs(dx) >= touchSlopPx) {
                        swiping = true;
                        if (passthroughTarget != null) {
                            dispatchToTarget(passthroughTarget, event, MotionEvent.ACTION_CANCEL);
                            passthroughTarget = null;
                        }
                        nativeOnSwipeBegan(nativePtr, vx);
                    }
                    if (swiping) {
                        nativeOnSwipeChanged(nativePtr, dx, vx);
                    } else if (passthroughTarget != null) {
                        dispatchToTarget(passthroughTarget, event, MotionEvent.ACTION_MOVE);
                    }
                    return true;
                }

                if (action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL) {
                    final float dx = rawX - startRawX;
                    // Use the last MOVE velocity; UP often has vx≈0 because there's no delta.
                    if (swiping) {
                        nativeOnSwipeEnded(nativePtr, dx, lastVx, action == MotionEvent.ACTION_CANCEL);
                    } else if (passthroughTarget != null) {
                        dispatchToTarget(passthroughTarget, event, action);
                    }

                    if (velocityTracker != null) {
                        velocityTracker.recycle();
                        velocityTracker = null;
                    }
                    active = false;
                    activePointerId = -1;
                    swiping = false;
                    passthroughTarget = null;
                    return true;
                }

                return true;
            });

            contentView.addView(touchOverlayView);
            updateGestureExclusion();
        });
    }

    public void updateTouchOverlayBounds(float xPx, float yPx, float widthPx, float heightPx) {
        handlerX = xPx;
        handlerY = yPx;
        handlerWidth = widthPx;
        handlerHeight = heightPx;

        if (activity != null) {
            activity.runOnUiThread(() -> {
                if (touchOverlayView == null) return;
                // Re-attach if rotation/activity changes detached the view.
                if (touchOverlayView.getParent() == null) {
                    ViewGroup contentView = (ViewGroup) activity.getWindow().getDecorView().findViewById(android.R.id.content);
                    if (contentView != null) {
                        contentView.addView(touchOverlayView);
                    }
                }

                ViewGroup.LayoutParams lp = touchOverlayView.getLayoutParams();
                if (lp != null) {
                    lp.width = (int) Math.max(1, handlerWidth);
                    lp.height = (int) Math.max(1, handlerHeight);
                    touchOverlayView.setLayoutParams(lp);
                }
                touchOverlayView.setX(handlerX);
                touchOverlayView.setY(handlerY);
                updateGestureExclusion();
            });
        }
    }

    private void updateGestureExclusion() {
        if (touchOverlayView == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q)
            return;

        int w = (int) Math.max(1, handlerWidth);
        int h = (int) Math.max(1, handlerHeight);
        Rect exclusion = new Rect(0, 0, w, h);
        touchOverlayView.setSystemGestureExclusionRects(Collections.singletonList(exclusion));
    }

    private View findPassthroughTarget() {
        if (activity == null) return null;
        ViewGroup contentView = (ViewGroup) activity.getWindow().getDecorView().findViewById(android.R.id.content);
        if (contentView == null) return null;
        View qtView = findQtView(contentView);
        if (qtView != null) return qtView;
        for (int i = contentView.getChildCount() - 1; i >= 0; i--) {
            View child = contentView.getChildAt(i);
            if (child != null && child != touchOverlayView && child.getVisibility() == View.VISIBLE) {
                return child;
            }
        }
        return null;
    }

    private View findQtView(View root) {
        if (root == null || root == touchOverlayView) return null;
        String name = root.getClass().getName();
        if (name.startsWith("org.qtproject.qt.android")) {
            return root;
        }
        if (root instanceof ViewGroup) {
            ViewGroup vg = (ViewGroup) root;
            for (int i = vg.getChildCount() - 1; i >= 0; i--) {
                View match = findQtView(vg.getChildAt(i));
                if (match != null) return match;
            }
        }
        return null;
    }

    private void dispatchToTarget(View target, MotionEvent src, int action) {
        if (target == null) return;
        int[] loc = new int[2];
        target.getLocationOnScreen(loc);
        float localX = src.getRawX() - loc[0];
        float localY = src.getRawY() - loc[1];
        MotionEvent ev = MotionEvent.obtain(src);
        ev.setLocation(localX, localY);
        ev.setAction(action);
        ev.setSource(src.getSource());
        target.dispatchTouchEvent(ev);
        ev.recycle();
    }

    public void cleanup() {
        if (activity == null) return;
        activity.runOnUiThread(() -> {
            if (touchOverlayView != null) {
                ViewGroup parent = (ViewGroup) touchOverlayView.getParent();
                if (parent != null) parent.removeView(touchOverlayView);
                touchOverlayView = null;
            }

            if (velocityTracker != null) {
                velocityTracker.recycle();
                velocityTracker = null;
            }
            active = false;
            activePointerId = -1;
        });
    }
}


