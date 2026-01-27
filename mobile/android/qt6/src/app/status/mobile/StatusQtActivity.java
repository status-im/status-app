package app.status.mobile;

import org.qtproject.qt.android.bindings.QtActivity;
import android.os.Build;
import android.os.Bundle;
import android.content.pm.PackageManager;
import androidx.core.splashscreen.SplashScreen;
import java.util.concurrent.atomic.AtomicBoolean;
import android.content.Intent;
import android.net.Uri;
import android.provider.Settings;
import im.status.mobileui.PushNotificationHelper;

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
        
        if (Build.VERSION.SDK_INT >= 31) { // Android 12+
            SplashScreen splashScreen = SplashScreen.installSplashScreen(this);
            splashScreen.setKeepOnScreenCondition(() -> !splashShouldHide.get());
        }
        // Set up shake detection (used for share-on-shake)
        ShakeDetector.start(this);

        handleDeepLink(getIntent());
    }

    @Override
    protected void onResume() {
        super.onResume();
        ShakeDetector.onResume(this);
        // Inform the status-go service that UI is visible so it can suppress OS notifications.
        StatusGoStub.setUiVisible(true);
    }

    @Override
    protected void onPause() {
        ShakeDetector.onPause();
        // Inform the status-go service that UI is no longer in foreground.
        StatusGoStub.setUiVisible(false);
        super.onPause();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleDeepLink(intent);
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
