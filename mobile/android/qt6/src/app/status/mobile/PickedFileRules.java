package app.status.mobile;

import java.util.regex.Pattern;

/** Android-free rules for the copies UrlUtils::convertUrlToLocalPath makes of picked files. */
final class PickedFileRules {
    /** App-private cache subdirectory holding the copies; the same name as in urlutils.cpp. */
    static final String COPIES_DIR = "picked-files";

    private static final Pattern LEGACY_COPY_NAME = Pattern.compile(
            "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}");

    private PickedFileRules() {}

    /** Whether a file in the cache root is a copy that older builds left there, named by a bare UUID. */
    static boolean isLegacyCopyName(String name) {
        return name != null && LEGACY_COPY_NAME.matcher(name).matches();
    }
}
