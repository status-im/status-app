package app.status.mobile;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import android.content.Intent;
import android.net.Uri;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.filters.SmallTest;

import org.junit.Test;
import org.junit.runner.RunWith;

import java.lang.reflect.Method;
import java.util.List;

/**
 * RED test — pins the share-intake stream-validation gap (PR #21769).
 *
 * StatusQtActivity.handleShareIntake copies every EXTRA_STREAM into the
 * app-private share-intake cache with the app's own UID, without validating
 * the URI scheme or authority. Any installed app with zero permissions can
 * send an ACTION_SEND with type "image/png" and a `file://` URI (or a
 * `content://` URI pointing at Status's own FileProvider authority); the file
 * is read as Status and staged as a sendable "image", so private
 * keystore/DB/log content can be exfiltrated into a chat.
 *
 * The intake must accept only foreign `content://` streams: reject the
 * `file://` scheme and reject our own `${applicationId}.qtprovider` authority.
 * There is no such vetting today, so the assertions below FAIL (RED). They go
 * GREEN once handleShareIntake vets every extracted stream before copying it.
 *
 * Note: this exercises the pure static extraction seam via reflection, so it
 * does not boot Qt/status-go. It still runs as an instrumentation test because
 * android.net.Uri scheme/authority parsing needs the real framework.
 */
@RunWith(AndroidJUnit4.class)
@SmallTest
public class ShareIntakeSecurityTest {

    private static final String OWN_FILEPROVIDER_AUTHORITY =
            "app.status.mobile.qtprovider";

    @SuppressWarnings("unchecked")
    private static List<Uri> extractStreams(Intent intent, boolean multiple) throws Exception {
        Method m = StatusQtActivity.class.getDeclaredMethod(
                "extractStreamUris", Intent.class, boolean.class);
        m.setAccessible(true);
        return (List<Uri>) m.invoke(null, intent, multiple);
    }

    /** A share stream is safe only if it is a foreign content:// URI. */
    private static boolean isForeignContentStream(Uri uri) {
        if (uri == null) return false;
        if (!"content".equals(uri.getScheme())) return false;
        return !OWN_FILEPROVIDER_AUTHORITY.equals(uri.getAuthority());
    }

    @Test
    public void fileSchemeStreamIsRejected() throws Exception {
        // A hostile app hands us a path inside Status's own private storage.
        Uri hostile = Uri.parse("file:///data/user/0/app.status.mobile/files/keystore/secret");
        Intent intent = new Intent(Intent.ACTION_SEND)
                .setType("image/png")
                .putExtra(Intent.EXTRA_STREAM, hostile);

        for (Uri uri : extractStreams(intent, false)) {
            assertTrue(
                    "Share intake must reject non-content stream: " + uri,
                    isForeignContentStream(uri));
        }
    }

    @Test
    public void ownFileProviderAuthorityIsRejected() throws Exception {
        // Our own FileProvider authority is grantable back to us — a confused
        // deputy vector that must not be treated as an incoming share.
        Uri selfRef = Uri.parse(
                "content://" + OWN_FILEPROVIDER_AUTHORITY + "/cache/share-intake/leak.png");
        Intent intent = new Intent(Intent.ACTION_SEND)
                .setType("image/png")
                .putExtra(Intent.EXTRA_STREAM, selfRef);

        for (Uri uri : extractStreams(intent, false)) {
            assertTrue(
                    "Share intake must reject our own FileProvider authority: " + uri,
                    isForeignContentStream(uri));
        }
    }

    @Test
    public void foreignContentStreamIsAccepted() throws Exception {
        // The legitimate case (e.g. Google Photos) must still pass — this
        // assertion is already GREEN and guards against an over-broad fix.
        Uri legit = Uri.parse("content://com.google.android.apps.photos.contentprovider/1/2/img");
        Intent intent = new Intent(Intent.ACTION_SEND)
                .setType("image/png")
                .putExtra(Intent.EXTRA_STREAM, legit);

        List<Uri> streams = extractStreams(intent, false);
        assertEquals(1, streams.size());
        assertTrue(isForeignContentStream(streams.get(0)));
    }
}
