package app.status.mobile;

import org.qtproject.qt.android.bindings.QtActivity;
import android.os.Build;
import android.os.Bundle;
import androidx.core.splashscreen.SplashScreen;
import java.util.concurrent.atomic.AtomicBoolean;
import android.content.Intent;
import android.net.Uri;
import android.provider.Settings;

public class StatusQtActivity extends QtActivity {
    private static final AtomicBoolean splashShouldHide = new AtomicBoolean(false);
    private static StatusQtActivity sInstance = null;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        sInstance = this;
        
        if (Build.VERSION.SDK_INT >= 31) { // Android 12+
            SplashScreen splashScreen = SplashScreen.installSplashScreen(this);
            splashScreen.setKeepOnScreenCondition(() -> !splashShouldHide.get());
        }
        // Set up shake detection (used for share-on-shake)
        ShakeDetector.start(this);
    }

    @Override
    protected void onResume() {
        super.onResume();
        ShakeDetector.onResume(this);
    }

    @Override
    protected void onPause() {
        ShakeDetector.onPause();
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        sInstance = null;
        super.onDestroy();
    }

    // Called from Qt via JNI when main window is visible
    public static void hideSplashScreen() {
        splashShouldHide.set(true);
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
