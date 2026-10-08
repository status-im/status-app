package app.status.mobile.ipc;

import android.os.Parcel;
import android.os.Parcelable;
import android.os.SharedMemory;
import android.system.ErrnoException;
import android.system.OsConstants;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;

/**
 * UTF-8 JSON carrier for status-go requests, responses and signals.
 *
 * Carries exactly one of: an inline UTF-8 byte payload (small payloads, written directly
 * into the Binder Parcel) or a SharedMemory region (large payloads, transferred via an
 * ashmem fd so they never count against the ~1 MB Binder transaction budget). A shared
 * region holds the payload followed by one NUL byte, so native readers can hand the
 * mapping to C callers without copying it.
 *
 * Returned from a Binder method, writeToParcel runs with PARCELABLE_WRITE_RETURN_VALUE and
 * SharedMemory hands its fd to the Parcel. Passed as an {@code in} argument, the sender
 * still owns the fd and must close() after the call. Receivers must close() (try-with-
 * resources) to release the mapping and the fd. close() is idempotent.
 */
public final class IpcPayload implements Parcelable, AutoCloseable {
    /**
     * Payloads shorter than this (in UTF-8 bytes) travel inline in the Parcel; larger ones
     * go through SharedMemory to stay under the per-process Binder budget (~1 MB hard cap).
     * Empirically ~97% of RPC responses fit at 64 KB.
     */
    public static final int INLINE_THRESHOLD_BYTES = 64 * 1024;

    private static final byte TAG_INLINE = 0;
    private static final byte TAG_SHARED = 1;

    private final byte[] inlineUtf8;
    private SharedMemory shm;
    private ByteBuffer mappedBuffer;

    private IpcPayload(byte[] inlineUtf8, SharedMemory shm) {
        this.inlineUtf8 = inlineUtf8;
        this.shm = shm;
    }

    public static IpcPayload inline(byte[] utf8) {
        return new IpcPayload(utf8, null);
    }

    public static IpcPayload inline(String json) {
        return inline(json.getBytes(StandardCharsets.UTF_8));
    }

    /**
     * Copies {@code utf8} once: inline below {@code sharedThreshold} bytes, otherwise into a
     * new SharedMemory region. Does not change the buffer's position.
     */
    public static IpcPayload of(ByteBuffer utf8, int sharedThreshold, String regionName)
            throws ErrnoException {
        if (utf8.remaining() < sharedThreshold) {
            return inline(SignalFanout.toArray(utf8));
        }
        return shared(utf8, regionName);
    }

    public static IpcPayload shared(ByteBuffer utf8, String regionName) throws ErrnoException {
        SharedMemory region = null;
        try {
            region = SharedMemory.create(regionName, utf8.remaining() + 1);
            final ByteBuffer buf = region.mapReadWrite();
            try {
                buf.put(utf8.duplicate());
                buf.put((byte) 0);
            } finally {
                SharedMemory.unmap(buf);
            }
            region.setProtect(OsConstants.PROT_READ);
            final IpcPayload result = new IpcPayload(null, region);
            region = null;
            return result;
        } finally {
            if (region != null) region.close();
        }
    }

    /** Payload size in bytes, excluding the shared region's NUL terminator. */
    public int length() {
        if (inlineUtf8 != null) return inlineUtf8.length;
        return shm != null ? Math.max(0, shm.getSize() - 1) : 0;
    }

    /**
     * The payload bytes. Shared regions are mapped on first call and stay mapped until
     * close(); the returned buffer is then direct, with the NUL terminator just past its limit.
     */
    public ByteBuffer buffer() throws ErrnoException {
        if (inlineUtf8 != null) return ByteBuffer.wrap(inlineUtf8);
        if (shm == null) return ByteBuffer.allocate(0);
        if (mappedBuffer == null) mappedBuffer = shm.mapReadOnly();
        final ByteBuffer view = mappedBuffer.duplicate();
        view.limit(length());
        return view;
    }

    /**
     * The inline byte[] or the mapped direct ByteBuffer, so JNI can read the bytes in place.
     * Called by name from mobile/statusgo_stub/statusgo_stub.cpp.
     */
    public Object nativeView() throws ErrnoException {
        if (inlineUtf8 != null) return inlineUtf8;
        return buffer();
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
        shm.writeToParcel(dest, flags);
    }

    public static final Parcelable.Creator<IpcPayload> CREATOR =
            new Parcelable.Creator<IpcPayload>() {
                @Override
                public IpcPayload createFromParcel(Parcel in) {
                    final byte tag = in.readByte();
                    if (tag == TAG_INLINE) {
                        return inline(in.createByteArray());
                    }
                    return new IpcPayload(null, SharedMemory.CREATOR.createFromParcel(in));
                }

                @Override
                public IpcPayload[] newArray(int size) {
                    return new IpcPayload[size];
                }
            };
}
