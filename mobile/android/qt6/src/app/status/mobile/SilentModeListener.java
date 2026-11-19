package app.status.mobile;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.media.AudioManager;
import android.os.Build;
import android.util.Log;

public final class SilentModeListener {
    private static final String TAG = "StatusSilentMode";
    private final Context context;
    private volatile boolean registered;

    private final BroadcastReceiver receiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (!registered || !AudioManager.RINGER_MODE_CHANGED_ACTION.equals(intent.getAction()))
                return;
            int mode = intent.getIntExtra(AudioManager.EXTRA_RINGER_MODE, -1);
            if (mode >= AudioManager.RINGER_MODE_SILENT && mode <= AudioManager.RINGER_MODE_NORMAL)
                nativeOnSilentModeChanged(mode != AudioManager.RINGER_MODE_NORMAL);
            else
                Log.w(TAG, "Received invalid ringer mode: " + mode);
        }
    };

    public SilentModeListener(Context context) {
        this.context = context.getApplicationContext();
    }

    public int start() {
        AudioManager audio = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        if (audio == null) {
            Log.e(TAG, "AudioManager is unavailable");
            return -1;
        }
        try {
            if (!registered) {
                IntentFilter filter = new IntentFilter(AudioManager.RINGER_MODE_CHANGED_ACTION);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
                    context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
                else
                    context.registerReceiver(receiver, filter);
                registered = true;
            }
            return audio.getRingerMode();
        } catch (SecurityException e) {
            Log.e(TAG, "Cannot observe ringer mode", e);
            return -1;
        }
    }

    public void stop() {
        if (registered) {
            registered = false;
            context.unregisterReceiver(receiver);
        }
    }

    private static native void nativeOnSilentModeChanged(boolean silent);
}
