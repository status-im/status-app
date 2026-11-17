package app.status.mobile;

import android.app.Activity;
import android.content.ComponentCallbacks2;
import android.content.res.Configuration;
import android.util.Log;

import java.util.concurrent.atomic.AtomicBoolean;

public final class MemoryPressureListener {
    private static final String TAG = "StatusMemoryPressure";
    private static final AtomicBoolean started = new AtomicBoolean(false);

    private MemoryPressureListener() {}

    public static void start(Activity activity) {
        if (activity == null) return;

        if (!started.compareAndSet(false, true)) {
            return;
        }

        activity.getApplication().registerComponentCallbacks(new ComponentCallbacks2() {
            @Override
            public void onConfigurationChanged(Configuration newConfig) {
                // no-op
            }

            @Override
            public void onLowMemory() {
                notifyMemoryPressure();
            }

            // UI_HIDDEN only says the UI went to the background.
            @Override
            public void onTrimMemory(int level) {
                if (level >= TRIM_MEMORY_RUNNING_LOW && level != TRIM_MEMORY_UI_HIDDEN) {
                    Log.i(TAG, "onTrimMemory: memory pressure, level " + level);
                    notifyMemoryPressure();
                }
            }
        });
    }

    private static void notifyMemoryPressure() {
        try {
            nativeOnMemoryPressure();
        } catch (UnsatisfiedLinkError e) {
            Log.w(TAG, "nativeOnMemoryPressure not yet registered", e);
        }
    }

    private static native void nativeOnMemoryPressure();
}
