package app.status.mobile;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

/**
 * "Open with" and "Share" from other apps land here and are passed on to
 * StatusQtActivity in its own task, with the read grants this activity holds.
 * The caller's flags stay behind: a result it waits for is not passed on.
 */
public class ExternalIntakeActivity extends Activity {
    private static final String TAG = "StatusExternalIntake";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        final Intent received = getIntent();
        if (savedInstanceState == null && isIntake(received)) {
            final Intent forward = new Intent(received)
                    .setClass(this, StatusQtActivity.class)
                    .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                            | (received.getFlags() & Intent.FLAG_GRANT_READ_URI_PERMISSION));
            try {
                startActivity(forward);
            } catch (ActivityNotFoundException | SecurityException e) {
                Log.w(TAG, "could not pass the intent on: " + e.getClass().getSimpleName());
            }
        }
        finish();
    }

    private static boolean isIntake(Intent intent) {
        if (intent == null) return false;
        final String action = intent.getAction();
        return Intent.ACTION_VIEW.equals(action)
                || Intent.ACTION_SEND.equals(action)
                || Intent.ACTION_SEND_MULTIPLE.equals(action);
    }
}
