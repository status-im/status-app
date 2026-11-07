package app.status.mobile;

import android.app.Activity;
import android.content.Context;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
import android.hardware.display.DisplayManager;
import android.util.Log;
import android.util.Size;
import android.view.Display;

import androidx.annotation.NonNull;
import androidx.camera.core.Camera;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.CameraState;
import androidx.camera.core.ImageAnalysis;
import androidx.camera.core.ImageProxy;
import androidx.camera.core.resolutionselector.ResolutionSelector;
import androidx.camera.core.resolutionselector.ResolutionStrategy;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleOwner;
import androidx.lifecycle.LifecycleRegistry;

import com.google.common.util.concurrent.ListenableFuture;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Camera frames for the QR scanner without QtMultimedia (StatusQ NativeQrCodeCapture):
 * one CameraX ImageAnalysis use case, upright RGBA frames handed to native code, which
 * draws them as the preview and crops the scan area for the decoder. Every method is
 * called from native code on any thread; CameraX and the lifecycle run on the UI thread.
 */
public final class QrCamera implements LifecycleOwner {
    private static final String TAG = "QrCamera";

    private static native void nativeFrame(long handle, java.nio.ByteBuffer rgba, int rowStride,
                                           int width, int height);
    private static native void nativeState(long handle, boolean running, boolean torchSupported,
                                           String error);

    private final long handle;
    private final Activity activity;
    private final LifecycleRegistry lifecycle;
    private final ExecutorService analyzer = Executors.newSingleThreadExecutor();
    private ProcessCameraProvider provider;
    private ImageAnalysis analysis;
    private Camera camera;
    private DisplayManager.DisplayListener displayListener;
    private String facing = "back";
    private boolean wanted;
    private boolean torch;
    private boolean released;

    public QrCamera(long handle, Activity activity) {
        this.handle = handle;
        this.activity = activity;
        lifecycle = LifecycleRegistry.createUnsafe(this);
        lifecycle.setCurrentState(Lifecycle.State.CREATED);
    }

    @NonNull
    @Override
    public Lifecycle getLifecycle() {
        return lifecycle;
    }

    /** "id\tname" lines, back camera first. */
    public static String cameras(Context context) {
        StringBuilder back = new StringBuilder();
        StringBuilder front = new StringBuilder();
        try {
            CameraManager manager = (CameraManager) context.getSystemService(Context.CAMERA_SERVICE);
            for (String id : manager.getCameraIdList()) {
                Integer lens = manager.getCameraCharacteristics(id).get(CameraCharacteristics.LENS_FACING);
                if (lens == null)
                    continue;
                if (lens == CameraCharacteristics.LENS_FACING_BACK && back.length() == 0)
                    back.append("back\tBack camera\n");
                else if (lens == CameraCharacteristics.LENS_FACING_FRONT && front.length() == 0)
                    front.append("front\tFront camera\n");
            }
        } catch (CameraAccessException | RuntimeException e) {
            Log.w(TAG, "camera list failed", e);
        }
        return back.toString() + front;
    }

    public void start(String facing) {
        activity.runOnUiThread(() -> {
            if (released)
                return;
            boolean changed = !facing.equals(this.facing);
            this.facing = facing;
            if (wanted && !changed)
                return;
            wanted = true;
            if (provider == null) {
                ListenableFuture<ProcessCameraProvider> future = ProcessCameraProvider.getInstance(activity);
                future.addListener(() -> {
                    try {
                        provider = future.get();
                    } catch (Exception e) {
                        Log.w(TAG, "camera provider failed", e);
                        nativeState(handle, false, false, String.valueOf(e.getMessage()));
                        return;
                    }
                    if (wanted && !released)
                        bind();
                }, activity.getMainExecutor());
            } else {
                bind();
            }
        });
    }

    public void stop() {
        activity.runOnUiThread(() -> {
            wanted = false;
            unbind();
        });
    }

    public void setTorch(boolean on) {
        activity.runOnUiThread(() -> {
            torch = on;
            if (camera != null && camera.getCameraInfo().hasFlashUnit())
                camera.getCameraControl().enableTorch(on);
        });
    }

    public void release() {
        activity.runOnUiThread(() -> {
            released = true;
            wanted = false;
            unbind();
            lifecycle.setCurrentState(Lifecycle.State.DESTROYED);
            analyzer.shutdown();
        });
    }

    private int displayRotation() {
        Display display = activity.getWindowManager().getDefaultDisplay();
        return display != null ? display.getRotation() : 0;
    }

    private void bind() {
        unbind();
        analysis = new ImageAnalysis.Builder()
                .setResolutionSelector(new ResolutionSelector.Builder()
                        .setResolutionStrategy(new ResolutionStrategy(new Size(1280, 720),
                                ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER))
                        .build())
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                .setOutputImageRotationEnabled(true)
                .setTargetRotation(displayRotation())
                .build();
        analysis.setAnalyzer(analyzer, this::analyze);
        CameraSelector selector = "front".equals(facing) ? CameraSelector.DEFAULT_FRONT_CAMERA
                                                         : CameraSelector.DEFAULT_BACK_CAMERA;
        try {
            lifecycle.setCurrentState(Lifecycle.State.RESUMED);
            camera = provider.bindToLifecycle(this, selector, analysis);
        } catch (RuntimeException e) {
            Log.w(TAG, "bind failed", e);
            camera = null;
            nativeState(handle, false, false, String.valueOf(e.getMessage()));
            return;
        }
        boolean flash = camera.getCameraInfo().hasFlashUnit();
        if (torch && flash)
            camera.getCameraControl().enableTorch(true);
        camera.getCameraInfo().getCameraState().observe(this, state -> {
            CameraState.StateError error = state.getError();
            if (error != null && state.getType() == CameraState.Type.CLOSED)
                nativeState(handle, false, flash, "Camera error " + error.getCode());
        });
        displayListener = new DisplayManager.DisplayListener() {
            @Override public void onDisplayAdded(int id) {}
            @Override public void onDisplayRemoved(int id) {}
            @Override public void onDisplayChanged(int id) {
                if (analysis != null)
                    analysis.setTargetRotation(displayRotation());
            }
        };
        activity.getSystemService(DisplayManager.class).registerDisplayListener(displayListener, null);
        nativeState(handle, true, flash, "");
    }

    private void unbind() {
        if (displayListener != null) {
            activity.getSystemService(DisplayManager.class).unregisterDisplayListener(displayListener);
            displayListener = null;
        }
        if (camera != null)
            camera.getCameraInfo().getCameraState().removeObservers(this);
        if (analysis != null) {
            analysis.clearAnalyzer();
            if (provider != null)
                provider.unbind(analysis);
            analysis = null;
        }
        camera = null;
        if (!released)
            lifecycle.setCurrentState(Lifecycle.State.CREATED);
        nativeState(handle, false, false, "");
    }

    private void analyze(ImageProxy image) {
        try {
            ImageProxy.PlaneProxy plane = image.getPlanes()[0];
            nativeFrame(handle, plane.getBuffer(), plane.getRowStride(), image.getWidth(),
                        image.getHeight());
        } finally {
            image.close();
        }
    }
}
