package app.status.mobile;

import android.app.Activity;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ImageView;

public class NativeIndicatorHelper {
    private final Activity activity;
    private FrameLayout container;
    private ImageView imageView;

    public NativeIndicatorHelper(Activity activity) {
        this.activity = activity;
        createViews();
    }

    private void createViews() {
        activity.runOnUiThread(() -> {
            ViewGroup contentView = (ViewGroup) activity.getWindow().getDecorView().findViewById(android.R.id.content);
            if (contentView == null) return;

            container = new FrameLayout(activity);
            container.setClipChildren(false);
            container.setClipToPadding(false);

            imageView = new ImageView(activity);
            imageView.setScaleType(ImageView.ScaleType.FIT_XY);
            container.addView(imageView);

            contentView.addView(container);
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

            container.setX(containerX);
            container.setY(containerY);
            FrameLayout.LayoutParams cParams = new FrameLayout.LayoutParams((int) containerW, (int) containerH);
            container.setLayoutParams(cParams);
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
            if (container != null) {
                ViewGroup parent = (ViewGroup) container.getParent();
                if (parent != null) parent.removeView(container);
            }
            container = null;
            imageView = null;
        });
    }
}


