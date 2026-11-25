package app.status.mobile.ipc;

import android.content.Context;

import app.status.mobile.SecureStorageHelper;

/** The boot-login record in the prompt-free secure store (see SecureStorageHelper). */
final class BootLoginRecordStore implements BootLogin.RecordStore {
    private final Context context;

    BootLoginRecordStore(Context context) {
        this.context = context;
    }

    @Override
    public String read() {
        final String[] out = new String[1];
        final int status = store().getBootLoginRecord(out);
        return status == SecureStorageHelper.STATUS_OK ? out[0] : null;
    }

    @Override
    public boolean exists() {
        return store().hasCredential(SecureStorageHelper.BOOT_LOGIN_RECORD_KEY) == SecureStorageHelper.STATUS_OK;
    }

    @Override
    public void delete() {
        store().deleteBootLoginRecord();
    }

    private SecureStorageHelper store() {
        return SecureStorageHelper.getInstance(context);
    }
}
