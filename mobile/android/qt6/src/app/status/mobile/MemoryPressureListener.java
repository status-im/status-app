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
                notifyMemoryPressure(true);
            }

            // BACKGROUND only says the app went to the background (since API
            // 34 it is all that is sent, besides UI_HIDDEN, which is ignored);
            // the other levels are real pressure, sent before API 34.
            @Override
            public void onTrimMemory(int level) {
                switch (level) {
                case TRIM_MEMORY_BACKGROUND:
                    Log.i(TAG, "onTrimMemory: background");
                    notifyMemoryPressure(false);
                    break;
                case TRIM_MEMORY_RUNNING_LOW:
                case TRIM_MEMORY_RUNNING_CRITICAL:
                case TRIM_MEMORY_MODERATE:
                case TRIM_MEMORY_COMPLETE:
                    Log.i(TAG, "onTrimMemory: memory pressure, level " + level);
                    notifyMemoryPressure(true);
                    break;
                default:
                    break;
                }
            }
        });
    }

    private static void notifyMemoryPressure(boolean critical) {
        try {
            nativeOnMemoryPressure(critical);
        } catch (UnsatisfiedLinkError e) {
            Log.w(TAG, "nativeOnMemoryPressure not yet registered", e);
        }
    }

    private static native void nativeOnMemoryPressure(boolean critical);
}
