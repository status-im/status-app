package app.status.mobile.ipc;

import app.status.mobile.ipc.RpcResponse;

/** One-way signal stream from status-go service to UI process. */
oneway interface IStatusGoSignalListener {
    /** UTF-8 signal JSON, small enough for the Binder buffer. */
    void onSignal(in byte[] utf8);
    void onSignalShm(in RpcResponse signalPayload);
}

