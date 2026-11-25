package app.status.mobile.ipc;

import android.content.Context;

import app.status.mobile.SecureStorageHelper;

/** The boot-login record in the prompt-free secure store (see SecureStorageHelper). */
public final class BootLoginRecordStore implements BootLogin.RecordStore {
    /** The UI process's record write, see BootLogin.writeRecord. */
    public static boolean writeFromUi(Context context, String recordJson) {
        return BootLogin.writeRecord(new BootLoginRecordStore(context), recordJson);
    }

    private final Context context;

    BootLoginRecordStore(Context context) {
        this.context = context;
    }

    @Override
    public boolean exists() throws BootLogin.StoreException {
        return StatusGoService.secureEntryExists(context, SecureStorageHelper.BOOT_LOGIN_RECORD_KEY);
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

    @Override
    public boolean write(String recordJson) {
        return store().setCredential(SecureStorageHelper.BOOT_LOGIN_RECORD_KEY, recordJson)
                == SecureStorageHelper.STATUS_OK;
    }

    @Override
    public boolean attemptPending() {
        return store().hasBootLoginAttempt();
    }

    @Override
    public void markAttempt() {
        store().setBootLoginAttempt(true);
    }

    @Override
    public void clearAttempt() {
        store().setBootLoginAttempt(false);
    }

    private SecureStorageHelper store() {
        return SecureStorageHelper.getInstance(context);
    }
}
