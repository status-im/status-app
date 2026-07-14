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
    if matches.count > 1 {
        FileHandle.standardError.write("warning: \(matches.count) matches for '\(idSubstr)', using first:\n".data(using: .utf8)!)
        for (_, p) in matches {
            FileHandle.standardError.write("  \(p)\n".data(using: .utf8)!)
        }
    }
    return matches.first?.0
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
      click     --pid P --id S             synthesized mouse click at center
      type      --text V                   synthesized keystrokes (focused el)
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

case "click":
    guard let el = findOne(app: appElement(), idSubstr: requireOpt("id")) else { fail("no match") }
    guard let f = frame(el) else { fail("element has no frame") }
    let center = CGPoint(x: f.midX, y: f.midY)
    for type in [CGEventType.leftMouseDown, .leftMouseUp] {
        guard let ev = CGEvent(mouseEventSource: nil, mouseType: type,
                               mouseCursorPosition: center, mouseButton: .left) else { fail("CGEvent failed") }
        ev.post(tap: .cghidEventTap)
        usleep(30_000)
    }
    print("ok")

case "type":
    let text = requireOpt("text")
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
