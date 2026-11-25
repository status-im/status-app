package app.status.mobile.ipc;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import androidx.core.content.ContextCompat;

import app.status.mobile.BuildFlags;

/**
 * Starts the boot login after a phone restart or an app update: StatusGoService in the
 * foreground, which replays the boot-login record (see BootLogin). Without a record nothing
 * starts, so the status-go library is never loaded for a device that has nothing to resume. A
 * corrupt record (half blob pair) still starts it, so the boot login fails and notifies. A
 * build with the feature off removes any record left by a build that had it on.
 */
public final class BootCompletedReceiver extends BroadcastReceiver {
    private static final String TAG = "BootCompletedReceiver";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null) return;
        if (!BootLoginTrigger.startsBootLogin(intent.getAction(), () -> BootLogin.startsOnBoot(
                BuildFlags.RESUME_AFTER_RESTART_ENABLED, new BootLoginRecordStore(context)))) {
            return;
        }
        try {
            ContextCompat.startForegroundService(context,
                    new Intent(context, StatusGoService.class).setAction(StatusGoService.ACTION_BOOT_LOGIN));
        } catch (Throwable t) {
            Log.w(TAG, "failed to start the boot login", t);
        }
    }
}
