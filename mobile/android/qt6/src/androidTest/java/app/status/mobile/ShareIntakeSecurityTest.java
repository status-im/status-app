package app.status.mobile;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.filters.SmallTest;
import androidx.test.platform.app.InstrumentationRegistry;

import org.junit.Test;
import org.junit.runner.RunWith;

import java.lang.reflect.Method;
import java.util.List;

/**
 * Share-intake stream vetting: StatusQtActivity.handleShareIntake opens every
 * EXTRA_STREAM as Status itself, so a zero-permission app could otherwise hand
 * us a file:// path or a content:// URI on our own FileProvider and have
 * private storage staged as a sendable image. Only foreign content:// streams
 * may pass.
 *
 * Exercises the static extraction seam by reflection; no Qt/status-go boot.
 * Runs under instrumentation because android.net.Uri parsing and the
 * PackageManager provider lookup need the real framework.
 */
@RunWith(AndroidJUnit4.class)
@SmallTest
public class ShareIntakeSecurityTest {

    private static final Context CTX =
            InstrumentationRegistry.getInstrumentation().getTargetContext();

    // Carries applicationIdSuffix (".debug"), same as the manifest authority.
    private static final String OWN_FILEPROVIDER_AUTHORITY =
            CTX.getPackageName() + ".qtprovider";

    @SuppressWarnings("unchecked")
    private static List<Uri> extractStreams(Intent intent, boolean multiple) throws Exception {
        Method m = StatusQtActivity.class.getDeclaredMethod(
                "extractStreamUris", Context.class, Intent.class, boolean.class);
        m.setAccessible(true);
        return (List<Uri>) m.invoke(null, CTX, intent, multiple);
    }

    private static Intent sendImage(Uri stream) {
        return new Intent(Intent.ACTION_SEND)
                .setType("image/png")
                .putExtra(Intent.EXTRA_STREAM, stream);
    }

    @Test
    public void fileSchemeStreamIsRejected() throws Exception {
        // A hostile app hands us a path inside Status's own private storage.
        Uri hostile = Uri.parse("file:///data/user/0/app.status.mobile/files/keystore/secret");

        List<Uri> streams = extractStreams(sendImage(hostile), false);
        assertTrue("Share intake must reject non-content stream: " + streams, streams.isEmpty());
    }

    @Test
    public void ownFileProviderAuthorityIsRejected() throws Exception {
        // Our own FileProvider authority is grantable back to us — a confused
        // deputy vector that must not be treated as an incoming share.
        Uri selfRef = Uri.parse(
                "content://" + OWN_FILEPROVIDER_AUTHORITY + "/cache/share-intake/leak.png");

        List<Uri> streams = extractStreams(sendImage(selfRef), false);
        assertTrue("Share intake must reject our own FileProvider authority: " + streams,
                streams.isEmpty());
    }

    @Test
    public void foreignContentStreamIsAccepted() throws Exception {
        // The legitimate case (e.g. Google Photos) must still pass — guards
        // against an over-broad fix.
        Uri legit = Uri.parse("content://com.google.android.apps.photos.contentprovider/1/2/img");

        List<Uri> streams = extractStreams(sendImage(legit), false);
        assertEquals(1, streams.size());
        assertEquals(legit, streams.get(0));
    }
}
