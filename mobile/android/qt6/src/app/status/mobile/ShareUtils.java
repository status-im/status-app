package app.status.mobile;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;

import androidx.core.content.FileProvider;

import java.io.File;
import java.util.ArrayList;

public final class ShareUtils {
    private static final String TAG = "StatusShare";

    private ShareUtils() {}

    public static void sharePaths(Activity activity, ArrayList<String> paths) {
        if (activity == null || paths == null || paths.isEmpty()) return;

        String authority = activity.getPackageName() + ".qtprovider";
        ArrayList<Uri> uris = new ArrayList<>();

        for (String path : paths) {
            if (path == null || path.isEmpty()) continue;
            Uri uri = toUri(activity, authority, path);
            if (uri != null) {
                uris.add(uri);
            }
        }

        if (uris.isEmpty()) return;

        Intent intent;
        if (uris.size() == 1) {
            intent = new Intent(Intent.ACTION_SEND);
            intent.putExtra(Intent.EXTRA_STREAM, uris.get(0));
        } else {
            intent = new Intent(Intent.ACTION_SEND_MULTIPLE);
            intent.putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris);
        }

        intent.setType("*/*");
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);

        try {
            activity.startActivity(Intent.createChooser(intent, null));
        } catch (Throwable t) {
            Log.e(TAG, "sharePaths failed", t);
        }
    }

    private static Uri toUri(Activity activity, String authority, String path) {
        try {
            if (path.startsWith("content://")) {
                return Uri.parse(path);
            }
            if (path.startsWith("file://")) {
                Uri parsed = Uri.parse(path);
                path = parsed.getPath();
            }
            if (path == null || path.isEmpty()) return null;

            File file = new File(path);
            if (!file.exists()) {
                Log.w(TAG, "sharePaths: file missing: " + path);
            }
            return FileProvider.getUriForFile(activity, authority, file);
        } catch (Throwable t) {
            Log.e(TAG, "sharePaths: failed to build uri for " + path, t);
            return null;
        }
    }
}
