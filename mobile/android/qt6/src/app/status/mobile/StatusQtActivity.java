package app.status.mobile;

import org.qtproject.qt.android.bindings.QtActivity;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.content.pm.PackageManager;
import android.content.pm.ProviderInfo;
import androidx.core.splashscreen.SplashScreen;
import java.util.concurrent.atomic.AtomicBoolean;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.provider.Settings;
import android.util.Log;
import im.status.mobileui.PushNotificationHelper;
import android.content.ActivityNotFoundException;
import android.widget.Toast;
import android.webkit.MimeTypeMap;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;

public class StatusQtActivity extends QtActivity {
    private static final String TAG = "StatusQtActivity";
    private static final long RESTART_KILL_DELAY_MS = 250L;

    // QtActivityBase.onDestroy() can deadlock on Android during Qt/EGL teardown;
    // if it hasn't completed within this window we force-kill the UI process.
    private static final long TEARDOWN_WATCHDOG_MS = 3000L;

    private static final AtomicBoolean splashShouldHide = new AtomicBoolean(false);
    private static StatusQtActivity sInstance = null;

    private static final AtomicBoolean userLoggedIn = new AtomicBoolean(false);
    // App-private cache subdirectory holding copies of shared image streams.
    // Copies are made immediately at receipt (OS read grants on content URIs
    // expire once the source activity result is consumed); the Nim side owns
    // deletion after send/cancel and only ever deletes inside a directory of
    // this name (share_intake_cache.nim keeps the same constant).
    private static final String SHARE_INTAKE_CACHE_DIR = "share-intake";

    // Java mirror of the Nim pending intake slot (single, last-wins across
    // kinds): holds the intake URL or shared payload until mainWindowReady,
    // since on a cold start the native side isn't up yet to receive it.
    // Setting one clears the other; a replaced share's cached image copies are
    // deleted. No routing here — that lives at the Nim external-intake seam.
    private static String pendingIntakeUrl = null;
    private static String pendingIntakeShareText = null;
    private static String[] pendingIntakeShareImagePaths = null;
    private static String pendingIntakeShareDestinationChatId = null;

    // JNI hooks: implemented in native code (StatusQ urlschemeevent.cpp) to
    // forward external intake to Qt — URLs (deep links and arbitrary web
    // links) and shared content (share target; a shared link arrives as text
    // and must launch the share flow, not URL routing; imagePaths are the
    // app-private cached copies, never OS-managed URIs; destinationChatId is
    // the tapped direct-share shortcut's id, or "" for a plain share).
    private static native void passDeepLinkToQt(String deepLink);
    private static native void passShareToQt(String text, String[] imagePaths,
            String destinationChatId);

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
        // Set up density change detection
        DensityListener.start(this);

        // A fresh launch can't have an in-flight share flow: drop cached
        // copies a previous run left behind (killed before send/cancel
        // cleanup), before this launch's intent adds new ones.
        if (savedInstanceState == null) {
            sweepShareIntakeCache();
        }

        // Delivery dedup, not routing: getIntent() on an Activity recreation
        // (unlock, config change, process-death restore) or a history/recents
        // launch returns the task-root intent — possibly a days-old VIEW/SEND
        // a previous instance already processed. Re-processing it clobbers a
        // newer buffered share (URL buffering clears the pending share) or
        // replays an old deep link. Only a truly fresh launch handles the
        // creation intent; fresh warm deliveries arrive via onNewIntent.
        if (savedInstanceState == null && !isHistoryLaunch(getIntent())) {
            handleUrlIntake(getIntent());
            handleShareIntake(getIntent());
        }
    }

    private static boolean isHistoryLaunch(Intent intent) {
        return intent != null
                && (intent.getFlags() & Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0;
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
        handleUrlIntake(intent);
        handleShareIntake(intent);
    }

    @Override
    protected void onDestroy() {
        sInstance = null;
        // QtActivityBase.onDestroy() can deadlock on Android: the Qt render
        // thread blocks in eglSwapBuffers on a Surface Android already
        // destroyed, the Qt GUI thread waits on it, and this (Android UI)
        // thread waits on the GUI thread inside flushWindowSystemEvents.
        // When the activity is really finishing, guarantee the process dies
        // so the task clears from recents and the next launch is a clean
        // cold start. Armed before super.onDestroy() since that call is what
        // hangs; runs on its own daemon thread because the main thread is
        // exactly what gets stuck.
        if (isFinishing()) {
            Thread watchdog = new Thread(() -> {
                try { Thread.sleep(TEARDOWN_WATCHDOG_MS); }
                catch (InterruptedException ignored) {}
                Log.w(TAG, "Qt teardown did not complete within "
                        + TEARDOWN_WATCHDOG_MS + "ms; force-killing UI process "
                        + android.os.Process.myPid());
                android.os.Process.killProcess(android.os.Process.myPid());
            }, "status-teardown-watchdog");
            watchdog.setDaemon(true);
            watchdog.start();
        }
        super.onDestroy();
        if (isFinishing()) {
            // Teardown returned without deadlocking — still ensure the
            // process exits so no stale activity lingers in the task.
            Log.w(TAG, "onDestroy complete; force-killing UI process "
                    + android.os.Process.myPid() + " to clear the task");
            android.os.Process.killProcess(android.os.Process.myPid());
        }
    }

    // Called from Qt via JNI when main window is visible
    public static void mainWindowReady() {
        splashShouldHide.set(true);
        userLoggedIn.set(true);
        if (pendingIntakeUrl != null) {
            passDeepLinkToQt(pendingIntakeUrl);
            pendingIntakeUrl = null;
        }
        // The share fields are always set (non-null) and cleared together.
        if (pendingIntakeShareText != null) {
            passShareToQt(pendingIntakeShareText, pendingIntakeShareImagePaths,
                    pendingIntakeShareDestinationChatId);
            pendingIntakeShareText = null;
            pendingIntakeShareImagePaths = null;
            pendingIntakeShareDestinationChatId = null;
        }
    }

    // Thin, decision-free platform layer: extract the URL payload from the
    // VIEW intent and forward it to the external-intake seam.
    private void handleUrlIntake(Intent intent) {
        if (intent == null) return;
        String action = intent.getAction();
        Uri data = intent.getData();
        if (Intent.ACTION_VIEW.equals(action) && data != null) {
            if (!userLoggedIn.get()) {
                pendingIntakeUrl = data.toString();
                clearPendingShare();
                return;
            }
            passDeepLinkToQt(data.toString());
        }
    }

    // Thin, decision-free platform layer: extract the shared payload from the
    // SEND/SEND_MULTIPLE intent — copying image streams to app-private cache
    // immediately, before any read grant can expire — and forward it to the
    // external-intake seam.
    private void handleShareIntake(Intent intent) {
        if (intent == null) return;
        String action = intent.getAction();
        boolean isSend = Intent.ACTION_SEND.equals(action);
        boolean isSendMultiple = Intent.ACTION_SEND_MULTIPLE.equals(action);
        if (!isSend && !isSendMultiple) return;
        String type = intent.getType();
        if (type == null) return;
        // Android matches "text/*" and "*/*" intents against our concrete
        // text/plain and image/* filters, so the type can be a wildcard.
        boolean isWildcard = "*/*".equals(type);
        boolean isImageShare = type.startsWith("image/") || isWildcard;
        if (!isImageShare && !(isSend && type.startsWith("text/"))) return;

        String text = intent.getStringExtra(Intent.EXTRA_TEXT);
        if (text == null || text.isEmpty()) {
            text = intent.getStringExtra(Intent.EXTRA_SUBJECT);
        }
        if (text == null) text = "";

        String[] imagePaths = isImageShare
                ? copySharedImagesToCache(
                        imagesOnly(extractStreamUris(this, intent, isSendMultiple), isWildcard))
                : new String[0];
        if (text.isEmpty() && imagePaths.length == 0) {
            if (isImageShare) {
                Toast.makeText(this, "Only images and text can be shared to Status",
                        Toast.LENGTH_LONG).show();
            }
            return;
        }

        // A tap on a direct-share shortcut arrives as the same SEND intent
        // with the shortcut id (the destination chat id) attached; forwarding
        // it lets the app skip the destination picker.
        String destinationChatId = intent.getStringExtra(Intent.EXTRA_SHORTCUT_ID);
        if (destinationChatId == null) destinationChatId = "";

        if (!userLoggedIn.get()) {
            clearPendingShare();
            pendingIntakeShareText = text;
            pendingIntakeShareImagePaths = imagePaths;
            pendingIntakeShareDestinationChatId = destinationChatId;
            pendingIntakeUrl = null;
            return;
        }
        passShareToQt(text, imagePaths, destinationChatId);
    }

    // Last-wins: a replaced pending share must not leak its cached copies.
    private static void clearPendingShare() {
        if (pendingIntakeShareImagePaths != null) {
            for (String path : pendingIntakeShareImagePaths) {
                new File(path).delete();
            }
        }
        pendingIntakeShareImagePaths = null;
        pendingIntakeShareText = null;
        pendingIntakeShareDestinationChatId = null;
    }

    private static List<Uri> extractStreamUris(Context ctx, Intent intent, boolean multiple) {
        ArrayList<Uri> uris = new ArrayList<>();
        if (multiple) {
            ArrayList<Uri> streams = intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM);
            if (streams != null) {
                for (Uri stream : streams) {
                    if (isSharableStream(ctx, stream)) uris.add(stream);
                }
            }
        } else {
            Uri stream = intent.getParcelableExtra(Intent.EXTRA_STREAM);
            if (isSharableStream(ctx, stream)) uris.add(stream);
        }
        return uris;
    }

    // The sender chooses the URI but we do the opening, so an unvetted stream
    // makes us a confused deputy: openInputStream() resolves file:// directly,
    // and a content:// URI on one of our OWN providers is readable by us
    // regardless of what the sender can reach. Either lets a zero-permission
    // app name a path in our private storage and have us copy it out.
    // Accept only content:// from somebody else.
    private static boolean isSharableStream(Context ctx, Uri uri) {
        if (uri == null) return false;
        if (!ContentResolver.SCHEME_CONTENT.equals(uri.getScheme())) {
            Log.w(TAG, "share intake: rejecting non-content stream: " + uri.getScheme());
            return false;
        }
        if (belongsToUs(ctx, uri)) {
            Log.w(TAG, "share intake: rejecting stream on our own provider: " + uri.getAuthority());
            return false;
        }
        return true;
    }

    // Resolved through PackageManager rather than compared against a literal:
    // the authority carries applicationIdSuffix (".debug"), and this also
    // covers any provider we add later.
    private static boolean belongsToUs(Context ctx, Uri uri) {
        final String authority = uri.getAuthority();
        if (authority == null) return true; // unresolvable: treat as untrusted
        final ProviderInfo info =
                ctx.getPackageManager().resolveContentProvider(authority, 0);
        // Unknown authority: not ours, and openInputStream would fail anyway.
        if (info == null) return false;
        return ctx.getPackageName().equals(info.packageName);
    }

    // Resolved before copying: the copy loop runs on the UI thread, so a
    // wildcard share's video or archive would block it.
    private List<Uri> imagesOnly(List<Uri> uris, boolean resolveTypes) {
        if (!resolveTypes) return uris;
        ArrayList<Uri> images = new ArrayList<>();
        for (Uri uri : uris) {
            String mime = getContentResolver().getType(uri);
            if (mime != null && mime.startsWith("image/")) {
                images.add(uri);
            } else {
                Log.w(TAG, "share intake: dropping non-image stream (" + mime + ")");
            }
        }
        return images;
    }

    // Copies each shared stream into the share-intake cache dir and returns
    // the copies' absolute paths. Streams that fail to copy are skipped (the
    // rest of the share still goes through).
    private String[] copySharedImagesToCache(List<Uri> uris) {
        ArrayList<String> paths = new ArrayList<>();
        File dir = new File(getCacheDir(), SHARE_INTAKE_CACHE_DIR);
        if (!dir.exists() && !dir.mkdirs()) {
            Log.w(TAG, "share intake: cannot create cache dir " + dir);
            return new String[0];
        }
        int index = 0;
        for (Uri uri : uris) {
            File out = new File(dir,
                    "share-" + System.currentTimeMillis() + "-" + (index++) + extensionForUri(uri));
            try (InputStream in = getContentResolver().openInputStream(uri);
                 OutputStream os = new FileOutputStream(out)) {
                if (in == null) {
                    out.delete();
                    continue;
                }
                byte[] buffer = new byte[64 * 1024];
                int read;
                while ((read = in.read(buffer)) != -1) {
                    os.write(buffer, 0, read);
                }
                paths.add(out.getAbsolutePath());
            } catch (Exception e) {
                Log.w(TAG, "share intake: failed to copy shared image " + uri, e);
                out.delete();
            }
        }
        return paths.toArray(new String[0]);
    }

    private String extensionForUri(Uri uri) {
        String mime = getContentResolver().getType(uri);
        String ext = mime != null
                ? MimeTypeMap.getSingleton().getExtensionFromMimeType(mime)
                : null;
        return ext != null ? "." + ext : "";
    }

    private void sweepShareIntakeCache() {
        File[] files = new File(getCacheDir(), SHARE_INTAKE_CACHE_DIR).listFiles();
        if (files == null) return;
        for (File file : files) {
            file.delete();
        }
    }

    // Backgrounds the whole task, revealing the app the user came from — used
    // when the share flow is cancelled ("cancel returns to the source app").
    // Called from Qt via JNI.
    public static void moveAppTaskToBack() {
        final StatusQtActivity activity = sInstance;
        if (activity != null) {
            activity.runOnUiThread(() -> activity.moveTaskToBack(true));
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

    /**
     * Opens the system Downloads UI (Show in folder for browser downloads).
     * Called from Qt via JNI. Standard-mode completed files are registered by
     * MobileWebView; Incognito downloads are not (ADR 0006).
     */
    public static void openDownloadsUi() {
        if (sInstance == null) return;
        try {
            Intent intent = new Intent(android.app.DownloadManager.ACTION_VIEW_DOWNLOADS);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            sInstance.startActivity(intent);
        } catch (ActivityNotFoundException e) {
            Log.e(TAG, "openDownloadsUi failed", e);
        }
    }

    // Opens the system Accessibility Settings screen. Called from Qt via JNI.
    public static void openAccessibilitySettings() {
        if (sInstance == null) return;
        try {
            Intent intent = new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            sInstance.startActivity(intent);
        } catch (ActivityNotFoundException e) {
            // Handle the rare case where the settings activity doesn't exist
            Toast.makeText(sInstance, "Unable to open Accessibility Settings", Toast.LENGTH_SHORT).show();
        }
    }

    /**
     * Restarts the UI process and optionally stops the separate status-go service process.
     *
     * Called from Qt via JNI.
     */
    public static void restartApplication(boolean killBackend) {
        final StatusQtActivity activity = sInstance;
        final android.content.Context context = activity != null
                ? activity
                : StatusGoStub.getContext();

        if (context == null) {
            Log.w(TAG, "restartApplication: context is null");
            return;
        }

        if (killBackend) {
            StatusGoStub.stopService();
        }

        try {
            Intent launch = context.getPackageManager()
                    .getLaunchIntentForPackage(context.getPackageName());
            if (launch != null) {
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
                context.startActivity(launch);
            } else {
                Log.w(TAG, "restartApplication: launch intent is null");
            }
        } catch (Throwable t) {
            Log.w(TAG, "restartApplication failed", t);
        }

        new Handler(Looper.getMainLooper()).postDelayed(
                () -> android.os.Process.killProcess(android.os.Process.myPid()),
                RESTART_KILL_DELAY_MS
        );
    }
}
