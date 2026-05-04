package app.status.mobile.ipc;

import app.status.mobile.ipc.IStatusGoSignalListener;
import app.status.mobile.ipc.RpcResponse;

interface IStatusGoService {
    /**
     * Hybrid status-go RPC.
     *
     * Returns the response inline in the Binder reply Parcel when small enough, otherwise
     * via an ashmem-backed SharedMemory region carried by the returned RpcResponse. The
     * server picks the path based on response size; the client must release the
     * RpcResponse via close() (try-with-resources).
     */
    RpcResponse rpcCall(String method, String argsJson);

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
