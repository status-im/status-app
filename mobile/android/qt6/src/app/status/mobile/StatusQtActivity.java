package app.status.mobile;

import org.qtproject.qt.android.bindings.QtActivity;
import android.os.Build;
import android.os.Bundle;
import android.content.pm.PackageManager;
import androidx.core.splashscreen.SplashScreen;
import java.util.concurrent.atomic.AtomicBoolean;
import android.content.Intent;
import android.content.Context;
import android.net.Uri;
import android.provider.Settings;
import im.status.mobileui.PushNotificationHelper;

import java.lang.ref.WeakReference;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;

public class StatusQtActivity extends QtActivity {
    private static final AtomicBoolean splashShouldHide = new AtomicBoolean(false);
    private static StatusQtActivity sInstance = null;

    private static final AtomicBoolean userLoggedIn = new AtomicBoolean(false);
    private static String savedDeepLink = null;

    // JNI hook: implemented in native code to forward deep links to Qt
    private static native void passDeepLinkToQt(String deepLink);

    @Override
    public void onCreate(Bundle savedInstanceState) {
        // Initialize the status-go UI stub bridge early.
        // (In the service-based architecture this forwards to the separate status-go process.)
        StatusGoStub.setContext(this);
        StatusGoStub.ensureInitialized(this);

        // IMPORTANT: call super.onCreate() after starting/binding the service.
        // QtActivity may start the Qt (Nim) side during super.onCreate(), and the Nim
        // onboarding resume check queries the service immediately on startup.
        super.onCreate(savedInstanceState);
        sInstance = this;
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) { // Android 12+
            SplashScreen splashScreen = SplashScreen.installSplashScreen(this);
            splashScreen.setKeepOnScreenCondition(() -> !splashShouldHide.get());
        }
        // Set up shake detection (used for share-on-shake)
        ShakeDetector.start(this);

        handleDeepLink(getIntent());
    }

    @Override
    protected void onStart() {
        super.onStart();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            Api34Helper.register(this);
            Api34Helper.triggerIfPending(this, "onStart");
        }
    }

    @Override
    protected void onStop() {
        super.onStop();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            Api34Helper.unregister(this);
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        ShakeDetector.onResume(this);
        // Inform the status-go service that UI is visible so it can suppress OS notifications.
        StatusGoStub.setUiVisible(true);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            Api34Helper.triggerIfPending(this, "onResume");
        }
    }

    @Override
    protected void onPause() {
        ShakeDetector.onPause();
        // Inform the status-go service that UI is no longer in foreground.
        StatusGoStub.setUiVisible(false);
        super.onPause();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        // Let Qt initialize its internal focus values first
        super.onWindowFocusChanged(hasFocus);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            Api34Helper.onFocusChanged(this, hasFocus);
        }
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleDeepLink(intent);
    }

    /**
     * Nested class to isolate API 34+ references.
     * Uses persistent states and window focus tracking to withstand system overlay environments.
     */
    private static class Api34Helper {
        private static android.app.Activity.ScreenCaptureCallback screenshotCallback;
        private static WeakReference<StatusQtActivity> activityRef;
        private static final Handler mainHandler = new Handler(Looper.getMainLooper());

        private static int recoveryAttempts = 0;
        private static final int MAX_ATTEMPTS = 15; // 15 attempts * 300ms = 4.5 seconds per wave

        // Persistent storage access ensures state data survives any background process cleanup
        private static boolean getPendingRecovery(Context context) {
            return context.getSharedPreferences("screenshot_recovery_prefs", Context.MODE_PRIVATE)
                          .getBoolean("pending_recovery", false);
        }

        private static void setPendingRecovery(Context context, boolean pending) {
            context.getSharedPreferences("screenshot_recovery_prefs", Context.MODE_PRIVATE)
                          .edit()
                          .putBoolean("pending_recovery", pending)
                          .apply();
        }

        static void register(final StatusQtActivity activity) {
            activityRef = new WeakReference<>(activity);

            try {
                if (screenshotCallback == null) {
                    screenshotCallback = new android.app.Activity.ScreenCaptureCallback() {
                        @Override
                        public void onScreenCaptured() {
                            StatusQtActivity act = (activityRef != null) ? activityRef.get() : null;
                            if (act == null || act.isFinishing() || act.isDestroyed()) {
                                return;
                            }

                            // Arm persistent recovery state and begin the initial wave
                            setPendingRecovery(act.getApplicationContext(), true);
                            startRecoveryWave();
                        }
                    };
                }
                activity.registerScreenCaptureCallback(activity.getMainExecutor(), screenshotCallback);

            } catch (SecurityException e) {
                android.util.Log.e("StatusQtActivity", "SecurityException: Missing DETECT_SCREEN_CAPTURE permission.", e);
            } catch (Throwable t) {
                android.util.Log.e("StatusQtActivity", "Failed to initialize screen capture hook.", t);
            }
        }

        /**
         * Intercepts standard lifecycle resume methods. If returning from the editor
         * with an un-resolved recovery state, this initializes a fresh wave.
         */
        static void triggerIfPending(StatusQtActivity activity, String source) {
            if (getPendingRecovery(activity.getApplicationContext())) {
                android.util.Log.i("StatusQtActivity", "Lifecycle milestone (" + source + ") met. Re-initializing wave.");
                startRecoveryWave();
            }
        }

        /**
         * Intercepts window focus returns to smash hidden flags loaded during panel closures.
         */
        static void onFocusChanged(StatusQtActivity activity, boolean hasFocus) {
            if (hasFocus && getPendingRecovery(activity.getApplicationContext())) {
                android.util.Log.i("StatusQtActivity", "Window focus regained. Launching enforcement wave.");
                startRecoveryWave();
            }
        }

        private static void startRecoveryWave() {
            recoveryAttempts = 0;
            mainHandler.removeCallbacks(recoveryRunnable);
            mainHandler.postDelayed(recoveryRunnable, 200);
        }

        /**
         * Sustained loop engine that strips immersive configurations and forces native layout recalculations.
         */
        private static final Runnable recoveryRunnable = new Runnable() {
            @Override
            public void run() {
                StatusQtActivity act = (activityRef != null) ? activityRef.get() : null;
                if (act == null || act.isFinishing() || act.isDestroyed()) {
                    return;
                }

                Context context = act.getApplicationContext();

                if (recoveryAttempts >= MAX_ATTEMPTS) {
                    // CRITICAL FIX: Only clear the flag if the wave finishes while the user is actively
                    // focusing on our window. If focus is absent, the flag remains armed indefinitely.
                    if (act.hasWindowFocus()) {
                        android.util.Log.i("StatusQtActivity", "Enforcement wave successfully finalized under focus.");
                        setPendingRecovery(context, false);
                    } else {
                        android.util.Log.w("StatusQtActivity", "Wave timed out in the background/overlay. Keeping flag armed.");
                    }
                    return;
                }

                if (act.getWindow() != null) {
                    // 1. Modern Layer: Force system bars visible and set behavior to default
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        WindowInsetsController controller = act.getWindow().getInsetsController();
                        if (controller != null) {
                            controller.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_DEFAULT);
                            controller.show(WindowInsets.Type.statusBars() | WindowInsets.Type.navigationBars());
                        }
                    }

                    // 2. Legacy Layer: Clear layout parameters from the window frame
                    act.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);

                    // 3. View Hierarchy Layer: Clean up hidden UI visibility variables on the DecorView
                    View decorView = act.getWindow().getDecorView();
                    if (decorView != null) {
                        int currentUiVisibility = decorView.getSystemUiVisibility();
                        int clearedFlags = currentUiVisibility & ~(
                            View.SYSTEM_UI_FLAG_FULLSCREEN |
                            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION |
                            View.SYSTEM_UI_FLAG_IMMERSIVE |
                            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        );
                        decorView.setSystemUiVisibility(clearedFlags);

                        // 4. Synchronization Pass: Force layout calculations back down into Qt's core engine
                        decorView.requestLayout();
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                            decorView.requestApplyInsets();
                        }
                    }
                }

                recoveryAttempts++;
                mainHandler.postDelayed(this, 300);
            }
        };

        static void unregister(StatusQtActivity activity) {
            try {
                mainHandler.removeCallbacks(recoveryRunnable);
                if (screenshotCallback != null) {
                    activity.unregisterScreenCaptureCallback(screenshotCallback);
                }
            } catch (Throwable t) {
                android.util.Log.e("StatusQtActivity", "Cleanup failed", t);
            } finally {
                activityRef = null;
            }
        }
    }

    @Override
    protected void onDestroy() {
        sInstance = null;
        super.onDestroy();
    }

    // Called from Qt via JNI when main window is visible
    public static void mainWindowReady() {
        splashShouldHide.set(true);
        userLoggedIn.set(true);
        if (savedDeepLink != null) {
            passDeepLinkToQt(savedDeepLink);
            savedDeepLink = null;
        }
    }

    private void handleDeepLink(Intent intent) {
        if (intent == null) return;
        String action = intent.getAction();
        Uri data = intent.getData();
        if (Intent.ACTION_VIEW.equals(action) && data != null) {
            if (!userLoggedIn.get()) {
                savedDeepLink = data.toString();
                return;
            }
            passDeepLinkToQt(data.toString());
        }
    }

    // Static method to open app settings
    public static void openAppSettings() {
        if (sInstance != null) {
            Intent intent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
            Uri uri = Uri.fromParts("package", sInstance.getPackageName(), null);
            intent.setData(uri);
            sInstance.startActivity(intent);
        }
    }
}
