# MenuNote

A tiny macOS menu bar notepad, styled after Apple Notes. One note, always a click away.

Click the **+** in your menu bar and a Notes-style notepad pops open. Everything you type is saved automatically and is right where you left it next time — no windows to manage, no files to save.

## Features

- **Lives in the menu bar** — no Dock icon, opens instantly from the **+** icon
- **Apple Notes styling** — Title / Heading / Subheading / Body / Monostyled text, bulleted, dashed & numbered lists, clickable checklists, block quotes
- **Markdown-style shortcuts while typing** (at the start of a line):
  - `# `, `## `, `### ` → Title / Heading / Subheading
  - `- ` or `* ` → bulleted list
  - `1. ` → numbered list (any starting number)
  - `[] ` → checklist item, `[x] ` → checked item
  - `| ` or `> ` → block quote
  - ``` ``` ``` → monostyled code line
- **Smart Enter key** — lists and checklists continue automatically; numbered lists renumber themselves; Enter on an empty item exits the list
- **Format menu (Aa)** — bold, italic, underline, strikethrough, and every paragraph style
- **Pin on top** — click the pin to detach the note into a floating window that stays above everything, follows you across Spaces, and can be dragged anywhere
- **Autosave** — every change is saved to disk within half a second, formatting and checkbox states included
- **Native & dependency-free** — a few small Swift/AppKit files, no frameworks, no Electron

## Install

### Build from source (recommended, ~30 seconds)

Requires the Xcode Command Line Tools (free). If you don't have them:

```bash
xcode-select --install
```

Then:

```bash
git clone https://github.com/mattwelter/MenuNote.git
cd MenuNote
./build.sh
open MenuNote.app
```

Drag `MenuNote.app` into `/Applications` to keep it. To have it start at login: System Settings → General → Login Items → add MenuNote.

### Download a release

Grab `MenuNote.app` from the [Releases](https://github.com/mattwelter/MenuNote/releases) page (if one is published). Because the app isn't notarized by Apple, macOS will warn on first open — **right-click the app → Open → Open**, or run:

```bash
xattr -cr MenuNote.app
```

Building from source avoids the warning entirely.

## Usage

| Action | How |
|---|---|
| Open / close the note | Left-click the **+** in the menu bar |
| Quit | Right-click the **+** → Quit |
| Change text style | **Aa** button, or type a shortcut like `## ` |
| Toggle a checkbox | Click the circle |
| Pin as a floating window | Click the **pin** — drag it by the header; click again to unpin |
| Bold / Italic / Underline | ⌘B / ⌘I / ⌘U |
| Undo / Redo | ⌘Z / ⇧⌘Z |

Your note is stored at `~/Library/Application Support/MenuNote/note.data`.

## Project layout

```
MenuNote/
├── build.sh                     # one-command build (swiftc + iconutil + codesign)
├── Info.plist                   # app bundle metadata (menu-bar-only app)
├── AppIcon.iconset/             # app icon at every required size
└── Sources/
    ├── main.swift               # app entry, status item, popover ↔ pinned panel
    ├── NoteViewController.swift # header UI, format menu, typing triggers, Enter handling
    ├── NoteTextView.swift       # checkbox clicks + keyboard shortcuts
    ├── Styles.swift             # fonts & paragraph styles for every text role
    ├── CheckboxAttachment.swift # the clickable checklist circle
    └── NoteStore.swift          # load/save (keyed archive, autosaved)
```

## License

MIT — see [LICENSE](LICENSE).
