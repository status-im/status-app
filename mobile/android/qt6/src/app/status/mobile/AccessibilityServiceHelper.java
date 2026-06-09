package app.status.mobile;

import android.accessibilityservice.AccessibilityServiceInfo;
import android.content.Context;
import android.view.accessibility.AccessibilityManager;
import java.util.ArrayList;
import java.util.List;

public class AccessibilityServiceHelper {

    /**
     * Returns a comma-separated list of active third-party accessibility service names,
     * or an empty string if none are found.
     *
     * Filters out known system/OEM packages (com.android.*, com.samsung.*, com.sec.*,
     * com.google.*, own package). All remaining services can read the screen and warrant
     * a warning before revealing sensitive data.
     */
    public static String getActiveThirdPartyServices(Context context) {
        AccessibilityManager am =
            (AccessibilityManager) context.getSystemService(Context.ACCESSIBILITY_SERVICE);
        if (am == null) return "";

        List<AccessibilityServiceInfo> services =
            am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK);
        List<String> names = new ArrayList<>();
        for (AccessibilityServiceInfo info : services) {
            if (info.getResolveInfo() == null) continue;

            String pkg = info.getResolveInfo().serviceInfo.packageName;

            // Skip system and OEM packages — these include TalkBack (com.android.*),
            // Switch Access (com.google.*), Samsung accessibility (com.samsung.*, com.sec.*),
            // and the app itself.
            if (pkg.startsWith("com.android") ||
                pkg.startsWith("com.samsung") ||
                pkg.startsWith("com.sec") ||
                pkg.startsWith("com.google") ||
                pkg.equals(context.getPackageName())) continue;

            String label = info.getResolveInfo()
                .loadLabel(context.getPackageManager()).toString();
            names.add(label.isEmpty() ? pkg : label);
        }

        String r = String.join(", ", names);
        return r;
    }
}
