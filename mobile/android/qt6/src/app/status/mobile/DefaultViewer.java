package app.status.mobile;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.provider.Settings;
import android.util.Log;

import androidx.core.content.FileProvider;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

/**
 * Whether Status opens a file type by default, and the way there and back. Only
 * the user picks a default, with "Always" when the system asks which app opens
 * the type.
 */
public final class DefaultViewer {
    private static final String TAG = "StatusDefaultViewer";

    private DefaultViewer() {}

    /** See {@link DefaultViewerRules#state}; "" for a type Status does not claim. Called from Qt via JNI. */
    public static String state(Context ctx, String mimeType) {
        if (!DefaultViewerRules.isType(mimeType)) {
            return "";
        }
        try {
            PackageManager pm = ctx.getPackageManager();
            Intent view = viewIntent(ctx, mimeType);
            ResolveInfo chosen = pm.resolveActivity(view, PackageManager.MATCH_DEFAULT_ONLY);
            if (chosen == null || chosen.activityInfo == null) {
                return DefaultViewerRules.state(ctx.getPackageName(), null, false, null);
            }
            return DefaultViewerRules.state(ctx.getPackageName(),
                    chosen.activityInfo.packageName, isCandidate(pm, view, chosen),
                    String.valueOf(chosen.loadLabel(pm)));
        } catch (RuntimeException e) {
            Log.w(TAG, "could not tell the default viewer: " + e.getClass().getSimpleName());
            return "";
        }
    }

    /**
     * Asks the system which app opens the type. False when it would not ask:
     * an app opens the type already. Called from Qt via JNI.
     */
    public static boolean offer(Activity activity, String mimeType) {
        if (!DefaultViewerRules.isType(mimeType)) {
            return false;
        }
        try {
            PackageManager pm = activity.getPackageManager();
            Intent view = viewIntent(activity, mimeType);
            ResolveInfo chosen = pm.resolveActivity(view, PackageManager.MATCH_DEFAULT_ONLY);
            if (chosen == null || chosen.activityInfo == null) {
                return false;
            }
            if (isCandidate(pm, view, chosen)) {
                return false;
            }
            writeProbe(activity, DefaultViewerRules.probeName(mimeType));
            activity.startActivity(view.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION));
            return true;
        } catch (ActivityNotFoundException | SecurityException | IOException e) {
            Log.w(TAG, "could not offer the default viewer: " + e.getClass().getSimpleName());
            return false;
        }
    }

    /** The types the user chose Status for. Called from Qt via JNI. */
    public static String[] types(Context ctx) {
        List<String> own = new ArrayList<>();
        try {
            PackageManager pm = ctx.getPackageManager();
            for (String type : DefaultViewerRules.TYPES) {
                Intent view = viewIntent(ctx, type);
                ResolveInfo chosen = pm.resolveActivity(view, PackageManager.MATCH_DEFAULT_ONLY);
                if (chosen == null || chosen.activityInfo == null
                        || !ctx.getPackageName().equals(chosen.activityInfo.packageName)) {
                    continue;
                }
                int candidates = pm.queryIntentActivities(view, PackageManager.MATCH_DEFAULT_ONLY).size();
                if (DefaultViewerRules.opensByChoice(ctx.getPackageName(),
                        chosen.activityInfo.packageName, candidates)) {
                    own.add(type);
                }
            }
        } catch (RuntimeException e) {
            Log.w(TAG, "could not list the default types: " + e.getClass().getSimpleName());
        }
        return own.toArray(new String[0]);
    }

    /**
     * Stops Status opening any type by default. When the system keeps a type,
     * opens Status's app settings, where the user clears it. True when Status
     * opens no type by default afterwards. Called from Qt via JNI.
     */
    @SuppressWarnings("deprecation")
    public static boolean reset(Activity activity) {
        try {
            activity.getPackageManager().clearPackagePreferredActivities(activity.getPackageName());
        } catch (RuntimeException e) {
            Log.w(TAG, "could not clear the defaults: " + e.getClass().getSimpleName());
        }
        if (types(activity).length == 0) {
            return true;
        }
        try {
            activity.startActivity(appSettings(activity.getPackageName()));
        } catch (ActivityNotFoundException e) {
            Log.w(TAG, "no app settings to clear the defaults in");
        }
        return false;
    }

    /** True for a probe, which comes back to us when the user picks Status. */
    static boolean isProbe(Context ctx, Uri uri) {
        Uri probe = probeUri(ctx, "Status.pdf");
        String path = probe.getPath();
        String dir = path == null ? "" : path.substring(0, path.lastIndexOf('/'));
        return DefaultViewerRules.isProbe(probe.getAuthority(), dir, uri.getAuthority(), uri.getPath());
    }

    private static Intent viewIntent(Context ctx, String mimeType) {
        return new Intent(Intent.ACTION_VIEW)
                .setDataAndType(probeUri(ctx, DefaultViewerRules.probeName(mimeType)), mimeType);
    }

    private static Intent appSettings(String packageName) {
        return new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", packageName, null));
    }

    // The system's own "Open with" dialog is not among the apps that open the type.
    private static boolean isCandidate(PackageManager pm, Intent view, ResolveInfo chosen) {
        List<ResolveInfo> candidates = pm.queryIntentActivities(view, PackageManager.MATCH_DEFAULT_ONLY);
        for (ResolveInfo candidate : candidates) {
            if (candidate.activityInfo != null
                    && candidate.activityInfo.packageName.equals(chosen.activityInfo.packageName)
                    && candidate.activityInfo.name.equals(chosen.activityInfo.name)) {
                return true;
            }
        }
        return false;
    }

    private static File probeFile(Context ctx, String name) {
        return new File(new File(ctx.getCacheDir(), DefaultViewerRules.PROBE_DIR), name);
    }

    private static Uri probeUri(Context ctx, String name) {
        return FileProvider.getUriForFile(ctx, ctx.getPackageName() + ".qtprovider", probeFile(ctx, name));
    }

    private static void writeProbe(Context ctx, String name) throws IOException {
        File file = probeFile(ctx, name);
        File dir = file.getParentFile();
        if (dir != null && !dir.isDirectory() && !dir.mkdirs()) {
            throw new IOException("no directory for the probe");
        }
        try (FileOutputStream out = new FileOutputStream(file)) {
            out.write(DefaultViewerRules.probeBytes(name));
        }
    }
}
