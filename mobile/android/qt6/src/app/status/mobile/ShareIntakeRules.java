package app.status.mobile;

/** Android-free rules for content shared to Status (see StatusQtActivity.handleShareIntake). */
final class ShareIntakeRules {
    private ShareIntakeRules() {}

    /**
     * True when a share brought nothing Status can send and the user offered
     * something it cannot take (an image it could not read, or a file such
     * as a .txt), so Status says why instead of doing nothing.
     */
    static boolean explainsNothingShared(boolean usable, boolean imageShare, boolean fileAttached) {
        return !usable && (imageShare || fileAttached);
    }
}
