package app.status.mobile.ipc;

/** One-way signal stream from status-go service to UI process. */
oneway interface IStatusGoSignalListener {
    void onSignal(String jsonSignal);
}

