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
    public boolean exists() throws BootLogin.StoreException {
        return StatusGoService.secureEntryExists(store().hasCredential(SecureStorageHelper.BOOT_LOGIN_RECORD_KEY));
    }

    @Override
    public String read() throws BootLogin.StoreException {
        final String[] out = new String[1];
        return StatusGoService.secureEntry(store().getBootLoginRecord(out), out);
    }

    @Override
    public void delete() {
        store().deleteBootLoginRecord();
    }

    private SecureStorageHelper store() {
        return SecureStorageHelper.getInstance(context);
    }
}
