package app.status.mobile;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;

/**
 * "Open with" lands here and is passed on to StatusQtActivity in its own task,
 * together with the read grant this activity holds for the file.
 */
public class OpenedFileActivity extends Activity {
    private static final String TAG = "StatusOpenedFile";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        final Intent received = getIntent();
        final Uri uri = received != null ? received.getData() : null;
        if (savedInstanceState == null && uri != null) {
            final Intent forward = new Intent(Intent.ACTION_VIEW)
                    .setDataAndType(uri, received.getType())
                    .setClass(this, StatusQtActivity.class)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                            | Intent.FLAG_GRANT_READ_URI_PERMISSION);
            try {
                startActivity(forward);
            } catch (ActivityNotFoundException | SecurityException e) {
                Log.w(TAG, "could not pass the file on: " + e.getClass().getSimpleName());
            }
        }
        finish();
    }
}
