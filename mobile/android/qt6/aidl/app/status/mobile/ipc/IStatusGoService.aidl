package app.status.mobile.ipc;

import app.status.mobile.ipc.IStatusGoSignalListener;
import app.status.mobile.ipc.IpcPayload;

interface IStatusGoService {
    /**
     * status-go call: {@code args} is the UTF-8 JSON array of string arguments.
     *
     * Requests and responses travel inline in the Parcel when small enough, otherwise via
     * an ashmem-backed SharedMemory region carried by the IpcPayload, so neither side can
     * exceed the Binder transaction budget. Both sides release their IpcPayloads via
     * close() (try-with-resources).
     */
    IpcPayload rpcCall(String method, in IpcPayload args);

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
