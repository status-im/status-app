package app.status.mobile;

import android.app.Activity;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.PixelFormat;
import android.os.Build;
import android.os.IBinder;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.ImageView;

public class NativeIndicatorHelper implements WindowSurfaceMode.Listener {
    private final Activity activity;
    private FrameLayout container;
    private ImageView imageView;

    // While the activity window draws no views (WindowSurfaceMode "ts"), the indicator lives in a
    // software-drawn, untouchable panel: a band as wide as the window and as tall as the container,
    // so moving it sideways never relayouts a window.
    private FrameLayout band;
    private WindowManager.LayoutParams bandParams;
    private float containerY;

    public NativeIndicatorHelper(Activity activity) {
        this.activity = activity;
        createViews();
    }

    private ViewGroup contentView() {
        return (ViewGroup) activity.getWindow().getDecorView().findViewById(android.R.id.content);
    }

    private boolean inBand() {
        return band != null;
    }

    private void host() {
        if (container == null || container.getParent() != null) return;
        if (WindowSurfaceMode.mainWindowDrawsViews()) {
            ViewGroup contentView = contentView();
            if (contentView != null) contentView.addView(container);
            container.setY(containerY);
            return;
        }
        final View decor = activity.getWindow().getDecorView();
        final IBinder token = decor.getWindowToken();
        if (token == null) {
            decor.post(this::host);
            return;
        }
        band = new FrameLayout(activity);
        band.setClipChildren(false);
        band.addView(container);
        container.setY(0);
        bandParams = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT, Math.max(1, container.getLayoutParams() != null
                        ? container.getLayoutParams().height : 1),
                WindowManager.LayoutParams.TYPE_APPLICATION_PANEL,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                        | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                        | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                        | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT);
        bandParams.gravity = Gravity.TOP | Gravity.START;
        bandParams.token = token;
        bandParams.y = (int) containerY + contentOffsetY();
        bandParams.setTitle("StatusIndicatorBand");
        if (Build.VERSION.SDK_INT >= 30) bandParams.setFitInsetsTypes(0);
        // The application context's WindowManager has no parent window, so the panel takes the
        // application's hardwareAccelerated=false and draws in software: no HWUI renderer.
        windowManager().addView(band, bandParams);
        WindowSurfaceMode.addListener(this);
    }

    private WindowManager windowManager() {
        return (WindowManager) activity.getApplicationContext().getSystemService(android.content.Context.WINDOW_SERVICE);
    }

    private int contentOffsetY() {
        ViewGroup contentView = contentView();
        if (contentView == null) return 0;
        int[] loc = new int[2];
        contentView.getLocationInWindow(loc);
        return loc[1];
    }

    private void unhostBand() {
        if (band == null) return;
        band.removeView(container);
        windowManager().removeViewImmediate(band);
        band = null;
        bandParams = null;
        WindowSurfaceMode.removeListener(this);
    }

    @Override
    public void beforeWindowReadd() {
        unhostBand();
    }

    @Override
    public void afterWindowReadd() {
        host();
    }

    private void createViews() {
        activity.runOnUiThread(() -> {
            if (contentView() == null) return;

            container = new FrameLayout(activity);
            container.setClipChildren(false);
            container.setClipToPadding(false);
            container.setElevation(1f);

            imageView = new ImageView(activity);
            imageView.setScaleType(ImageView.ScaleType.FIT_XY);
            container.addView(imageView);

            host();
        });
    }

    public void updateBitmap(byte[] pngBytes) {
        if (pngBytes == null) return;
        activity.runOnUiThread(() -> {
            if (imageView == null) return;
            Bitmap bmp = BitmapFactory.decodeByteArray(pngBytes, 0, pngBytes.length);
            if (bmp != null) imageView.setImageBitmap(bmp);
        });
    }

    public void updateLayout(
        float containerX, float containerY, float containerW, float containerH,
        float imgX, float imgY, float imgW, float imgH,
        boolean visible, boolean clip
    ) {
        activity.runOnUiThread(() -> {
            if (container == null || imageView == null) return;

            this.containerY = containerY;
            container.setX(containerX);
            FrameLayout.LayoutParams cParams = new FrameLayout.LayoutParams((int) containerW, (int) containerH);
            container.setLayoutParams(cParams);
            if (inBand()) {
                container.setY(0);
                final int y = (int) containerY + contentOffsetY();
                final int h = Math.max(1, (int) containerH);
                if (bandParams.y != y || bandParams.height != h) {
                    bandParams.y = y;
                    bandParams.height = h;
                    windowManager().updateViewLayout(band, bandParams);
                }
            } else {
                container.setY(containerY);
            }
            container.setVisibility(visible ? android.view.View.VISIBLE : android.view.View.GONE);

            container.setClipChildren(clip);
            container.setClipToPadding(clip);

            FrameLayout.LayoutParams iParams = new FrameLayout.LayoutParams((int) imgW, (int) imgH);
            imageView.setLayoutParams(iParams);
            imageView.setX(imgX);
            imageView.setY(imgY);
        });
    }

    public void cleanup() {
        activity.runOnUiThread(() -> {
            unhostBand();
            if (container != null) {
                ViewGroup parent = (ViewGroup) container.getParent();
                if (parent != null) parent.removeView(container);
            }
            container = null;
            imageView = null;
        });
    }
}


