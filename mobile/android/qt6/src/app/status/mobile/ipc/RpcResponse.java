package app.status.mobile.ipc;

import android.os.Parcel;
import android.os.Parcelable;
import android.os.SharedMemory;
import android.system.ErrnoException;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;

/**
 * Hybrid status-go RPC response carrier.
 *
 * Carries exactly one of: an inline UTF-8 byte payload (small responses, returned directly
 * in the Binder reply Parcel) or a SharedMemory region (large responses, transferred
 * zero-copy via an ashmem fd). UTF-8 bytes are used for the inline tag so wire-size and
 * threshold semantics are unit-consistent with the SharedMemory path.
 *
 * Server-side ownership: once an RpcResponse holding a SharedMemory is returned to the
 * Binder framework, writeToParcel is invoked with PARCELABLE_WRITE_RETURN_VALUE; SharedMemory
 * itself releases its local fd at that point and the Parcel takes ownership for delivery.
 *
 * Client-side ownership: callers must use try-with-resources (or otherwise call close())
 * to release the mapped buffer and the SharedMemory fd. close() is idempotent.
 */
public final class RpcResponse implements Parcelable, AutoCloseable {
    private static final byte TAG_INLINE = 0;
    private static final byte TAG_SHARED = 1;

    private final byte[] inlineUtf8;
    private SharedMemory shm;
    private ByteBuffer mappedBuffer;
    private String cachedJson;

    private RpcResponse(byte[] inlineUtf8, SharedMemory shm) {
        this.inlineUtf8 = inlineUtf8;
        this.shm = shm;
    }

    public static RpcResponse inline(byte[] utf8) {
        return new RpcResponse(utf8, null);
    }

    public static RpcResponse shared(SharedMemory shm) {
        return new RpcResponse(null, shm);
    }

    /**
     * Decodes the JSON payload, mapping the SharedMemory on first call and caching the
     * resulting String. Subsequent calls return the cache without re-mapping, so callers
     * may invoke readJson() more than once without leaking ashmem mappings.
     */
    public String readJson() throws ErrnoException {
        if (cachedJson != null) return cachedJson;
        if (inlineUtf8 != null) {
            cachedJson = new String(inlineUtf8, StandardCharsets.UTF_8);
            return cachedJson;
        }
        if (shm == null) {
            cachedJson = "";
            return cachedJson;
        }
        ByteBuffer buf = shm.mapReadOnly();
        mappedBuffer = buf;
        cachedJson = StandardCharsets.UTF_8.decode(buf).toString();
        return cachedJson;
    }

    @Override
    public void close() {
        if (mappedBuffer != null) {
            try {
                SharedMemory.unmap(mappedBuffer);
            } catch (Throwable ignored) {
                // unmap can throw IllegalArgumentException for foreign buffers; we tolerate.
            }
            mappedBuffer = null;
        }
        if (shm != null) {
            shm.close();
            shm = null;
        }
    }

    @Override
    public int describeContents() {
        return shm != null ? CONTENTS_FILE_DESCRIPTOR : 0;
    }

    @Override
    public void writeToParcel(Parcel dest, int flags) {
        if (inlineUtf8 != null) {
            dest.writeByte(TAG_INLINE);
            dest.writeByteArray(inlineUtf8);
            return;
        }
        dest.writeByte(TAG_SHARED);
        // SharedMemory.writeToParcel honors PARCELABLE_WRITE_RETURN_VALUE: when set (the
        // standard case for AIDL return values), it transfers fd ownership to the Parcel
        // and releases the local SharedMemory's fd, so no explicit close is needed here.
        // SharedMemory.getSize() is the authoritative payload size on the receiving end.
        shm.writeToParcel(dest, flags);
    }

    public static final Parcelable.Creator<RpcResponse> CREATOR =
            new Parcelable.Creator<RpcResponse>() {
                @Override
                public RpcResponse createFromParcel(Parcel in) {
                    final byte tag = in.readByte();
                    if (tag == TAG_INLINE) {
                        return inline(in.createByteArray());
                    }
                    final SharedMemory shm = SharedMemory.CREATOR.createFromParcel(in);
                    return shared(shm);
                }

                @Override
                public RpcResponse[] newArray(int size) {
                    return new RpcResponse[size];
                }
            };
}
