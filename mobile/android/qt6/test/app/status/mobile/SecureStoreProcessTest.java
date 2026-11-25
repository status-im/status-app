package app.status.mobile;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class SecureStoreProcessTest {
    @Test
    public void theServiceProcessReloadsTheStoreBeforeEveryAccess() {
        assertTrue(SecureStoreProcess.reloadsBeforeEveryAccess("app.status.mobile:statusgo"));
        assertTrue(SecureStoreProcess.reloadsBeforeEveryAccess("app.status.mobile.w21715.debug:statusgo"));
    }

    @Test
    public void theUiProcessKeepsItsCachedStore() {
        assertFalse(SecureStoreProcess.reloadsBeforeEveryAccess("app.status.mobile"));
        assertFalse(SecureStoreProcess.reloadsBeforeEveryAccess("app.status.mobile.statusgo"));
        assertFalse(SecureStoreProcess.reloadsBeforeEveryAccess(null));
    }
}
