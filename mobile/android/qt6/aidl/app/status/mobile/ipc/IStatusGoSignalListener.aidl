package app.status.mobile.ipc;

import app.status.mobile.ipc.RpcResponse;

/** One-way signal stream from status-go service to UI process. */
oneway interface IStatusGoSignalListener {
    void onSignal(String jsonSignal);
    void onSignalShm(in RpcResponse signalPayload);
}

