package app.status.mobile;

import android.app.Activity;
import android.content.ComponentCallbacks;
import android.content.res.Configuration;
import android.util.DisplayMetrics;
import android.util.Log;

import java.util.concurrent.atomic.AtomicBoolean;

public final class DensityListener {
    private static final String TAG = "StatusDensityListener";
    private static final AtomicBoolean started = new AtomicBoolean(false);
    private static float lastDensity = -1.0f;

    private DensityListener() {}

    public static void start(Activity activity) {
        if (activity == null) return;

        if (!started.compareAndSet(false, true)) {
            return;
        }

        try {
            DisplayMetrics initialMetrics = activity.getResources().getDisplayMetrics();
            if (initialMetrics != null) {
                lastDensity = initialMetrics.density;
            }
        } catch (Throwable t) {
            Log.w(TAG, "Failed to get initial display metrics", t);
        }

        final android.content.res.Resources resources = activity.getApplication().getResources();
        activity.getApplication().registerComponentCallbacks(new ComponentCallbacks() {
            @Override
            public void onConfigurationChanged(Configuration newConfig) {
                try {
                    DisplayMetrics metrics = resources.getDisplayMetrics();
                    if (metrics != null) {
                        float currentDensity = metrics.density;
                        if (lastDensity < 0 || Math.abs(currentDensity - lastDensity) > 0.0001f) {
                            lastDensity = currentDensity;
                            Log.i(TAG, "onConfigurationChanged: density changed to " + currentDensity);
                            try {
                                nativeOnDensityChanged(currentDensity);
                            } catch (UnsatisfiedLinkError e) {
                                Log.w(TAG, "nativeOnDensityChanged not yet registered", e);
                            }
                        }
                    }
                } catch (Throwable t) {
                    Log.w(TAG, "Error handling onConfigurationChanged", t);
                }
            }

            @Override
            public void onLowMemory() {
                // no-op
            }
        });
    }

    private static native void nativeOnDensityChanged(float density);
}
