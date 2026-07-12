package app.status.mobile.debug;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.util.Log;

import androidx.core.content.ContextCompat;

import app.status.mobile.ipc.StatusGoServiceClient;

/**
 * Dev-only broadcast seam for injecting synthetic status-go signals.
 *
 * Registered dynamically (no manifest entry) and ONLY for debug/profile builds by
 * {@link #registerIfDevBuild}, so it is dead in release/fdroid by construction. Injects a
 * synthetic status-go signal into the normal delivery path so a dev build can drive signal
 * handling on demand.
 *
 * Usage:
 *   adb shell am broadcast -a app.status.mobile.DEBUG_CMD --es cmd token-dump -p <appId>
 *   adb shell am broadcast -a app.status.mobile.DEBUG_CMD --es cmd raw --es json '<signal>' -p <appId>
 */
public final class DebugCommandReceiver extends BroadcastReceiver {
    private static final String TAG = "DEBUGCMD";
    private static final String ACTION = "app.status.mobile.DEBUG_CMD";

    // Synthetic "wallet" signal carrying a dev-only eventType the token service handles by
    // writing a deterministic dump of its observable state. Piggybacks on the already-subscribed
    // wallet signal so no signals_manager/signal-type change is needed; the empty accounts array
    // is required by WalletSignal.fromEvent.
    private static final String TOKEN_DUMP_SIGNAL =
            "{\"type\":\"wallet\",\"event\":{\"type\":\"token-dump\",\"accounts\":[]}}";

    /**
     * Registers the receiver on debug/profile builds only; no-op otherwise.
     * RECEIVER_EXPORTED is required for {@code adb am broadcast} to reach a dynamically
     * registered receiver on API 33+. The receiver is dead code on release/fdroid because
     * this method is never called there.
     */
    public static void registerIfDevBuild(Context context, String buildType) {
        if (!"debug".equals(buildType) && !"profile".equals(buildType)) return;
        try {
            ContextCompat.registerReceiver(
                    context.getApplicationContext(),
                    new DebugCommandReceiver(),
                    new IntentFilter(ACTION),
                    ContextCompat.RECEIVER_EXPORTED);
            Log.i(TAG, "DebugCommandReceiver registered (buildType=" + buildType + ")");
        } catch (Throwable t) {
            Log.w(TAG, "DebugCommandReceiver registration failed", t);
        }
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || !ACTION.equals(intent.getAction())) return;
        final String cmd = intent.getStringExtra("cmd");
        if (cmd == null) {
            Log.w(TAG, "onReceive: missing 'cmd' extra");
            return;
        }
        switch (cmd) {
            case "token-dump":
                inject("token-dump", TOKEN_DUMP_SIGNAL);
                break;
            case "raw":
                final String json = intent.getStringExtra("json");
                if (json == null || json.isEmpty()) {
                    Log.w(TAG, "onReceive: cmd=raw requires a 'json' extra");
                    return;
                }
                inject("raw", json);
                break;
            default:
                Log.w(TAG, "onReceive: unknown cmd=" + cmd);
        }
    }

    private static void inject(String cmd, String jsonSignal) {
        Log.i(TAG, "injecting cmd=" + cmd + " bytes=" + jsonSignal.length());
        StatusGoServiceClient.get().injectSignalForDebug(jsonSignal);
    }
}
