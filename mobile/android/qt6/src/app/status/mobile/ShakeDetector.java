package app.status.mobile;

import android.app.Activity;
import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.SystemClock;
import android.util.Log;

import java.util.concurrent.atomic.AtomicBoolean;

public final class ShakeDetector {
    private static final String TAG = "StatusShake";
    private static final AtomicBoolean started = new AtomicBoolean(false);
    private static final AtomicBoolean registered = new AtomicBoolean(false);
    private static SensorManager sensorManager;
    private static Sensor accelerometer;
    private static long lastShakeMs = 0L;

    // Threshold and cooldown tuned to match iOS behavior.
    private static final float SHAKE_THRESHOLD = 1.35f; // delta from 1g
    private static final long COOLDOWN_MS = 1000;

    private static final SensorEventListener listener = new SensorEventListener() {
        @Override
        public void onSensorChanged(SensorEvent event) {
            if (event == null || event.values == null || event.values.length < 3) return;

            float ax = event.values[0];
            float ay = event.values[1];
            float az = event.values[2];

            float g = (float) Math.sqrt(ax * ax + ay * ay + az * az) / SensorManager.GRAVITY_EARTH;
            float deltaFrom1g = Math.abs(g - 1.0f);

            if (deltaFrom1g < SHAKE_THRESHOLD) return;

            long now = SystemClock.elapsedRealtime();
            if (now - lastShakeMs < COOLDOWN_MS) return;

            lastShakeMs = now;
            Log.i(TAG, "detected: g=" + g + " deltaFrom1g=" + deltaFrom1g);
            nativeShakeDetected();
        }

        @Override
        public void onAccuracyChanged(Sensor sensor, int accuracy) {
            // no-op
        }
    };

    private ShakeDetector() {}

    public static void start(Activity activity) {
        if (activity == null) return;

        if (!started.compareAndSet(false, true)) {
            onResume(activity);
            return;
        }

        Context appContext = activity.getApplicationContext();
        sensorManager = (SensorManager) appContext.getSystemService(Context.SENSOR_SERVICE);
        if (sensorManager == null) {
            Log.w(TAG, "SensorManager unavailable");
            return;
        }

        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
        if (accelerometer == null) {
            Log.w(TAG, "Accelerometer not available");
            return;
        }

        onResume(activity);
    }

    public static void onResume(Activity activity) {
        if (sensorManager == null || accelerometer == null) {
            if (activity != null) {
                start(activity);
            }
            return;
        }
        if (registered.compareAndSet(false, true)) {
            sensorManager.registerListener(listener, accelerometer, SensorManager.SENSOR_DELAY_GAME);
        }
    }

    public static void onPause() {
        if (sensorManager == null || accelerometer == null) return;
        if (registered.compareAndSet(true, false)) {
            sensorManager.unregisterListener(listener, accelerometer);
        }
    }

    private static native void nativeShakeDetected();
}
