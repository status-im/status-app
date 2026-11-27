package app.status.mobile;

/**
 * Tells whether an intake that finished its background work is still the one
 * to deliver (see StatusQtActivity). Not thread-safe: the caller holds intakeLock.
 */
final class IntakeSerials {
    static final class Ticket {
        final int any;
        // 0 for an intake that is not a share.
        final int share;

        Ticket(int any, int share) {
            this.any = any;
            this.share = share;
        }
    }

    private int any = 0;
    private int shares = 0;

    Ticket next() {
        return new Ticket(++any, 0);
    }

    Ticket nextShare() {
        return new Ticket(++any, ++shares);
    }

    /**
     * Before login the slot keeps one intake, so any later intake makes a
     * ticket stale. Logged in, only a later share makes a share stale.
     */
    boolean isStale(Ticket ticket, boolean loggedIn) {
        return loggedIn ? ticket.share != 0 && ticket.share != shares : ticket.any != any;
    }
}
