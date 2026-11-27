package app.status.mobile;

/** Android-free rules for files handed over through "Open with" (see OpenedFileIntake). */
final class OpenedFileRules {
    /** App-private cache subdirectory holding copies of opened files. */
    static final String COPIES_DIR = "opened-files";

    /** Same limit as OpenedFileCopyLimitBytes in external_intake.nim. */
    static final long COPY_LIMIT_BYTES = 200L * 1024 * 1024;

    private static final String FALLBACK_NAME = "file";

    private OpenedFileRules() {}

    /**
     * The name to show and to check against the browser's formats: the
     * provider's name without any directory, with the extension of the MIME
     * type when the name has none.
     */
    static String displayName(String providerName, String mimeExtension) {
        String name = providerName == null ? "" : providerName;
        int slash = Math.max(name.lastIndexOf('/'), name.lastIndexOf('\\'));
        name = name.substring(slash + 1).trim();
        if (name.isEmpty() || name.equals(".") || name.equals("..")) {
            name = FALLBACK_NAME;
        }
        if (mimeExtension != null && !mimeExtension.isEmpty() && !hasExtension(name)) {
            name = name + "." + mimeExtension;
        }
        return name;
    }

    /**
     * The type whose extension a nameless file gets: the provider's, else the
     * sender's claim, which only names a copy and never describes a file.
     */
    static String nameType(String providerType, String intentType) {
        if (providerType != null && !providerType.isEmpty()) {
            return providerType;
        }
        return intentType == null ? "" : intentType;
    }

    /** Whether canonical {@code path} lies inside canonical {@code dir}, not being it. */
    static boolean isInside(String path, String dir) {
        if (path == null || dir == null || dir.isEmpty()) {
            return false;
        }
        String prefix = dir.endsWith("/") ? dir : dir + "/";
        return path.startsWith(prefix) && path.length() > prefix.length();
    }

    private static boolean hasExtension(String name) {
        int dot = name.lastIndexOf('.');
        return dot >= 0 && dot < name.length() - 1;
    }
}
