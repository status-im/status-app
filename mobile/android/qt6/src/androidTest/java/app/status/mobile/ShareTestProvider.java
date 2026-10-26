package app.status.mobile;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.ParcelFileDescriptor;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;

/**
 * Stands in for a gallery app's provider: content://<test pkg>.sharetest/image/N
 * serves a small PNG, .../video/N claims video/mp4. It lives in the test APK,
 * so to the share intake it is a foreign provider, as a real sender's is.
 */
public class ShareTestProvider extends ContentProvider {
    static final String IMAGE = "image";
    static final String VIDEO = "video";

    @Override
    public boolean onCreate() {
        return true;
    }

    @Override
    public String getType(Uri uri) {
        String kind = uri.getPathSegments().get(0);
        if (IMAGE.equals(kind)) return "image/png";
        if (VIDEO.equals(kind)) return "video/mp4";
        return null;
    }

    @Override
    public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        File png = new File(getContext().getCacheDir(), "share-test.png");
        if (!png.exists()) {
            Bitmap bitmap = Bitmap.createBitmap(4, 4, Bitmap.Config.ARGB_8888);
            try (FileOutputStream os = new FileOutputStream(png)) {
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, os);
            } catch (IOException e) {
                throw new FileNotFoundException(e.toString());
            } finally {
                bitmap.recycle();
            }
        }
        return ParcelFileDescriptor.open(png, ParcelFileDescriptor.MODE_READ_ONLY);
    }

    @Override
    public Cursor query(Uri uri, String[] projection, String selection, String[] selectionArgs,
                        String sortOrder) {
        return null;
    }

    @Override
    public Uri insert(Uri uri, ContentValues values) {
        return null;
    }

    @Override
    public int delete(Uri uri, String selection, String[] selectionArgs) {
        return 0;
    }

    @Override
    public int update(Uri uri, ContentValues values, String selection, String[] selectionArgs) {
        return 0;
    }
}
