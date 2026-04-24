package app.status.mobile;

import android.content.ContentValues;
import android.content.Context;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

/**
 * Helper for inserting images into the shared MediaStore gallery (Pictures).
 * Requires Android 10+ (API 29); no storage permission is needed on Q+.
 */
public final class MediaStoreHelper {
    private MediaStoreHelper() {}

    public static boolean insertImageFromPath(Context context,
                                              String srcPath,
                                              String mimeType,
                                              String displayName) {
        if (context == null || srcPath == null || srcPath.isEmpty()) return false;
        if (mimeType == null || mimeType.isEmpty()) mimeType = "image/jpeg";
        if (displayName == null || displayName.isEmpty()) displayName = "image.jpg";

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return false;
        }

        ContentValues values = new ContentValues();
        values.put(MediaStore.Images.Media.DISPLAY_NAME, displayName);
        values.put(MediaStore.Images.Media.MIME_TYPE, mimeType);
        values.put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES);
        values.put(MediaStore.Images.Media.IS_PENDING, 1);
        final Uri contentUri =
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY);

        Uri itemUri = null;
        try {
            itemUri = context.getContentResolver().insert(contentUri, values);
            if (itemUri == null) return false;

            try (InputStream is = new FileInputStream(new File(srcPath));
                 OutputStream os = context.getContentResolver().openOutputStream(itemUri, "w")) {
                if (os == null) {
                    context.getContentResolver().delete(itemUri, null, null);
                    return false;
                }
                byte[] buf = new byte[8192];
                int n;
                while ((n = is.read(buf)) != -1) {
                    os.write(buf, 0, n);
                }
                os.flush();
            }

            ContentValues update = new ContentValues();
            update.put(MediaStore.Images.Media.IS_PENDING, 0);
            context.getContentResolver().update(itemUri, update, null, null);
            return true;
        } catch (IOException | SecurityException e) {
            if (itemUri != null) {
                context.getContentResolver().delete(itemUri, null, null);
            }
            return false;
        }
    }
}
