package app.status.mobile.ipc;

// UTF-8 JSON carrier for status-go requests, responses and signals: inline bytes for small
// payloads, a SharedMemory fd for large ones. Layout and ownership rules in IpcPayload.java.
parcelable IpcPayload;
