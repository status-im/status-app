package app.status.mobile;

/** Build-time switches shared by the UI and the :statusgo process. */
public final class BuildFlags {
    private BuildFlags() {}

    /** debug, profile and PR packages; never true for release or fdroid. */
    public static final boolean PROFILING = BuildConfig.PR_VARIANT
            || (!"release".equals(BuildConfig.BUILD_TYPE) && !"fdroid".equals(BuildConfig.BUILD_TYPE));

    /** Boot login after a phone restart (FLAG_RESUME_AFTER_RESTART_ENABLED, as for Nim). */
    public static final boolean RESUME_AFTER_RESTART_ENABLED = BuildConfig.RESUME_AFTER_RESTART_ENABLED;
}
