import AppKit
import ApplicationServices

func axValue(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var result: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
    return result
}
func elements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
    axValue(element, attribute) as? [AXUIElement] ?? []
}
struct Entry {
    let element: AXUIElement
    let app: NSRunningApplication
    let title: String
}
final class App: NSObject, NSApplicationDelegate {
    var popover: NSPopover!
    var stack: NSStackView!
    var message: NSTextField!
    var status: NSStatusItem!
    var entries: [Entry] = []
    var refreshing = false
    var accessTimer: Timer?
    var lastTrusted = false
    func recordAccess() -> Bool {
        let trusted = AXIsProcessTrusted()
        UserDefaults.standard.set(trusted, forKey: "AccessibilityTrusted")
        UserDefaults.standard.set("0.4", forKey: "RunningVersion")
        return trusted
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appMenu = NSMenuItem()
        menu.addItem(appMenu)
        appMenu.submenu = NSMenu()
        appMenu.submenu?.addItem(withTitle: "Quit MenuShelf", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = menu
        let positionKey = "NSStatusItem Preferred Position MenuShelf"
        if UserDefaults.standard.object(forKey: positionKey) == nil {
            UserDefaults.standard.set(0, forKey: positionKey)
        }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.autosaveName = "MenuShelf"
        status.button?.image = NSImage(systemSymbolName: "list.bullet.rectangle", accessibilityDescription: "MenuShelf")
        status.button?.target = self
        status.button?.action = #selector(show)
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        let controller = NSViewController()
        controller.view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 520))
        popover.contentViewController = controller
        popover.contentSize = controller.view.frame.size
        let contentView = controller.view
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor), root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor), root.topAnchor.constraint(equalTo: contentView.topAnchor), root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)])
        message = NSTextField(wrappingLabelWithString: "")
        root.addArrangedSubview(message)
        let controls = NSStackView()
        controls.spacing = 10
        for (title, action) in [("Refresh", #selector(refresh)), ("Access…", #selector(permission)), ("Quit", #selector(quit))] {
            let b = NSButton(title: title, target: self, action: action)
            controls.addArrangedSubview(b)
        }
        root.addArrangedSubview(controls)
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = false
        scroll.borderType = .bezelBorder
        stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = stack
        root.addArrangedSubview(scroll)
        NSLayoutConstraint.activate([scroll.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -36), stack.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor)])
        lastTrusted = recordAccess()
        accessTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let trusted = self.recordAccess()
            if trusted != self.lastTrusted {
                self.lastTrusted = trusted
                self.refresh()
            }
        }
        if !CommandLine.arguments.contains("--background") {
            show()
            if !lastTrusted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.permission() }
            }
        }
    }
    @objc func show() {
        if popover.isShown { popover.performClose(nil); return }
        openPopover()
        refresh()
    }
    func openPopover() {
        guard let button = status.button else { return }
        let available = button.window?.screen?.visibleFrame.height ?? 700
        popover.contentSize = NSSize(width: 420, height: min(520, max(260, available - 60)))
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }
    @objc func permission() {
        popover.performClose(nil)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc func refresh() {
        guard !refreshing else { return }
        for view in stack.arrangedSubviews { stack.removeArrangedSubview(view); view.removeFromSuperview() }
        entries.removeAll()
        guard recordAccess() else {
            message.stringValue = "Allow MenuShelf in System Settings → Privacy & Security → Accessibility. This list refreshes automatically when access is granted. If an old entry is stuck, remove it and add the installed copy again."
            return
        }
        refreshing = true
        message.stringValue = "Finding menu bar items…"
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
                && $0.bundleIdentifier != "com.apple.controlcenter"
        }
        DispatchQueue.global(qos: .userInitiated).async {
            var found: [Entry] = []
            for app in apps {
                let ax = AXUIElementCreateApplication(app.processIdentifier)
                AXUIElementSetMessagingTimeout(ax, 0.2)
                var bars: [AXUIElement] = []
                if let bar = axValue(ax, "AXExtrasMenuBar"), CFGetTypeID(bar) == AXUIElementGetTypeID() { bars.append(bar as! AXUIElement) }
                if app.bundleIdentifier == "com.apple.systemuiserver", let bar = axValue(ax, kAXMenuBarAttribute), CFGetTypeID(bar) == AXUIElementGetTypeID() {
                    let candidate = bar as! AXUIElement
                    if !bars.contains(where: { CFEqual($0, candidate) }) { bars.append(candidate) }
                }
                for bar in bars {
                    for item in elements(bar, kAXChildrenAttribute) {
                        if found.contains(where: { CFEqual($0.element, item) }) { continue }
                        let texts = [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute].compactMap { axValue(item, $0) as? String }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        found.append(Entry(element: item, app: app, title: texts.first ?? "Untitled item"))
                    }
                }
            }
            let result = found.sorted { ($0.app.localizedName ?? "") < ($1.app.localizedName ?? "") }
            DispatchQueue.main.async {
                UserDefaults.standard.set(result.count, forKey: "DiscoveredItemCount")
                self.entries = result
                self.refreshing = false
                self.message.stringValue = result.isEmpty ? "No menu bar items were exposed through Accessibility. Check permission, then refresh." : "Menu bar items · \(result.count)"
                for (index, entry) in result.enumerated() {
                    let b = NSButton(title: "\(entry.app.localizedName ?? "Application") · \(entry.title)", target: self, action: #selector(self.press(_:)))
                    b.image = entry.app.icon
                    b.image?.size = NSSize(width: 22, height: 22)
                    b.imagePosition = .imageLeading
                    b.alignment = .left
                    b.lineBreakMode = .byTruncatingTail
                    b.tag = index
                    b.toolTip = b.title
                    self.stack.addArrangedSubview(b)
                    b.widthAnchor.constraint(equalTo: self.stack.widthAnchor, constant: -20).isActive = true
                    b.heightAnchor.constraint(equalToConstant: 36).isActive = true
                }
            }
        }
    }
    @objc func press(_ sender: NSButton) {
        guard entries.indices.contains(sender.tag) else { return }
        let entry = entries[sender.tag]
        popover.performClose(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let result = AXUIElementPerformAction(entry.element, kAXPressAction as CFString)
            if result != .success {
                self.openPopover()
                self.message.stringValue = "\(entry.app.localizedName ?? "Application") could not open this item (AX: \(result.rawValue)). It may have disappeared or may not support accessibility actions. Refresh the list."
            }
        }
    }
}
if CommandLine.arguments.contains("--self-test") {
    print("MenuShelf: executable OK; accessibility=\(AXIsProcessTrusted()); macOS=\(ProcessInfo.processInfo.operatingSystemVersionString)")
} else {
    let app = NSApplication.shared
    let delegate = App()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
