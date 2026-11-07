package app.status.mobile;

import android.app.Activity;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.PorterDuff;
import android.graphics.Rect;
import android.system.Os;
import android.util.Log;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.TextureView;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewTreeObserver;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.WebView;

import java.util.ArrayList;
import java.util.List;

/**
 * Qt renders into its own SurfaceView below the activity window, so the window itself only shows
 * a background and the SurfaceView hole. With HWUI that still costs four full-screen buffers and a
 * Skia device. The activity takes the window surface instead ({@link Window#takeSurface}):
 * ViewRootImpl then never creates a renderer, and the window gets one transparent software frame
 * so SurfaceFlinger has input bounds for it.
 *
 * Views in the window are not drawn while the surface is taken. The first time a WebView or
 * TextureView becomes visible the window is re-added with HWUI (one way); the swipe indicator
 * lives in its own panel until then ({@link NativeIndicatorHelper}).
 *
 * Profiling builds can keep the plain HWUI window with STATUS_WINDOW_MODE=hw in status-env.txt.
 */
final class WindowSurfaceMode {
    private static final String TAG = "StatusWindow";

    interface Listener {
        void beforeWindowReadd();
        void afterWindowReadd();
    }

    private static boolean sTaken = false;
    private static final List<Listener> sListeners = new ArrayList<>();

    // SurfaceFlinger takes a window's input frame from its buffer: a window that never queued a
    // buffer gets an empty touchable region. So the taken surface gets one transparent software
    // frame per surface and size (one linear buffer), and nothing after that.
    private static final SurfaceHolder.Callback2 ONE_CLEAR_FRAME = new SurfaceHolder.Callback2() {
        private Surface mCleared;
        private int mClearedW = -1, mClearedH = -1;

        @Override public void surfaceCreated(SurfaceHolder holder) { mCleared = null; }
        @Override public void surfaceChanged(SurfaceHolder holder, int format, int w, int h) {}
        @Override public void surfaceDestroyed(SurfaceHolder holder) { mCleared = null; }

        @Override
        public void surfaceRedrawNeeded(SurfaceHolder holder) {
            final Rect frame = holder.getSurfaceFrame();
            final Surface surface = holder.getSurface();
            if (surface == null || !surface.isValid()) return;
            if (surface == mCleared && frame.width() == mClearedW && frame.height() == mClearedH) return;
            final Canvas canvas;
            try {
                canvas = holder.lockCanvas();
            } catch (RuntimeException e) {
                Log.w(TAG, "lockCanvas failed", e);
                return;
            }
            if (canvas == null) return;
            canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR);
            holder.unlockCanvasAndPost(canvas);
            mCleared = surface;
            mClearedW = frame.width();
            mClearedH = frame.height();
        }
    };

    private WindowSurfaceMode() {}

    /** Before super.onCreate(): the window is not attached yet. */
    static void beforeCreate(Activity activity) {
        if (BuildFlags.PROFILING && "hw".equals(Os.getenv("STATUS_WINDOW_MODE"))) return;
        final Window window = activity.getWindow();
        // The SurfaceView sits below the window: the cleared frame must be transparent.
        window.setFormat(PixelFormat.TRANSLUCENT);
        window.takeSurface(ONE_CLEAR_FRAME);
        sTaken = true;
    }

    /** After super.onCreate(): Qt has set the content view. */
    static void afterCreate(Activity activity) {
        if (!sTaken) return;
        final View decor = activity.getWindow().getDecorView();
        decor.getViewTreeObserver().addOnGlobalLayoutListener(new ViewTreeObserver.OnGlobalLayoutListener() {
            @Override
            public void onGlobalLayout() {
                if (!sTaken) {
                    decor.getViewTreeObserver().removeOnGlobalLayoutListener(this);
                    return;
                }
                final View needs = findViewNeedingWindowDraw(decor);
                if (needs == null) return;
                Log.i(TAG, "window drawn by HWUI from now on, for " + needs.getClass().getName());
                decor.post(() -> drawViews(activity));
            }
        });
    }

    /** True when ViewRootImpl draws the views of the activity window. */
    static boolean mainWindowDrawsViews() {
        return !sTaken;
    }

    static void addListener(Listener l) { sListeners.add(l); }
    static void removeListener(Listener l) { sListeners.remove(l); }

    private static View findViewNeedingWindowDraw(View v) {
        if (v.getVisibility() != View.VISIBLE) return null;
        if (v instanceof WebView || v instanceof TextureView) return v;
        if (v instanceof ViewGroup) {
            final ViewGroup g = (ViewGroup) v;
            for (int i = 0; i < g.getChildCount(); i++) {
                final View found = findViewNeedingWindowDraw(g.getChildAt(i));
                if (found != null) return found;
            }
        }
        return null;
    }

    // ViewRootImpl picks its renderer only in setView(), so the window is re-added. Qt sees the
    // same surface loss and re-creation as on a background/foreground cycle.
    private static void drawViews(Activity activity) {
        if (!sTaken || activity.isFinishing() || activity.isDestroyed()) return;
        final Window window = activity.getWindow();
        final View decor = window.getDecorView();
        if (decor.getParent() == null) return;
        sTaken = false;
        for (Listener l : new ArrayList<>(sListeners)) l.beforeWindowReadd();
        final WindowManager wm = activity.getWindowManager();
        wm.removeViewImmediate(decor);
        window.takeSurface(null);
        wm.addView(decor, window.getAttributes());
        for (Listener l : new ArrayList<>(sListeners)) l.afterWindowReadd();
    }
}
