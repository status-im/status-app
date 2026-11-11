package app.status.mobile;

import android.net.http.HttpResponseCache;
import android.util.Log;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * GETs https URLs for the UI process's QNetworkAccessManager with the platform TLS stack, so
 * Qt never loads OpenSSL. Responses are cached by HttpResponseCache, as QNetworkDiskCache did.
 */
final class PlatformHttps {
    private static final String TAG = "PlatformHttps";
    private static final ExecutorService EXECUTOR = Executors.newFixedThreadPool(4);
    private static boolean sCacheInstalled;

    private static native void nativeFinished(long id, int status, String contentType, byte[] body, String error);

    static synchronized void installCache(String dir, long maxSize) {
        if (sCacheInstalled) return;
        try {
            HttpResponseCache.install(new File(dir), maxSize);
            sCacheInstalled = true;
        } catch (Exception e) {
            Log.w(TAG, "no response cache", e);
        }
    }

    static void fetch(long id, String url, String accept) {
        EXECUTOR.execute(() -> {
            HttpURLConnection connection = null;
            try {
                connection = (HttpURLConnection) new URL(url).openConnection();
                connection.setConnectTimeout(15000);
                connection.setReadTimeout(30000);
                if (accept != null && !accept.isEmpty())
                    connection.setRequestProperty("Accept", accept);
                final int status = connection.getResponseCode();
                final InputStream in = status >= 400 ? connection.getErrorStream() : connection.getInputStream();
                nativeFinished(id, status, connection.getContentType(), in != null ? readAll(in) : new byte[0], null);
            } catch (Exception e) {
                nativeFinished(id, 0, null, null, e.toString());
            } finally {
                if (connection != null) connection.disconnect();
            }
        });
    }

    private static byte[] readAll(InputStream in) throws java.io.IOException {
        try (InputStream input = in) {
            final ByteArrayOutputStream out = new ByteArrayOutputStream();
            final byte[] buf = new byte[16384];
            int n;
            while ((n = input.read(buf)) > 0) out.write(buf, 0, n);
            return out.toByteArray();
        }
    }
}
