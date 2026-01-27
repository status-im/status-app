package app.status.mobile.ipc;

import app.status.mobile.ipc.IStatusGoSignalListener;

interface IStatusGoService {
    /** Generic call into status-go exports (method name is the C export name). */
    String call(String method, String argsJson);

    /**
     * Same as call(), but writes the response to a file in the service's cache dir
     * and returns the absolute file path. This avoids Binder size limits for large JSON.
     */
    String callToFile(String method, String argsJson);

    /** Register a signal listener. */
    void registerSignalListener(IStatusGoSignalListener listener);

    /** Unregister a signal listener. */
    void unregisterSignalListener(IStatusGoSignalListener listener);

    /**
     * UI visibility hint used for notification suppression.
     *
     * If {@code visible=true}, the UI is in foreground; the service should not post OS
     * message notifications (to avoid duplicates / to match “only when background” behavior).
     */
    void setUiVisible(boolean visible);
}

