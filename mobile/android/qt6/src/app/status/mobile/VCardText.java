package app.status.mobile;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

// Renders a shared vCard as a readable contact card: name, title, organisation,
// phones, emails, URLs, addresses, note. Photos and anything else are dropped;
// chat has no contact message, so the card travels as plain text.
final class VCardText {
    private VCardText() {}

    static boolean isVCard(String text) {
        String t = text.trim();
        return t.regionMatches(true, 0, "BEGIN:VCARD", 0, "BEGIN:VCARD".length());
    }

    // Every card in the text, blank-line separated. Falls back to the raw text
    // when nothing readable was found.
    static String format(String text) {
        StringBuilder out = new StringBuilder();
        Card card = null;
        for (String line : unfold(text)) {
            Property p = Property.parse(line);
            if (p == null) continue;
            if (p.name.equals("BEGIN") && p.value.equalsIgnoreCase("VCARD")) {
                card = new Card();
            } else if (p.name.equals("END") && card != null) {
                String rendered = card.render();
                if (!rendered.isEmpty()) {
                    if (out.length() > 0) out.append("\n\n");
                    out.append(rendered);
                }
                card = null;
            } else if (card != null) {
                card.add(p);
            }
        }
        return out.length() > 0 ? out.toString() : text.trim();
    }

    // Continuation lines (leading space or tab) belong to the previous line.
    private static List<String> unfold(String text) {
        List<String> lines = new ArrayList<>();
        for (String raw : text.split("\r\n|\r|\n")) {
            if (!raw.isEmpty() && (raw.charAt(0) == ' ' || raw.charAt(0) == '\t') && !lines.isEmpty()) {
                int last = lines.size() - 1;
                lines.set(last, lines.get(last) + raw.substring(1));
            } else {
                lines.add(raw);
            }
        }
        return lines;
    }

    // Splits on an unescaped separator; backslash escapes stay in the parts.
    private static List<String> splitUnescaped(String s, char sep) {
        List<String> parts = new ArrayList<>();
        StringBuilder cur = new StringBuilder();
        boolean escaped = false;
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (escaped) {
                cur.append(c);
                escaped = false;
            } else if (c == '\\') {
                cur.append(c);
                escaped = true;
            } else if (c == sep) {
                parts.add(cur.toString());
                cur.setLength(0);
            } else {
                cur.append(c);
            }
        }
        parts.add(cur.toString());
        return parts;
    }

    private static String unescape(String s) {
        StringBuilder out = new StringBuilder();
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == '\\' && i + 1 < s.length()) {
                char n = s.charAt(++i);
                out.append(n == 'n' || n == 'N' ? '\n' : n);
            } else {
                out.append(c);
            }
        }
        return out.toString();
    }

    private static String joinNonEmpty(List<String> parts, String sep) {
        StringBuilder out = new StringBuilder();
        for (String part : parts) {
            String p = unescape(part).trim();
            if (p.isEmpty()) continue;
            if (out.length() > 0) out.append(sep);
            out.append(p);
        }
        return out.toString();
    }

    private static final class Property {
        final String name;
        final List<String> params;
        final String value;

        private Property(String name, List<String> params, String value) {
            this.name = name;
            this.params = params;
            this.value = value;
        }

        static Property parse(String line) {
            int colon = line.indexOf(':');
            if (colon <= 0) return null;
            List<String> head = splitUnescaped(line.substring(0, colon), ';');
            String name = head.get(0).toUpperCase(Locale.ROOT);
            int group = name.indexOf('.');
            if (group >= 0) name = name.substring(group + 1);
            return new Property(name, head.subList(1, head.size()), line.substring(colon + 1));
        }

        // "(mobile)", "(work)" ... from the TYPE parameters; vCard 2.1 writes
        // the type words as bare parameters.
        String label() {
            for (String param : params) {
                String p = param.toUpperCase(Locale.ROOT);
                String types = p.startsWith("TYPE=") ? p.substring(5) : p.contains("=") ? "" : p;
                for (String type : types.split(",")) {
                    switch (type.replace("\"", "")) {
                        case "CELL": return "mobile";
                        case "IPHONE": return "iPhone";
                        case "HOME": return "home";
                        case "WORK": return "work";
                        case "MAIN": return "main";
                        case "FAX": return "fax";
                        case "PAGER": return "pager";
                        default: break;
                    }
                }
            }
            return "";
        }

        String labelled(String rendered) {
            String label = label();
            return label.isEmpty() ? rendered : rendered + " (" + label + ")";
        }
    }

    private static final class Card {
        String fn = "";
        String n = "";
        String title = "";
        String org = "";
        String note = "";
        final List<String> tels = new ArrayList<>();
        final List<String> emails = new ArrayList<>();
        final List<String> urls = new ArrayList<>();
        final List<String> adrs = new ArrayList<>();

        void add(Property p) {
            switch (p.name) {
                case "FN": fn = unescape(p.value).trim(); break;
                case "N": {
                    // Family;Given;Additional;Prefix;Suffix
                    List<String> c = splitUnescaped(p.value, ';');
                    while (c.size() < 5) c.add("");
                    List<String> ordered = new ArrayList<>();
                    ordered.add(c.get(3));
                    ordered.add(c.get(1));
                    ordered.add(c.get(2));
                    ordered.add(c.get(0));
                    ordered.add(c.get(4));
                    n = joinNonEmpty(ordered, " ");
                    break;
                }
                case "TITLE": title = unescape(p.value).trim(); break;
                case "ORG": org = joinNonEmpty(splitUnescaped(p.value, ';'), ", "); break;
                case "NOTE": note = unescape(p.value).trim(); break;
                case "TEL": addIfNotEmpty(tels, p.labelled(unescape(p.value).trim())); break;
                case "EMAIL": addIfNotEmpty(emails, p.labelled(unescape(p.value).trim())); break;
                case "URL": addIfNotEmpty(urls, p.labelled(unescape(p.value).trim())); break;
                case "ADR": addIfNotEmpty(adrs, p.labelled(joinNonEmpty(splitUnescaped(p.value, ';'), ", "))); break;
                default: break;
            }
        }

        private static void addIfNotEmpty(List<String> list, String s) {
            if (!s.isEmpty() && !s.startsWith(" (")) list.add(s);
        }

        String render() {
            List<String> lines = new ArrayList<>();
            String name = fn.isEmpty() ? n : fn;
            if (!name.isEmpty()) lines.add(name);
            if (!title.isEmpty()) lines.add(title);
            if (!org.isEmpty()) lines.add(org);
            lines.addAll(tels);
            lines.addAll(emails);
            lines.addAll(urls);
            lines.addAll(adrs);
            if (!note.isEmpty()) lines.add(note);
            return String.join("\n", lines);
        }
    }
}
