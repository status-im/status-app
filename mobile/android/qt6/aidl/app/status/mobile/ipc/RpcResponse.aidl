package app.status.mobile.ipc;

// Hybrid carrier for status-go RPC responses: inline UTF-8 bytes for small payloads,
// SharedMemory fd for large ones. Layout and ownership rules in RpcResponse.java.
parcelable RpcResponse;
