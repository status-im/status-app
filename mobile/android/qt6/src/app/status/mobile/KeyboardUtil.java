package app.status.mobile;

import android.app.Activity;
import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.view.Window;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.inputmethod.InputMethodManager;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import java.util.concurrent.atomic.AtomicInteger;

public class KeyboardUtil {
    // Cached keyboard state (updated by WindowInsets listener)
    private static final AtomicInteger cachedKeyboardHeight = new AtomicInteger(0);
    private static boolean isListenerSetup = false;
    
    // Call this from Qt via JNI: KeyboardUtil.getKeyboardHeight(Activity)
    // Returns the current keyboard height in pixels, or 0 if keyboard is hidden
    public static int getKeyboardHeight(Activity activity) {
        setupListenerIfNeeded(activity);
        return cachedKeyboardHeight.get();
    }
    
    // Call this from Qt via JNI: KeyboardUtil.isKeyboardVisible(Activity)
    // Returns true if keyboard is currently visible, false otherwise
    public static boolean isKeyboardVisible(Activity activity) {
        return getKeyboardHeight(activity) > 0;
    }
    
    // Setup WindowInsets listener once to cache keyboard state
    private static void setupListenerIfNeeded(Activity activity) {
        if (isListenerSetup || activity == null) return;
        
        Window window = activity.getWindow();
        if (window == null) return;
        
        View decorView = window.getDecorView();
        ViewCompat.setOnApplyWindowInsetsListener(decorView, (view, windowInsets) -> {
            // Get IME (keyboard) insets and cache the height
            Insets imeInsets = windowInsets.getInsets(WindowInsetsCompat.Type.ime());
            cachedKeyboardHeight.set(imeInsets.bottom);
            
            // Return insets unchanged so other listeners still work
            return windowInsets;
        });
        
        isListenerSetup = true;
    }

    // Force a keyboard show request. This helps on Android 16 when Qt misses the first request.
    public static void requestKeyboardShow(Activity activity) {
        if (activity == null) return;

        activity.runOnUiThread(() -> {
            View focusView = activity.getCurrentFocus();
            if (focusView == null) {
                Window window = activity.getWindow();
                if (window != null) {
                    focusView = window.getDecorView();
                }
            }
            requestKeyboardShowOnUiThread(activity, focusView, true);
        });
    }

    public static void requestKeyboardShow(Activity activity, View targetView, boolean allowRefocus) {
        if (activity == null || targetView == null) return;

        if (Looper.myLooper() == Looper.getMainLooper()) {
            requestKeyboardShowOnUiThread(activity, targetView, allowRefocus);
            return;
        }

        activity.runOnUiThread(() -> requestKeyboardShowOnUiThread(activity, targetView, allowRefocus));
    }

    private static void requestKeyboardShowOnUiThread(Activity activity, View targetView, boolean allowRefocus) {
        if (activity == null || targetView == null) return;

        if (!targetView.isFocused()) {
            targetView.requestFocus();
        }

        InputMethodManager imm = (InputMethodManager) activity.getSystemService(Context.INPUT_METHOD_SERVICE);
        if (imm != null) {
            imm.showSoftInput(targetView, InputMethodManager.SHOW_IMPLICIT);
        }

        WindowInsetsControllerCompat compatController = new WindowInsetsControllerCompat(activity.getWindow(), targetView);
        compatController.show(WindowInsetsCompat.Type.ime());

        if (Build.VERSION.SDK_INT >= 30) {
            WindowInsetsController controller = activity.getWindow().getInsetsController();
            if (controller != null) {
                controller.show(WindowInsets.Type.ime());
            }
        }

        if (allowRefocus && Build.VERSION.SDK_INT >= 36 && targetView.onCheckIsTextEditor()) {
            Handler handler = new Handler(Looper.getMainLooper());
            handler.postDelayed(() -> {
                targetView.clearFocus();
                handler.postDelayed(targetView::requestFocus, 50);
            }, 100);
        }
    }
}
