package app.status.mobile;

import android.content.Context;
import app.status.mobile.ipc.IpcPayload;
import app.status.mobile.ipc.StatusGoServiceClient;

import java.nio.ByteBuffer;

/**
 * UI-process bridge used by the native status-go stub library (libstatus_stub.so).
 *
 * For now this is a placeholder: it provides a stable Java surface for the native stub
 * to call into. Next step is to back this by a Binder client that talks to the
 * separate status-go service process.
 */
public final class StatusGoStub {
    static {
        // Loads libstatus_stub.so (needed for JNI_OnLoad + nativeInit).
        System.loadLibrary("status_stub");
    }

    private StatusGoStub() {}

    // Native: supplies the Java class that implements call().
    private static native void nativeInit(Class<?> bridgeClass);

    // Native: deliver UTF-8 signal JSON from the Binder listener to the Nim callback.
    public static native void nativeDeliverSignal(byte[] utf8);

    // Native: as above for a mapped shared region; reads {@code length} bytes in place.
    public static native void nativeDeliverSignalDirect(ByteBuffer utf8, int length);

    /** Must be called early (e.g. Activity.onCreate) to bind the Java bridge. */
    public static void ensureInitialized(Context context) {
        nativeInit(StatusGoStub.class);
        // Start/bind the status-go service early so first RPC doesn't block too long.
        StatusGoServiceClient.get().ensureStartedAndBound(context);
    }

    /**
     * Called from native status-go stub; the native side reads and closes the result.
     * @param method status-go exported method name (e.g. "CallPrivateRPC")
     * @param argsUtf8 direct buffer over the UTF-8 JSON array of string args
     */
    public static IpcPayload call(String method, ByteBuffer argsUtf8) {
        // Called from native stub exports; forward to separate-process service.
        if (sContext == null) {
            return IpcPayload.inline("{\"error\":\"StatusGoStub not initialized\"}");
        }
        return StatusGoServiceClient.get().call(sContext, method, argsUtf8);
    }

    /** Hint to the service whether the UI is currently visible (foreground). */
    public static void setUiVisible(boolean visible) {
        if (sContext == null) return;
        StatusGoServiceClient.get().setUiVisible(sContext, visible);
    }

    /**
     * Stops the separate status-go service process.
     */
    public static void stopService() {
        if (sContext == null) return;
        StatusGoServiceClient.get().stopService(sContext);
    }

    private static volatile Context sContext;

    /** Called by Activity. Keep application context for later native calls. */
    public static void setContext(Context context) {
        sContext = context.getApplicationContext();
    }

    /** Returns application context if initialized; null otherwise. */
    public static Context getContext() {
        return sContext;
    }
}

