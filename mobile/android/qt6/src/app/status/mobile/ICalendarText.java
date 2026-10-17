package app.status.mobile;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

// Renders a shared iCalendar file as readable events: summary, when,
// location, description, URL. Alarms, attendees, recurrence rules and
// anything else are dropped; chat has no event message, so it travels as text.
final class ICalendarText {
    private static final String[] MONTHS = {"Jan", "Feb", "Mar", "Apr", "May", "Jun",
            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};

    private ICalendarText() {}

    static boolean isICalendar(String text) {
        String t = text.trim();
        return t.regionMatches(true, 0, "BEGIN:VCALENDAR", 0, "BEGIN:VCALENDAR".length());
    }

    // Every event in the text, blank-line separated. Falls back to the raw
    // text when no event was found.
    static String format(String text) {
        StringBuilder out = new StringBuilder();
        Event event = null;
        int nested = 0;
        for (String line : VCardText.unfold(text)) {
            int colon = line.indexOf(':');
            if (colon <= 0) continue;
            List<String> head = VCardText.splitUnescaped(line.substring(0, colon), ';');
            String name = head.get(0).toUpperCase(Locale.ROOT);
            List<String> params = head.subList(1, head.size());
            String value = line.substring(colon + 1);
            if (name.equals("BEGIN")) {
                if (value.equalsIgnoreCase("VEVENT") && event == null) event = new Event();
                else if (event != null) nested++;
            } else if (name.equals("END")) {
                if (nested > 0) nested--;
                else if (event != null && value.equalsIgnoreCase("VEVENT")) {
                    String rendered = event.render();
                    if (!rendered.isEmpty()) {
                        if (out.length() > 0) out.append("\n\n");
                        out.append(rendered);
                    }
                    event = null;
                }
            } else if (event != null && nested == 0) {
                event.add(name, params, value);
            }
        }
        return out.length() > 0 ? out.toString() : text.trim();
    }

    // "20261005T090000Z", "20261005T090000" (floating or TZID) or "20261005".
    static final class Moment {
        final int year, month, day, hour, minute;
        final boolean allDay;
        final String zone; // "UTC", a TZID, or "" for floating

        Moment(int year, int month, int day, int hour, int minute, boolean allDay, String zone) {
            this.year = year; this.month = month; this.day = day;
            this.hour = hour; this.minute = minute; this.allDay = allDay; this.zone = zone;
        }

        static Moment parse(String value, List<String> params) {
            String v = value.trim();
            String tzid = "";
            boolean dateOnly = false;
            for (String p : params) {
                String u = p.toUpperCase(Locale.ROOT);
                if (u.startsWith("TZID=")) tzid = p.substring(5).replace("\"", "");
                if (u.equals("VALUE=DATE")) dateOnly = true;
            }
            try {
                int y = Integer.parseInt(v.substring(0, 4));
                int m = Integer.parseInt(v.substring(4, 6));
                int d = Integer.parseInt(v.substring(6, 8));
                if (m < 1 || m > 12 || d < 1 || d > 31) return null;
                if (dateOnly || v.length() == 8) return new Moment(y, m, d, 0, 0, true, "");
                if (v.charAt(8) != 'T' || v.length() < 13) return null;
                int hh = Integer.parseInt(v.substring(9, 11));
                int mm = Integer.parseInt(v.substring(11, 13));
                String zone = v.endsWith("Z") ? "UTC" : tzid;
                return new Moment(y, m, d, hh, mm, false, zone);
            } catch (RuntimeException e) {
                return null;
            }
        }

        // DTEND of an all-day event is exclusive; show the last day instead.
        Moment previousDay() {
            int y = year, m = month, d = day - 1;
            if (d < 1) {
                m--;
                if (m < 1) { m = 12; y--; }
                d = daysIn(y, m);
            }
            return new Moment(y, m, d, 0, 0, true, zone);
        }

        private static int daysIn(int y, int m) {
            int[] n = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
            boolean leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;
            return m == 2 && leap ? 29 : n[m - 1];
        }

        boolean sameDay(Moment o) {
            return o != null && year == o.year && month == o.month && day == o.day;
        }

        String date() {
            return day + " " + MONTHS[month - 1] + " " + year;
        }

        String time() {
            return String.format(Locale.ROOT, "%02d:%02d", hour, minute);
        }
    }

    static String when(Moment start, Moment end) {
        if (start == null) return "";
        if (start.allDay) {
            Moment last = end != null && end.allDay ? end.previousDay() : null;
            if (last == null || last.sameDay(start) || last.year < start.year
                    || (last.year == start.year && (last.month < start.month
                        || (last.month == start.month && last.day <= start.day))))
                return start.date();
            return start.date() + " – " + last.date();
        }
        String zone = start.zone.isEmpty() ? "" : " " + start.zone;
        if (end == null || end.allDay) return start.date() + ", " + start.time() + zone;
        if (end.sameDay(start))
            return start.date() + ", " + start.time() + " – " + end.time() + zone;
        return start.date() + ", " + start.time() + " – " + end.date() + ", " + end.time() + zone;
    }

    private static final class Event {
        String summary = "";
        String location = "";
        String description = "";
        String url = "";
        Moment start;
        Moment end;

        void add(String name, List<String> params, String value) {
            switch (name) {
                case "SUMMARY": summary = VCardText.unescape(value).trim(); break;
                case "LOCATION": location = VCardText.unescape(value).trim(); break;
                case "DESCRIPTION": description = VCardText.unescape(value).trim(); break;
                case "URL": url = value.trim(); break;
                case "DTSTART": start = Moment.parse(value, params); break;
                case "DTEND": end = Moment.parse(value, params); break;
                default: break;
            }
        }

        String render() {
            List<String> lines = new ArrayList<>();
            if (!summary.isEmpty()) lines.add(summary);
            String w = when(start, end);
            if (!w.isEmpty()) lines.add(w);
            if (!location.isEmpty()) lines.add(location);
            if (!description.isEmpty()) lines.add(description);
            if (!url.isEmpty()) lines.add(url);
            return String.join("\n", lines);
        }
    }
}
