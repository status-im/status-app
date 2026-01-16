package app.status.mobile;

import org.qtproject.qt.android.bindings.QtActivity;
import android.os.Build;
import android.os.Bundle;
import androidx.core.splashscreen.SplashScreen;
import java.util.concurrent.atomic.AtomicBoolean;

public class StatusQtActivity extends QtActivity {
    private static final AtomicBoolean splashShouldHide = new AtomicBoolean(false);
    
    // QTBUG-140897: Android 16 keyboard workaround
    // Remove this line when Qt 6.10+ fixes the issue, and delete Android16KeyboardWorkaround.java
    private Android16KeyboardWorkaround mKeyboardWorkaround;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        if (Build.VERSION.SDK_INT >= 31) { // Android 12+
            SplashScreen splashScreen = SplashScreen.installSplashScreen(this);
            splashScreen.setKeepOnScreenCondition(() -> !splashShouldHide.get());
        }
        
        // QTBUG-140897: Install Android 16 keyboard workaround
        // Remove this line when Qt 6.10+ fixes the issue
        mKeyboardWorkaround = Android16KeyboardWorkaround.install(this);

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
        // QTBUG-140897: Cleanup workaround resources
        // Remove this when Qt 6.10+ fixes the issue
        if (mKeyboardWorkaround != null) {
            mKeyboardWorkaround.cleanup();
            mKeyboardWorkaround = null;
        }
        
        super.onDestroy();
    }

    // Called from Qt via JNI when main window is visible
    public static void hideSplashScreen() {
        splashShouldHide.set(true);
    }
}
