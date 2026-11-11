package app.status.mobile;

import android.content.ContentResolver;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;
import android.system.ErrnoException;
import android.system.Os;
import android.system.OsConstants;
import android.util.Log;
import android.webkit.MimeTypeMap;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.UUID;

/**
 * Files handed over through "Open with" (a VIEW intent). A content:// URI is
 * read in place: the read grant lasts as long as our activity, and a regular
 * file descriptor is all the Web View and PdfRenderer need. Only a stream is
 * copied, into {@link OpenedFileRules#COPIES_DIR}. A file:// URL from another
 * app, or a URI on one of our own providers, is never read for it.
 * Decision-free otherwise: the external-intake seam decides what opens.
 */
public final class OpenedFileIntake {
    private static final String TAG = "StatusOpenedFile";

    /** What the native side gets: the URL to load and what the provider says about it. */
    static final class OpenedFile {
        final String url;
        final String name;
        final String mimeType;
        final boolean readable;
        final boolean copied;

        OpenedFile(String url, String name, String mimeType, boolean readable, boolean copied) {
            this.url = url;
            this.name = name;
            this.mimeType = mimeType;
            this.readable = readable;
            this.copied = copied;
        }
    }

    private OpenedFileIntake() {}

    /** Background thread: may wait on the provider. Never logs the URI (Gmail puts the account in it). */
    static OpenedFile receive(Context ctx, Uri uri, String intentType) {
        final String url = uri.toString();
        if (!ContentResolver.SCHEME_CONTENT.equals(uri.getScheme())) {
            Log.w(TAG, "not reading a " + uri.getScheme() + " URL handed over by another app");
            return new OpenedFile(url, OpenedFileRules.displayName(uri.getLastPathSegment(), null),
                    "", false, false);
        }
        if (StatusQtActivity.belongsToUs(ctx, uri)) {
            Log.w(TAG, "not reading a file on our own provider");
            return new OpenedFile(url, OpenedFileRules.displayName(null, null), "", false, false);
        }

        final ContentResolver resolver = ctx.getContentResolver();
        // The Web View renders a content:// URL by its provider's type.
        final String mimeType = providerType(resolver, uri);
        final String name = OpenedFileRules.displayName(providerName(resolver, uri),
                MimeTypeMap.getSingleton().getExtensionFromMimeType(
                        OpenedFileRules.nameType(mimeType, intentType)));

        Boolean regular = isRegularFile(resolver, uri);
        if (regular == null) {
            Log.w(TAG, "the provider did not open the file (" + uri.getAuthority() + ")");
            return new OpenedFile(url, name, mimeType, false, false);
        }
        if (regular) {
            return new OpenedFile(url, name, mimeType, true, false);
        }
        File copy = copyOf(ctx, resolver, uri, name);
        if (copy == null) {
            return new OpenedFile(url, name, mimeType, false, false);
        }
        return new OpenedFile(Uri.fromFile(copy).toString(), name, mimeType, true, true);
    }

    /** Deletes a copy made by {@link #receive}; anything else is left alone. Called from Qt via JNI. */
    public static void release(Context ctx, String path) {
        if (path == null || path.isEmpty()) {
            return;
        }
        if (path.startsWith("file:")) {
            path = Uri.parse(path).getPath();
        }
        try {
            File copies = new File(ctx.getCacheDir(), OpenedFileRules.COPIES_DIR).getCanonicalFile();
            File file = new File(path).getCanonicalFile();
            if (!OpenedFileRules.isInside(file.getPath(), copies.getPath())) {
                return;
            }
            File dir = file.getParentFile();
            file.delete();
            if (dir != null && !dir.equals(copies)) {
                dir.delete();
            }
        } catch (IOException | RuntimeException e) {
            Log.w(TAG, "could not delete a copy: " + e.getClass().getSimpleName());
        }
    }

    static void discard(Context ctx, OpenedFile file) {
        if (file != null && file.copied) {
            release(ctx, file.url);
        }
    }

    /** A fresh launch has no Tab showing a copy: drop what an earlier run left. */
    static void sweep(Context ctx) {
        deleteTree(new File(ctx.getCacheDir(), OpenedFileRules.COPIES_DIR));
    }

    private static String providerType(ContentResolver resolver, Uri uri) {
        try {
            String type = resolver.getType(uri);
            return type == null ? "" : type;
        } catch (RuntimeException e) {
            return "";
        }
    }

    private static String providerName(ContentResolver resolver, Uri uri) {
        try (Cursor cursor = resolver.query(uri, new String[] {OpenableColumns.DISPLAY_NAME},
                null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                int column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (column >= 0 && !cursor.isNull(column)) {
                    return cursor.getString(column);
                }
            }
        } catch (RuntimeException e) {
            // No name from the provider: the URI's last segment will do.
        }
        return uri.getLastPathSegment();
    }

    // True for a regular file, false for a stream (a pipe), null when it does not open.
    private static Boolean isRegularFile(ContentResolver resolver, Uri uri) {
        try (ParcelFileDescriptor pfd = resolver.openFileDescriptor(uri, "r")) {
            if (pfd == null) {
                return null;
            }
            return OsConstants.S_ISREG(Os.fstat(pfd.getFileDescriptor()).st_mode);
        } catch (IOException | ErrnoException | RuntimeException e) {
            return null;
        }
    }

    // Copies up to one byte past the limit: enough for the seam to refuse it.
    private static File copyOf(Context ctx, ContentResolver resolver, Uri uri, String name) {
        File dir = new File(new File(ctx.getCacheDir(), OpenedFileRules.COPIES_DIR),
                UUID.randomUUID().toString());
        if (!dir.mkdirs()) {
            Log.w(TAG, "cannot create a directory for the copy");
            return null;
        }
        File out = new File(dir, name);
        try (InputStream in = resolver.openInputStream(uri);
             OutputStream os = new FileOutputStream(out)) {
            if (in == null) {
                throw new IOException("no stream");
            }
            byte[] buffer = new byte[64 * 1024];
            long total = 0;
            int n;
            while (total <= OpenedFileRules.COPY_LIMIT_BYTES && (n = in.read(buffer)) > 0) {
                os.write(buffer, 0, n);
                total += n;
            }
            return out;
        } catch (IOException | RuntimeException e) {
            Log.w(TAG, "could not copy the file (" + uri.getAuthority() + "): "
                    + e.getClass().getSimpleName());
            deleteTree(dir);
            return null;
        }
    }

    private static void deleteTree(File file) {
        File[] children = file.listFiles();
        if (children != null) {
            for (File child : children) {
                deleteTree(child);
            }
        }
        file.delete();
    }
}
