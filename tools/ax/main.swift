// ax — minimal macOS Accessibility CLI for agent-driven QML iteration.
//
// Finds elements by AXIdentifier substring (Qt auto-derives identifiers from
// QML objectName paths), performs actions, reads state, dumps trees as JSON.
//
// Build: swiftc -O main.swift -o ax
// Requires: Accessibility permission for the invoking terminal (System
// Settings → Privacy & Security → Accessibility).

import AppKit
import ApplicationServices
import Foundation

// MARK: - AX helpers

func attr(_ el: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    let err = AXUIElementCopyAttributeValue(el, name as CFString, &value)
    return err == .success ? value : nil
}

func stringAttr(_ el: AXUIElement, _ name: String) -> String? {
    attr(el, name) as? String
}

func children(_ el: AXUIElement) -> [AXUIElement] {
    (attr(el, kAXChildrenAttribute) as? [AXUIElement]) ?? []
}

func frame(_ el: AXUIElement) -> CGRect? {
    guard let posVal = attr(el, kAXPositionAttribute),
          let sizeVal = attr(el, kAXSizeAttribute) else { return nil }
    var pos = CGPoint.zero
    var size = CGSize.zero
    guard AXValueGetValue(posVal as! AXValue, .cgPoint, &pos),
          AXValueGetValue(sizeVal as! AXValue, .cgSize, &size) else { return nil }
    return CGRect(origin: pos, size: size)
}

// MARK: - Node model

func describe(_ el: AXUIElement, depth: Int, maxDepth: Int, filter: String?) -> [String: Any]? {
    var node: [String: Any] = [:]
    if let role = stringAttr(el, kAXRoleAttribute) { node["role"] = role }
    if let id = stringAttr(el, "AXIdentifier"), !id.isEmpty { node["id"] = id }
    if let title = stringAttr(el, kAXTitleAttribute), !title.isEmpty { node["title"] = title }
    if let desc = stringAttr(el, kAXDescriptionAttribute), !desc.isEmpty { node["description"] = desc }
    if let value = attr(el, kAXValueAttribute) {
        node["value"] = (value as? String) ?? (value as? NSNumber)?.stringValue ?? String(describing: value)
    }
    if let enabled = attr(el, kAXEnabledAttribute) as? Bool { node["enabled"] = enabled }
    if let focused = attr(el, kAXFocusedAttribute) as? Bool, focused { node["focused"] = true }
    if let f = frame(el) {
        node["frame"] = [Int(f.origin.x), Int(f.origin.y), Int(f.size.width), Int(f.size.height)]
    }

    var childNodes: [[String: Any]] = []
    if depth < maxDepth {
        for child in children(el) {
            if let c = describe(child, depth: depth + 1, maxDepth: maxDepth, filter: filter) {
                childNodes.append(c)
            }
        }
    }
    if !childNodes.isEmpty { node["children"] = childNodes }

    // Filter: keep node if it matches, or any descendant matched.
    if let filter = filter {
        let hay = ((node["id"] as? String) ?? "") + " " + ((node["title"] as? String) ?? "")
            + " " + ((node["description"] as? String) ?? "") + " " + ((node["role"] as? String) ?? "")
        if !hay.localizedCaseInsensitiveContains(filter) && childNodes.isEmpty {
            return nil
        }
    }
    return node
}

// MARK: - Find

func collectMatches(_ el: AXUIElement, idSubstr: String, path: String, into: inout [(AXUIElement, String)]) {
    let id = stringAttr(el, "AXIdentifier") ?? ""
    let newPath = path + "/" + (id.isEmpty ? (stringAttr(el, kAXRoleAttribute) ?? "?") : id)
    if !id.isEmpty && id.localizedCaseInsensitiveContains(idSubstr) {
        into.append((el, newPath))
    }
    for child in children(el) {
        collectMatches(child, idSubstr: idSubstr, path: newPath, into: &into)
    }
}

func findOne(app: AXUIElement, idSubstr: String) -> AXUIElement? {
    var matches: [(AXUIElement, String)] = []
    collectMatches(app, idSubstr: idSubstr, path: "", into: &matches)
    guard !matches.isEmpty else { return nil }
    // Identifiers are ancestor paths, so a container's name is a substring of
    // every descendant's identifier. Prefer elements whose identifier *ends*
    // with the query (the element itself), then the shortest identifier.
    func rank(_ path: String) -> Int {
        let id = path.split(separator: "/").last.map(String.init) ?? path
        if id == idSubstr || id.hasSuffix("." + idSubstr) || id.hasSuffix(idSubstr) { return 0 }
        return 1
    }
    matches.sort { a, b in
        let (ra, rb) = (rank(a.1), rank(b.1))
        if ra != rb { return ra < rb }
        return a.1.count < b.1.count
    }
    let best = matches[0]
    let ambiguous = matches.filter { rank($0.1) == rank(best.1) && $0.1.count == best.1.count }
    if ambiguous.count > 1 {
        FileHandle.standardError.write("warning: \(ambiguous.count) equally-ranked matches for '\(idSubstr)', using first:\n".data(using: .utf8)!)
        for (_, p) in ambiguous.prefix(5) {
            FileHandle.standardError.write("  \(p)\n".data(using: .utf8)!)
        }
    }
    return best.0
}

// MARK: - HID event helpers
//
// postToPid is unreliable for AppKit/Qt (events bypass window-server routing
// and get dropped), so real input goes through the HID tap. To keep this
// unobtrusive: the target app is activated first (required for routing), the
// user's cursor position is saved, and restored immediately after the events.

func currentCursor() -> CGPoint {
    CGEvent(source: nil)?.location ?? .zero
}

func activateApp(_ pid: pid_t) {
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    usleep(150_000)
}

// Refuses to fire real input while the human is using the machine, if the
// target app could not become frontmost, or if the target point is covered
// by another app's window. HID events are global — a misfire lands in the
// user's windows, so failing loudly beats guessing. --force skips the idle check.
func hidGuard(_ pid: pid_t, point: CGPoint?) {
    if !args.contains("--force") {
        let types: [CGEventType] = [.mouseMoved, .leftMouseDown, .keyDown, .scrollWheel]
        let idle = types.map {
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0)
        }.min() ?? .infinity
        if idle < 2.0 {
            fail("user input detected \(String(format: "%.1f", idle))s ago — refusing to inject events while the human is active; retry when idle or pass --force")
        }
    }
    activateApp(pid)
    if let front = NSWorkspace.shared.frontmostApplication?.processIdentifier, front != pid {
        fail("target app (pid \(pid)) could not become frontmost (frontmost is pid \(front)) — real input would land in the wrong app")
    }
    if let p = point {
        let winList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        for win in winList where ((win[kCGWindowLayer as String] as? Int) ?? 1) == 0 {
            guard let b = win[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: b as CFDictionary) else { continue }
            if rect.contains(p) {
                let owner = win[kCGWindowOwnerPID as String] as? pid_t ?? -1
                if owner != pid {
                    fail("target point is covered by another app's window (pid \(owner), \(win[kCGWindowOwnerName as String] ?? "?")) — refusing to click through it")
                }
                break
            }
        }
    }
}

func withCursorRestore(_ body: () -> Void) {
    let saved = currentCursor()
    body()
    usleep(30_000)
    CGWarpMouseCursorPosition(saved)
    CGAssociateMouseAndMouseCursorPosition(1)
}

func postMouse(_ type: CGEventType, _ button: CGMouseButton, at point: CGPoint,
               buttonNumber: Int64? = nil, clickState: Int64 = 1) {
    guard let ev = CGEvent(mouseEventSource: nil, mouseType: type,
                           mouseCursorPosition: point, mouseButton: button) else { fail("CGEvent failed") }
    if type != .mouseMoved { ev.setIntegerValueField(.mouseEventClickState, value: clickState) }
    if let n = buttonNumber { ev.setIntegerValueField(.mouseEventButtonNumber, value: n) }
    ev.post(tap: .cghidEventTap)
    usleep(30_000)
}

// MARK: - Output

func printJSON(_ obj: Any) {
    let data = try! JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
    print(String(data: data, encoding: .utf8)!)
}

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write("error: \(msg)\n".data(using: .utf8)!)
    exit(1)
}

// MARK: - Args

var args = Array(CommandLine.arguments.dropFirst())
guard !args.isEmpty else {
    print("""
    usage: ax <command> [options]

    commands:
      preflight                            verify AX + Screen Recording permissions (prompts if missing)
      trusted                              check AX permission
      apps                                 list GUI apps (pid, name)
      tree      --pid P [--max-depth N] [--filter S]
      find      --pid P --id S             list all identifier matches
      read      --pid P --id S             dump one element's attributes
      press     --pid P --id S             AXPress on first match
      set       --pid P --id S --value V   set AXValue (text fields)
      activate  --pid P                    bring app frontmost (no cursor move)
      scroll    --pid P --id S (--to 0..1 | --by D)  pure-AX scrollbar drive
      click     --pid P --id S             real click; activates app, cursor
                                           warped back to user position after
      rightclick --pid P --id S            right click (context menus); same
      hover     --pid P --id S             mouse-move over element (Qt hover)
      mousedown|mouseup|mousemove --pid P (--id S | --x N --y N)
                                           drag primitives (cursor restored on mouseup)
      key       --pid P --key K [--id S]   esc|enter|tab|space|backspace|arrows|
                                           home|end|pageup|pagedown|back|forward
                                           (back/forward = mouse nav buttons 4/5)
      type      --pid P --text V           real keystrokes into app's focused field
                                           (prefer `set` for text fields)
      screenshot --pid P --out FILE        capture app's front window
    """)
    exit(0)
}

let command = args.removeFirst()

func opt(_ name: String) -> String? {
    guard let i = args.firstIndex(of: "--" + name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

func requireOpt(_ name: String) -> String {
    guard let v = opt(name) else { fail("missing --\(name)") }
    return v
}

func appElement() -> AXUIElement {
    guard let pidStr = opt("pid"), let pid = pid_t(pidStr) else { fail("missing/bad --pid") }
    return AXUIElementCreateApplication(pid)
}

// MARK: - Commands

switch command {
case "preflight":
    var failures: [String] = []
    let axOpts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    if !AXIsProcessTrustedWithOptions(axOpts) {
        failures.append("Accessibility: NOT granted — System Settings → Privacy & Security → Accessibility → enable your terminal (a grant prompt was triggered)")
    }
    if !CGPreflightScreenCaptureAccess() {
        CGRequestScreenCaptureAccess()
        failures.append("Screen Recording: NOT granted — System Settings → Privacy & Security → Screen Recording → enable your terminal (a grant prompt was triggered; restart the terminal after granting)")
    }
    if failures.isEmpty {
        print("ok: Accessibility + Screen Recording granted")
    } else {
        for f in failures { FileHandle.standardError.write("\(f)\n".data(using: .utf8)!) }
        exit(1)
    }

case "trusted":
    print(AXIsProcessTrusted() ? "trusted" : "NOT trusted — grant Accessibility permission to this terminal")
    exit(AXIsProcessTrusted() ? 0 : 1)

case "apps":
    for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
        print("\(app.processIdentifier)\t\(app.localizedName ?? "?")")
    }

case "tree":
    let maxDepth = Int(opt("max-depth") ?? "50") ?? 50
    let node = describe(appElement(), depth: 0, maxDepth: maxDepth, filter: opt("filter"))
    printJSON(node ?? [:])

case "find":
    var matches: [(AXUIElement, String)] = []
    collectMatches(appElement(), idSubstr: requireOpt("id"), path: "", into: &matches)
    let out = matches.map { el, path -> [String: Any] in
        var n = describe(el, depth: 0, maxDepth: 0, filter: nil) ?? [:]
        n["path"] = path
        return n
    }
    printJSON(out)

case "read":
    guard let el = findOne(app: appElement(), idSubstr: requireOpt("id")) else { fail("no match") }
    var names: CFArray?
    AXUIElementCopyAttributeNames(el, &names)
    var out: [String: Any] = [:]
    for name in (names as? [String]) ?? [] {
        guard let v = attr(el, name) else { continue }
        if let s = v as? String { out[name] = s }
        else if let n = v as? NSNumber { out[name] = n }
        else if name == kAXPositionAttribute || name == kAXSizeAttribute { continue }
        else { out[name] = String(describing: v) }
    }
    if let f = frame(el) { out["frame"] = [Int(f.origin.x), Int(f.origin.y), Int(f.size.width), Int(f.size.height)] }
    printJSON(out)

case "press":
    guard let el = findOne(app: appElement(), idSubstr: requireOpt("id")) else { fail("no match") }
    let err = AXUIElementPerformAction(el, kAXPressAction as CFString)
    guard err == .success else { fail("AXPress failed: \(err.rawValue)") }
    print("ok")

case "set":
    guard let el = findOne(app: appElement(), idSubstr: requireOpt("id")) else { fail("no match") }
    let value = requireOpt("value")
    let err = AXUIElementSetAttributeValue(el, kAXValueAttribute as CFString, value as CFString)
    guard err == .success else { fail("set AXValue failed: \(err.rawValue)") }
    print("ok")

case "activate":
    // Bring the app frontmost. Does not move the cursor.
    let err = AXUIElementSetAttributeValue(appElement(), kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    guard err == .success else { fail("activate failed: \(err.rawValue)") }
    print("ok")

case "click", "rightclick", "hover":
    guard let pidStr = opt("pid"), let pid = pid_t(pidStr) else { fail("missing/bad --pid") }
    guard let el = findOne(app: appElement(), idSubstr: requireOpt("id")) else { fail("no match") }
    guard let f = frame(el) else { fail("element has no frame") }
    let center = CGPoint(x: f.midX, y: f.midY)
    hidGuard(pid, point: center)
    withCursorRestore {
        switch command {
        case "click":
            postMouse(.leftMouseDown, .left, at: center)
            postMouse(.leftMouseUp, .left, at: center)
        case "rightclick":
            postMouse(.rightMouseDown, .right, at: center)
            postMouse(.rightMouseUp, .right, at: center)
        default: // hover
            postMouse(.mouseMoved, .left, at: center)
        }
    }
    print("ok")

case "mousedown", "mouseup", "mousemove":
    // Low-level primitives for drag / press-and-hold. Target by --id, or
    // explicit --x/--y (screen coords), e.g. mousedown on A, mousemove to B, mouseup.
    // NOTE: no cursor restore here — a drag sequence needs the cursor to stay
    // where the caller put it; restore happens implicitly on the final mouseup.
    guard let pidStr = opt("pid"), let pid = pid_t(pidStr) else { fail("missing/bad --pid") }
    var point: CGPoint
    if let xs = opt("x"), let ys = opt("y"), let x = Double(xs), let y = Double(ys) {
        point = CGPoint(x: x, y: y)
    } else if let idSub = opt("id"), let el = findOne(app: appElement(), idSubstr: idSub), let f = frame(el) {
        point = CGPoint(x: f.midX, y: f.midY)
    } else {
        fail("need --id or --x/--y")
    }
    hidGuard(pid, point: point)
    switch command {
    case "mousedown": postMouse(.leftMouseDown, .left, at: point)
    case "mouseup":
        withCursorRestore { postMouse(.leftMouseUp, .left, at: point) }
    default: postMouse(.leftMouseDragged, .left, at: point)
    }
    print("ok")

case "scroll":
    // Pure AX: drives the scrollbar's value — no cursor, no focus change.
    // Matches an AXScrollBar directly, or finds one among the element's
    // descendants. --to 0..1 sets absolute position; --by DELTA adjusts.
    // Containers (Pane, ScrollView) often have no AX element of their own —
    // search every identifier match and take the first that is, or contains,
    // an AXScrollBar.
    var matches: [(AXUIElement, String)] = []
    collectMatches(appElement(), idSubstr: requireOpt("id"), path: "", into: &matches)
    var bar: AXUIElement?
    outer: for (el, _) in matches {
        if stringAttr(el, kAXRoleAttribute) == "AXScrollBar" { bar = el; break }
        var queue = children(el)
        while !queue.isEmpty {
            let c = queue.removeFirst()
            if stringAttr(c, kAXRoleAttribute) == "AXScrollBar" { bar = c; break outer }
            queue.append(contentsOf: children(c))
        }
    }
    guard let scrollbar = bar else { fail("no AXScrollBar found among matches") }
    let current = (attr(scrollbar, kAXValueAttribute) as? NSNumber)?.doubleValue ?? 0
    var target = current
    if let to = opt("to"), let v = Double(to) { target = v }
    else if let by = opt("by"), let v = Double(by) { target = current + v }
    else { fail("need --to 0..1 or --by DELTA") }
    target = min(max(target, 0), 1)
    let err = AXUIElementSetAttributeValue(scrollbar, kAXValueAttribute as CFString, NSNumber(value: target))
    guard err == .success else { fail("set scrollbar value failed: \(err.rawValue)") }
    print("ok \(current) -> \(target)")

case "key":
    // Named keys by virtual keycode; "back"/"forward" are the mouse
    // navigation buttons (4/5), which Qt maps to back/forward navigation.
    // Keyboard events route to the focused window, so the app is activated.
    guard let pidStr = opt("pid"), let pid = pid_t(pidStr) else { fail("missing/bad --pid") }
    let name = requireOpt("key").lowercased()
    let keycodes: [String: CGKeyCode] = [
        "esc": 53, "escape": 53, "enter": 36, "return": 36, "tab": 48,
        "space": 49, "backspace": 51, "delete": 51,
        "left": 123, "right": 124, "down": 125, "up": 126,
        "home": 115, "end": 119, "pageup": 116, "pagedown": 121,
    ]
    hidGuard(pid, point: nil)
    if name == "back" || name == "forward" {
        let buttonNumber: Int64 = name == "back" ? 3 : 4
        var point = currentCursor()
        if let idSub = opt("id"), let el = findOne(app: appElement(), idSubstr: idSub), let f = frame(el) {
            point = CGPoint(x: f.midX, y: f.midY)
        } else if let win = attr(appElement(), kAXMainWindowAttribute).map({ $0 as! AXUIElement }),
                  let f = frame(win) {
            point = CGPoint(x: f.midX, y: f.midY)
        }
        withCursorRestore {
            postMouse(.otherMouseDown, .center, at: point, buttonNumber: buttonNumber)
            postMouse(.otherMouseUp, .center, at: point, buttonNumber: buttonNumber)
        }
    } else {
        guard let code = keycodes[name] else { fail("unknown key: \(name)") }
        for keyDown in [true, false] {
            guard let ev = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: keyDown) else { fail("CGEvent failed") }
            ev.post(tap: .cghidEventTap)
        }
    }
    print("ok")

case "type":
    // Real keystrokes via the HID tap; the app is activated first so the
    // events land in its focused field. Prefer `set` (pure AX) when possible.
    guard let pidStr = opt("pid"), let pid = pid_t(pidStr) else { fail("missing/bad --pid") }
    let text = requireOpt("text")
    hidGuard(pid, point: nil)
    for scalar in text.unicodeScalars {
        var chars = [UniChar](String(scalar).utf16)
        for keyDown in [true, false] {
            guard let ev = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: keyDown) else { fail("CGEvent failed") }
            ev.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
            ev.post(tap: .cghidEventTap)
        }
        usleep(15_000)
    }
    print("ok")

case "screenshot":
    guard let pidStr = opt("pid"), let pid = pid_t(pidStr) else { fail("missing/bad --pid") }
    let out = requireOpt("out")
    let winList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    let appWindows = winList.filter { ($0[kCGWindowOwnerPID as String] as? pid_t) == pid && (($0[kCGWindowLayer as String] as? Int) ?? 1) == 0 }
    guard let win = appWindows.first, let winID = win[kCGWindowNumber as String] as? Int else {
        fail("no on-screen window for pid \(pid)")
    }
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    task.arguments = ["-o", "-x", "-l", String(winID), out]
    try! task.run()
    task.waitUntilExit()
    guard task.terminationStatus == 0 else { fail("screencapture failed") }
    print(out)

default:
    fail("unknown command: \(command)")
}
