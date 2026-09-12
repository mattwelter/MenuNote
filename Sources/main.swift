import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let noteVC = NoteViewController()
    private var pinnedPanel: NSPanel?

    /// The note's size, shared by the popover and the pinned window,
    /// remembered across launches. Resize the pinned window to change it.
    private var savedNoteSize: NSSize {
        get {
            let defaults = UserDefaults.standard
            let w = defaults.double(forKey: "MenuNote.width")
            let h = defaults.double(forKey: "MenuNote.height")
            if w >= 260, h >= 300 { return NSSize(width: w, height: h) }
            return NSSize(width: 300, height: 400)
        }
        set {
            UserDefaults.standard.set(Double(newValue.width), forKey: "MenuNote.width")
            UserDefaults.standard.set(Double(newValue.height), forKey: "MenuNote.height")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("MenuNote v2.7 — launching")
        buildMainMenu()
        noteVC.onPinToggled = { [weak self] pinned in
            self?.setPinned(pinned)
        }

        popover.contentSize = savedNoteSize
        popover.behavior = .transient   // closes when you click elsewhere
        popover.animates = true
        popover.contentViewController = noteVC
        popover.delegate = self

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            var icon = NSImage(systemSymbolName: "plus", accessibilityDescription: "Note") ?? NSImage()
            if let configured = icon.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .bold)) {
                icon = configured
            }
            icon.isTemplate = true   // auto-adapts to menu bar light/dark
            button.image = icon
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    // A main menu (even though it's never visible in a menu-bar-only app)
    // lets the standard Edit shortcuts route through the responder chain.
    private func buildMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit MenuNote",
                                   action: #selector(NSApplication.terminate(_:)),
                                   keyEquivalent: "q"))
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        edit.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        edit.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        edit.addItem(.separator())
        edit.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        edit.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = edit

        let formatItem = NSMenuItem()
        main.addItem(formatItem)
        let format = NSMenu(title: "Format")
        let bold = NSMenuItem(title: "Bold", action: #selector(NoteViewController.toggleBold(_:)), keyEquivalent: "b")
        bold.target = noteVC
        let italic = NSMenuItem(title: "Italic", action: #selector(NoteViewController.toggleItalic(_:)), keyEquivalent: "i")
        italic.target = noteVC
        let underline = NSMenuItem(title: "Underline", action: #selector(NoteViewController.toggleUnderline(_:)), keyEquivalent: "u")
        underline.target = noteVC
        format.addItem(bold)
        format.addItem(italic)
        format.addItem(underline)
        formatItem.submenu = format

        NSApp.mainMenu = main
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showQuitMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        // While pinned, the status item toggles the floating panel instead.
        if let panel = pinnedPanel {
            if panel.isVisible {
                panel.orderOut(nil)
            } else {
                NSApp.activate(ignoringOtherApps: true)
                panel.makeKeyAndOrderFront(nil)
            }
            return
        }
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSLog("MenuNote v2.7 — opening popover")
            popover.contentSize = savedNoteSize
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSLog("MenuNote v2.7 — popover opened")
        }
    }

    // MARK: - Pinning (floating always-on-top panel)

    private func setPinned(_ pinned: Bool) {
        if pinned {
            pinToFloatingPanel()
        } else {
            unpinToPopover()
        }
    }

    private func pinToFloatingPanel() {
        // Remember where the popover was so the panel appears in the same spot.
        let currentFrame = noteVC.view.window?.frame

        popover.performClose(nil)
        popover.contentViewController = nil

        let frame = currentFrame ?? NSRect(x: 200, y: 200, width: 300, height: 400)
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.level = .floating                    // stays above normal windows
        panel.hidesOnDeactivate = false            // stays visible when you focus another app
        panel.isMovableByWindowBackground = true   // drag it from the header / date area
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentMinSize = NSSize(width: 260, height: 300)
        panel.delegate = self
        panel.contentViewController = noteVC
        var pinnedFrame = frame
        pinnedFrame.size = savedNoteSize
        panel.setFrame(pinnedFrame, display: true)

        pinnedPanel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let panel = pinnedPanel, (notification.object as? NSPanel) === panel,
              let contentSize = panel.contentView?.frame.size else { return }
        savedNoteSize = contentSize
    }

    private func unpinToPopover() {
        if let contentSize = pinnedPanel?.contentView?.frame.size {
            savedNoteSize = contentSize
        }
        popover.contentSize = savedNoteSize
        pinnedPanel?.orderOut(nil)
        pinnedPanel?.contentViewController = nil
        pinnedPanel = nil

        popover.contentViewController = noteVC
        if let button = statusItem.button {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        noteVC.saveNow()
    }

    private func showQuitMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit MenuNote", action: #selector(quit), keyEquivalent: "q"))
        menu.items.first?.target = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil   // so left-click keeps toggling the popover
    }

    @objc private func quit() {
        noteVC.saveNow()
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        noteVC.saveNow()
    }
}

// MARK: - Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // no Dock icon, menu bar only
app.run()
