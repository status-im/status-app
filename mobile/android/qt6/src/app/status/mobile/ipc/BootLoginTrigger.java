package app.status.mobile.ipc;

/**
 * Which broadcasts start the boot login: a phone restart and an app update. Both kill the
 * service process, so both replay the boot-login record when one is stored.
 */
public final class BootLoginTrigger {
    static final String ACTION_BOOT_COMPLETED = "android.intent.action.BOOT_COMPLETED";
    static final String ACTION_MY_PACKAGE_REPLACED = "android.intent.action.MY_PACKAGE_REPLACED";

    private BootLoginTrigger() {}

    /** recordStored runs only for a trigger: it removes a record when the feature is off. */
    public static boolean startsBootLogin(String action, BootLogin.Condition recordStored) {
        return (ACTION_BOOT_COMPLETED.equals(action) || ACTION_MY_PACKAGE_REPLACED.equals(action))
                && recordStored.holds();
    }
}
